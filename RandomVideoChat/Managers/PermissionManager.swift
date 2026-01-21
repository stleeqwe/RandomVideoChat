import AVFoundation
import UIKit

// MARK: - Permission Status
enum PermissionStatus {
    case granted
    case denied
    case notDetermined

    var isGranted: Bool {
        return self == .granted
    }
}

// MARK: - PermissionManager Protocol
protocol PermissionManagerProtocol {
    func checkCameraPermission() -> PermissionStatus
    func checkMicrophonePermission() -> PermissionStatus
    func checkAllPermissions() -> (camera: PermissionStatus, microphone: PermissionStatus)
    func areAllPermissionsGranted() -> Bool
    func requestCameraPermission(completion: @escaping (Bool) -> Void)
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void)
    func requestAllPermissions(completion: @escaping (Bool, String?) -> Void)
    func openAppSettings()
}

// MARK: - PermissionManager Implementation
final class PermissionManager: PermissionManagerProtocol {
    static let shared = PermissionManager()

    private init() {}

    // MARK: - Check Permissions

    func checkCameraPermission() -> PermissionStatus {
        return mapAVStatus(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func checkMicrophonePermission() -> PermissionStatus {
        return mapAVStatus(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    func checkAllPermissions() -> (camera: PermissionStatus, microphone: PermissionStatus) {
        return (checkCameraPermission(), checkMicrophonePermission())
    }

    func areAllPermissionsGranted() -> Bool {
        let permissions = checkAllPermissions()
        return permissions.camera.isGranted && permissions.microphone.isGranted
    }

    // MARK: - Request Permissions

    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = checkCameraPermission()

        switch status {
        case .granted:
            logDebug("Camera permission already granted", category: .permission)
            completion(true)

        case .notDetermined:
            logDebug("Requesting camera permission", category: .permission)
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    logInfo("Camera permission \(granted ? "granted" : "denied")", category: .permission)
                    completion(granted)
                }
            }

        case .denied:
            logWarning("Camera permission denied", category: .permission)
            completion(false)
        }
    }

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = checkMicrophonePermission()

        switch status {
        case .granted:
            logDebug("Microphone permission already granted", category: .permission)
            completion(true)

        case .notDetermined:
            logDebug("Requesting microphone permission", category: .permission)
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    logInfo("Microphone permission \(granted ? "granted" : "denied")", category: .permission)
                    completion(granted)
                }
            }

        case .denied:
            logWarning("Microphone permission denied", category: .permission)
            completion(false)
        }
    }

    /// Request all necessary permissions in sequence
    /// - Parameter completion: Returns (allGranted, errorMessage if any denied)
    func requestAllPermissions(completion: @escaping (Bool, String?) -> Void) {
        let permissions = checkAllPermissions()

        // Check if already granted
        if permissions.camera.isGranted && permissions.microphone.isGranted {
            completion(true, nil)
            return
        }

        // Request camera first if needed
        if !permissions.camera.isGranted {
            if permissions.camera == .denied {
                completion(false, "카메라 권한이 필요합니다. 설정에서 권한을 허용해 주세요.")
                return
            }

            requestCameraPermission { [weak self] cameraGranted in
                guard let self = self else { return }

                if !cameraGranted {
                    completion(false, "카메라 권한이 필요합니다. 설정에서 권한을 허용해 주세요.")
                    return
                }

                // Now check/request microphone
                self.handleMicrophonePermission(completion: completion)
            }
        } else {
            // Camera already granted, handle microphone
            handleMicrophonePermission(completion: completion)
        }
    }

    private func handleMicrophonePermission(completion: @escaping (Bool, String?) -> Void) {
        let micStatus = checkMicrophonePermission()

        if micStatus.isGranted {
            completion(true, nil)
            return
        }

        if micStatus == .denied {
            completion(false, "마이크 권한이 필요합니다. 설정에서 권한을 허용해 주세요.")
            return
        }

        requestMicrophonePermission { granted in
            if granted {
                completion(true, nil)
            } else {
                completion(false, "마이크 권한이 필요합니다. 설정에서 권한을 허용해 주세요.")
            }
        }
    }

    // MARK: - Open Settings

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
            logWarning("Cannot open app settings", category: .permission)
            return
        }

        logDebug("Opening app settings", category: .permission)
        UIApplication.shared.open(url)
    }

    // MARK: - Private Helpers

    private func mapAVStatus(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
}

// MARK: - Error Messages
extension PermissionManager {
    enum ErrorMessage {
        static let cameraRequired = "카메라 권한이 필요합니다. 설정에서 권한을 허용해 주세요."
        static let microphoneRequired = "마이크 권한이 필요합니다. 설정에서 권한을 허용해 주세요."
        static let allRequired = "카메라/마이크 권한이 필요합니다. 설정에서 권한을 허용해 주세요."
        static let genderRequired = "매칭을 시작하려면 먼저 성별을 선택해주세요."
    }
}
