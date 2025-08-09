import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    @Binding var isFrontCamera: Bool
    
    class Coordinator: NSObject {
        var parent: CameraView
        var captureSession: AVCaptureSession?
        var currentCamera: AVCaptureDevice?
        
        init(_ parent: CameraView) {
            self.parent = parent
            super.init()
        }
        
        func setupCamera() {
            captureSession = AVCaptureSession()
            captureSession?.sessionPreset = .high
            
            // 전면 카메라 찾기
            if let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) {
                currentCamera = camera
                
                do {
                    let input = try AVCaptureDeviceInput(device: camera)
                    if captureSession?.canAddInput(input) == true {
                        captureSession?.addInput(input)
                    }
                } catch {
                    print("카메라 설정 오류: \(error)")
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        // 카메라 권한 확인
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                DispatchQueue.main.async {
                    context.coordinator.setupCamera()
                    
                    if let session = context.coordinator.captureSession {
                        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
                        previewLayer.frame = view.bounds
                        previewLayer.videoGravity = .resizeAspectFill
                        view.layer.addSublayer(previewLayer)
                        
                        DispatchQueue.global(qos: .userInitiated).async {
                            session.startRunning()
                        }
                    }
                }
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 필요시 업데이트 로직
    }
}

// 카메라 미리보기를 위한 SwiftUI View
struct CameraPreview: View {
    @Binding var isOn: Bool
    
    var body: some View {
        if isOn {
            #if targetEnvironment(simulator)
            // 시뮬레이터에서는 대체 화면 표시
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("카메라 프리뷰")
                        .foregroundColor(.gray)
                        .padding(.top, 10)
                    
                    Text("(시뮬레이터)")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            #else
            // 실제 기기에서는 카메라 표시
            CameraView(isFrontCamera: .constant(true))
                .ignoresSafeArea()
            #endif
        } else {
            Color.black
                .ignoresSafeArea()
                .overlay(
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.gray)
                )
        }
    }
}
