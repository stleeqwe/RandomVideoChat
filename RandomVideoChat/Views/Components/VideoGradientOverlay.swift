import SwiftUI

// MARK: - Video Gradient Overlay
/// Reusable gradient overlay for video views
struct VideoGradientOverlay: View {
    enum Style {
        case standard
        case call

        var stops: [Gradient.Stop] {
            switch self {
            case .standard:
                return [
                    .init(color: Color.black.opacity(0.4), location: 0.0),
                    .init(color: Color.black.opacity(0.05), location: 0.25),
                    .init(color: Color.black.opacity(0.02), location: 0.5),
                    .init(color: Color.black.opacity(0.05), location: 0.75),
                    .init(color: Color.black.opacity(0.7), location: 1.0)
                ]
            case .call:
                return [
                    .init(color: Color.black.opacity(0.6), location: 0.0),
                    .init(color: Color.black.opacity(0.05), location: 0.25),
                    .init(color: Color.clear, location: 0.5),
                    .init(color: Color.black.opacity(0.05), location: 0.75),
                    .init(color: Color.black.opacity(0.7), location: 1.0)
                ]
            }
        }
    }

    let style: Style

    init(style: Style = .standard) {
        self.style = style
    }

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: style.stops),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Camera Off Overlay
/// Overlay shown when camera is turned off
struct CameraOffOverlay: View {
    let message: String

    init(message: String = "카메라 꺼짐") {
        self.message = message
    }

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 16) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            )
    }
}

// MARK: - Camera Placeholder
/// Placeholder shown when camera preview is off
struct CameraPlaceholder: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 200))
                .foregroundColor(.white.opacity(0.3))
        }
    }
}

#Preview {
    ZStack {
        Color.blue
        VideoGradientOverlay(style: .call)
    }
}
