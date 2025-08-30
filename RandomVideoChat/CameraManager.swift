import SwiftUI
import AVFoundation
import Combine

// Centralized camera management to prevent freezing and lifecycle issues
class CameraManager: NSObject, ObservableObject {
    static let shared = CameraManager()
    
    @Published var isRunning = false
    @Published var isAuthorized = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var captureSession: AVCaptureSession?
    private var currentInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private var setupCompleted = false
    
    override init() {
        super.init()
        checkAuthorization()
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Authorization
    private func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.isAuthorized = true
            }
            setupCameraSession()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                }
                if granted {
                    self?.setupCameraSession()
                }
            }
            
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isAuthorized = false
            }
            
        @unknown default:
            break
        }
    }
    
    // MARK: - Camera Setup
    private func setupCameraSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.setupCompleted else { return }
            
            print("📷 Setting up camera session...")
            
            // Create session
            let session = AVCaptureSession()
            session.beginConfiguration()
            
            // Set preset for optimal performance
            if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            } else {
                session.sessionPreset = .high
            }
            
            // Add front camera input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                print("❌ Front camera not available")
                session.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                
                if session.canAddInput(input) {
                    session.addInput(input)
                    self.currentInput = input
                    
                    // Configure camera for best performance
                    try camera.lockForConfiguration()
                    
                    // Set frame rate for smooth preview
                    camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                    camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
                    
                    // Enable smooth autofocus
                    if camera.isFocusModeSupported(.continuousAutoFocus) {
                        camera.focusMode = .continuousAutoFocus
                    }
                    
                    // Enable auto exposure
                    if camera.isExposureModeSupported(.continuousAutoExposure) {
                        camera.exposureMode = .continuousAutoExposure
                    }
                    
                    camera.unlockForConfiguration()
                    
                    print("✅ Camera input added successfully")
                } else {
                    print("❌ Cannot add camera input")
                }
            } catch {
                print("❌ Error setting up camera: \(error)")
            }
            
            session.commitConfiguration()
            
            self.captureSession = session
            self.setupCompleted = true
            
            // Create preview layer on main thread
            DispatchQueue.main.async {
                self.createPreviewLayer()
            }
            
            // Start session
            self.startSession()
        }
    }
    
    // MARK: - Preview Layer
    private func createPreviewLayer() {
        guard let session = captureSession else { return }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait
        
        // Enable mirroring for front camera - must disable automatic adjustment first
        if let connection = layer.connection {
            // Disable automatic mirroring adjustment first
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                // Now we can set the mirroring manually
                connection.isVideoMirrored = true
            }
        }
        
        self.previewLayer = layer
        print("✅ Preview layer created (bounds initially: \(layer.bounds))")
    }
    
    // MARK: - Session Control
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  !session.isRunning else { return }
            
            print("📷 Starting camera session...")
            session.startRunning()
            
            DispatchQueue.main.async {
                self.isRunning = true
                print("✅ Camera session started")
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  session.isRunning else { return }
            
            print("📷 Stopping camera session...")
            session.stopRunning()
            
            DispatchQueue.main.async {
                self.isRunning = false
                print("✅ Camera session stopped")
            }
        }
    }
    
    func resumeSession() {
        // Always re-check system authorization to avoid stale state
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            DispatchQueue.main.async { self.isAuthorized = true }
            if setupCompleted {
                startSession()
            } else {
                setupCameraSession()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                DispatchQueue.main.async { self.isAuthorized = granted }
                if granted {
                    self.setupCameraSession()
                } else {
                    // No permission; nothing to resume
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { self.isAuthorized = false }
        @unknown default:
            break
        }
    }
    
    // MARK: - Camera Switch
    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self,
                  let session = self.captureSession,
                  let currentInput = self.currentInput else { return }
            
            session.beginConfiguration()
            session.removeInput(currentInput)
            
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .front ? .back : .front
            
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                session.addInput(currentInput)
                session.commitConfiguration()
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newCamera)
                if session.canAddInput(newInput) {
                    session.addInput(newInput)
                    self.currentInput = newInput
                    
                    // Update mirroring for preview layer
                    DispatchQueue.main.async {
                        if let connection = self.previewLayer?.connection {
                            if connection.isVideoMirroringSupported {
                                // Must disable automatic adjustment before setting manually
                                connection.automaticallyAdjustsVideoMirroring = false
                                connection.isVideoMirrored = (newPosition == .front)
                            }
                        }
                    }
                }
            } catch {
                print("❌ Error switching camera: \(error)")
                session.addInput(currentInput)
            }
            
            session.commitConfiguration()
        }
    }
}

