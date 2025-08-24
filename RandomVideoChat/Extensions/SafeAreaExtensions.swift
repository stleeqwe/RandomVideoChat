import SwiftUI

// MARK: - Safe Area Extensions
extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    var safeAreaInsets: UIEdgeInsets {
        keyWindow?.safeAreaInsets ?? .zero
    }
}

// MARK: - View Extensions for Safe Area
extension View {
    var safeAreaTop: CGFloat {
        UIApplication.shared.safeAreaInsets.top
    }
    
    var safeAreaBottom: CGFloat {
        UIApplication.shared.safeAreaInsets.bottom
    }
}