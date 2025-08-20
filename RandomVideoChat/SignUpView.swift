import SwiftUI

@available(iOS 15.0, *)
struct SignUpView: View {
    @Binding var isAuthenticated: Bool
    
    var body: some View {
        // Legacy wrapper - redirect to unified OnboardingView
        if #available(iOS 15.0, *) {
            OnboardingView(isAuthenticated: $isAuthenticated)
        } else {
            Text("iOS 15.0+ required for onboarding").foregroundColor(.white)
        }
    }
}

#Preview {
    SignUpView(isAuthenticated: .constant(false))
}