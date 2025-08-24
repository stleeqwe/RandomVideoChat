import SwiftUI
import StoreKit

@available(iOS 15.0, *)
struct HeartPurchaseView: View {
    @StateObject private var storeManager = StoreKitManager.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showPurchaseSuccess = false
    @State private var showPurchaseError = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // 배경 그라데이션
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.6, blue: 0.7),
                        Color(red: 0.98, green: 0.8, blue: 0.85)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // 헤더
                    VStack(spacing: 15) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                            .shadow(color: .red.opacity(0.5), radius: 10)
                        
                        Text("하트 구매")
                            .font(.custom("Carter One", size: 32))
                            .foregroundColor(.white)
                        
                        Text("현재 보유 하트: \(userManager.currentUser?.heartCount ?? 0)개")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 40)
                    
                    // 상품 카드
                    VStack(spacing: 20) {
                        if storeManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                                .frame(height: 200)
                        } else if storeManager.products.isEmpty {
                            VStack(spacing: 15) {
                                Image(systemName: "wifi.slash")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("상품을 불러올 수 없습니다")
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Button("다시 시도") {
                                    Task {
                                        await storeManager.loadProducts()
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(25)
                            }
                            .frame(height: 200)
                        } else {
                            ForEach(storeManager.products) { product in
                                HeartProductCard(
                                    product: product,
                                    formattedPrice: storeManager.formatPrice(product),
                                    onPurchase: {
                                        Task {
                                            await purchaseHeart(product)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 안내 문구
                    VStack(spacing: 10) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("구매한 하트는 즉시 사용 가능합니다")
                        }
                        
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                            Text("매일 자정 출석 시 하트 1개 무료 지급")
                        }
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    // 구매 복원 버튼
                    Button(action: {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }) {
                        Text("구매 복원")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .underline()
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .task {
            await storeManager.loadProducts()
        }
        .alert("구매 완료", isPresented: $showPurchaseSuccess) {
            Button("확인") { 
                dismiss()
            }
        } message: {
            Text("하트 1개가 추가되었습니다!")
        }
        .alert("구매 실패", isPresented: $showPurchaseError) {
            Button("확인") { }
        } message: {
            Text(storeManager.errorMessage ?? "구매 중 오류가 발생했습니다.")
        }
    }
    
    private func purchaseHeart(_ product: Product) async {
        do {
            let success = try await storeManager.purchase(product)
            if success {
                showPurchaseSuccess = true
            }
        } catch {
            showPurchaseError = true
        }
    }
}

@available(iOS 15.0, *)
struct HeartProductCard: View {
    let product: Product
    let formattedPrice: String
    let onPurchase: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 상품 정보
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                        
                        Text("하트 1개")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("영상통화 60초 연장")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // 가격
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedPrice)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.15)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // 구매 버튼
            Button(action: onPurchase) {
                Text("구매하기")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.red)
            }
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
