import SwiftUI

@available(iOS 15.0, *)
struct AppleSignInView: View {
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        // Legacy wrapper - redirect to SignUpView which contains the unified onboarding
        SignUpView(isAuthenticated: $isAuthenticated)
    }
}

#Preview {
    AppleSignInView(isAuthenticated: .constant(false))
}