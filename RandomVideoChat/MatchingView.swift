import SwiftUI

// MatchingView.swift에서 수정할 부분

struct MatchingView: View {
    @Binding var isPresented: Bool
    @State private var navigateToVideoCall = false
    @StateObject private var matchingManager = MatchingManager.shared
    @State private var hasStartedMatching = false
    @State private var isReturningFromCall = false  // 통화에서 돌아온 상태 추적
    
    var body: some View {
        ZStack {
            // 배경
            Color.black
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // 통화에서 돌아온 경우 매칭 상태 표시
                if isReturningFromCall {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(3)
                        
                        Text("SEARCHING...")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else if matchingManager.isMatching && !matchingManager.isMatched {
                    // 매칭 중 인디케이터
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(3)
                        
                        Text("SEARCHING...")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else if matchingManager.isMatched && !navigateToVideoCall {
                    // 매칭 완료 - 짧게 표시 후 바로 이동
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("MATCHED!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .onAppear {
                        // 0.5초 후 자동으로 영상통화로 이동
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            navigateToVideoCall = true
                        }
                    }
                }
                
                Spacer()
                
                // 스와이프 안내
                if !matchingManager.isMatched {
                    HStack {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.white.opacity(0.6))
                        Text("SWIPE DOWN TO CANCEL")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 && !matchingManager.isMatched {
                        // 아래로 스와이프 - 매칭 취소
                        print("⬇️ 스와이프: 매칭 취소")
                        matchingManager.cancelMatching()
                        isPresented = false
                    }
                }
        )
        .onAppear {
            // 통화에서 돌아온 경우가 아닐 때만 매칭 시작
            if !hasStartedMatching && !isReturningFromCall {
                matchingManager.startMatching()
                hasStartedMatching = true
            }
        }
        .onDisappear {
            // 화면을 떠날 때 매칭 상태 초기화
            if !navigateToVideoCall {
                matchingManager.cancelMatching()
                hasStartedMatching = false
            }
        }
        .onChange(of: navigateToVideoCall) { newValue in
            if !newValue && hasStartedMatching {
                // 영상통화에서 돌아온 경우
                isReturningFromCall = true
                
                // 매칭 상태 초기화
                matchingManager.isMatched = false
                matchingManager.matchedUserId = nil
                
                // 2초 후 새로운 매칭 시작
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isReturningFromCall = false
                    hasStartedMatching = false
                    
                    // 새로운 매칭 시작
                    matchingManager.startMatching()
                    hasStartedMatching = true
                }
            }
        }
        .fullScreenCover(isPresented: $navigateToVideoCall) {
            VideoCallView()
        }
    }
}