// MARK: - SwiftUI Camera View
final class CameraPreviewContainerView: UIView {
    private var managedPreviewLayer: AVCaptureVideoPreviewLayer?
    
    func setPreviewLayer(_ newLayer: AVCaptureVideoPreviewLayer) {
        // Disable implicit Core Animation to avoid peel/fade effects
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        // Remove old
        if let old = managedPreviewLayer {
            old.removeFromSuperlayer()
        }
        managedPreviewLayer = newLayer
        layer.addSublayer(newLayer)
        newLayer.frame = bounds
        print("🎬 Attached preview layer to container (bounds: \(bounds))")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let layer = managedPreviewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = bounds
            CATransaction.commit()
        }
    }
}

struct ImprovedCameraView: UIViewRepresentable {
    @StateObject private var cameraManager = CameraManager.shared
    
    func makeUIView(context: Context) -> UIView {
        let view = CameraPreviewContainerView()
        view.backgroundColor = .black
        print("🧰 ImprovedCameraView.makeUIView (initial bounds: \(view.bounds))")
        
        // Set up preview layer when available
        if let previewLayer = cameraManager.previewLayer {
            view.setPreviewLayer(previewLayer)
        }
        
        // Observe preview layer changes
        context.coordinator.observePreviewLayer(view: view)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update preview layer frame
        if let container = uiView as? CameraPreviewContainerView,
           let previewLayer = cameraManager.previewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = container.bounds
            CATransaction.commit()
            // Ensure attached
            if previewLayer.superlayer !== container.layer {
                container.setPreviewLayer(previewLayer)
            }
        } else if let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = uiView.bounds
            CATransaction.commit()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: ImprovedCameraView
        private var cancellables = Set<AnyCancellable>()
        
        init(_ parent: ImprovedCameraView) {
            self.parent = parent
        }
        
        func observePreviewLayer(view: UIView) {
            CameraManager.shared.$previewLayer
                .compactMap { $0 }
                .sink { [weak view] layer in
                    guard let view = view else { return }
                    if let container = view as? CameraPreviewContainerView {
                        container.setPreviewLayer(layer)
                    } else {
                        // Remove old preview layers
                        view.layer.sublayers?.forEach { sublayer in
                            if sublayer is AVCaptureVideoPreviewLayer {
                                sublayer.removeFromSuperlayer()
                            }
                        }
                        view.layer.addSublayer(layer)
                        layer.frame = view.bounds
                        print("🎬 Attached preview layer to plain view (bounds: \(view.bounds))")
                    }
                }
                .store(in: &cancellables)
        }
    }
}

// MARK: - Improved Camera Preview for SwiftUI
struct ImprovedCameraPreview: View {
    @Binding var isOn: Bool
    @StateObject private var cameraManager = CameraManager.shared
    
    var body: some View {
        Group {
            if isOn && cameraManager.isAuthorized {
                ImprovedCameraView()
                    .ignoresSafeArea()
                    .transition(.identity)
            } else if isOn && !cameraManager.isAuthorized {
                // Camera not authorized
                VStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("카메라 접근 권한이 필요합니다")
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                    
                    Button("설정에서 권한 허용") {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .transition(.identity)
            } else {
                // Camera is off
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 150, height: 150)
                            .foregroundColor(.gray)
                    )
                    .transition(.identity)
            }
        }
        // isOn 변경에 따른 암묵적 애니메이션 제거
        .animation(.none, value: isOn)
        .onAppear {
            // Ensure session attempts to start and auth is re-checked
            print("🎥 ImprovedCameraPreview.onAppear (isOn=\(isOn), isAuthorized=\(cameraManager.isAuthorized))")
            cameraManager.resumeSession()
        }
        .onChange(of: isOn) { newValue in
            if newValue {
                print("🎥 ImprovedCameraPreview toggled ON -> ensure session running")
                cameraManager.resumeSession()
            } else {
                // UI-only: keep session running and show overlay
                print("🎥 ImprovedCameraPreview toggled OFF -> overlay only (session keeps running)")
            }
        }
    }
}
