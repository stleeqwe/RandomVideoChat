import SwiftUI

struct SplashView: View {
    @Binding var showSplash: Bool
    
    var body: some View {
        ZStack {
            // 배경색
            Color.black
                .ignoresSafeArea()
            
            // 로고 대신 앱 이름 텍스트 (나중에 로고 이미지로 교체)
            VStack {
                Text("Random")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Video Chat")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            // 2초 후 메인화면으로 전환
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showSplash = false
                }
            }
        }
    }
}
