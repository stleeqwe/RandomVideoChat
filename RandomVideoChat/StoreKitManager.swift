import Foundation
import StoreKit
import FirebaseAuth
import FirebaseFirestore

@available(iOS 15.0, *)
class StoreKitManager: NSObject, ObservableObject {
    static let shared = StoreKitManager()
    
    // 상품 ID (App Store Connect에서 설정해야 함)
    private let heartProductID = "com.pukaworks.5sec.heart.single"
    
    @Published var products: [Product] = []
    @Published var purchasedProducts: [Product] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var updateListenerTask: Task<Void, Error>?
    private let db = Firestore.firestore()
    
    override init() {
        super.init()
        startUpdateListener()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Product Loading
    @MainActor
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // App Store Connect에 등록된 상품 ID로 상품 정보 가져오기
            let products = try await Product.products(for: [heartProductID])
            self.products = products
            
            print("✅ 상품 로드 성공: \(products.count)개")
            for product in products {
                print("   - \(product.displayName): \(product.displayPrice)")
            }
        } catch {
            print("❌ 상품 로드 실패: \(error)")
            errorMessage = "상품을 불러올 수 없습니다."
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase
    @MainActor
    func purchase(_ product: Product) async throws -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            // 구매 시작
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // 구매 검증
                switch verification {
                case .verified(let transaction):
                    // 구매 성공. 트랜잭션 처리는 중앙 리스너(Transaction.updates)에서 수행
                    // 여기서는 UI에 성공을 알리고 종료만 처리
                    isLoading = false
                    return true
                    
                case .unverified(_, let error):
                    // 검증 실패
                    print("❌ 구매 검증 실패: \(error)")
                    errorMessage = "구매 검증에 실패했습니다."
                    isLoading = false
                    return false
                }
                
            case .userCancelled:
                // 사용자가 구매 취소
                print("ℹ️ 사용자가 구매를 취소했습니다")
                isLoading = false
                return false
                
            case .pending:
                // 구매 대기 중 (부모 승인 등)
                print("⏳ 구매 승인 대기 중")
                errorMessage = "구매 승인을 기다리고 있습니다."
                isLoading = false
                return false
                
            @unknown default:
                isLoading = false
                return false
            }
        } catch {
            print("❌ 구매 실패: \(error)")
            errorMessage = "구매 중 오류가 발생했습니다."
            isLoading = false
            throw error
        }
    }
    
    // MARK: - Grant Heart
    private func grantHeart() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let userRef = db.collection("users").document(uid)
        
        do {
            // Firestore에서 하트 1개 추가
            try await userRef.updateData([
                "heartCount": FieldValue.increment(Int64(1)),
                "purchasedHearts": FieldValue.increment(Int64(1)),
                "lastPurchaseDate": Timestamp(date: Date())
            ])
            
            // 로컬 상태 업데이트 (이중 증가 방지: Firestore에만 기록, 로컬 모델만 갱신)
            // UserDefaults도 동기화
            let currentHearts = UserDefaults.standard.integer(forKey: "heartCount")
            UserDefaults.standard.set(currentHearts + 1, forKey: "heartCount")
            await MainActor.run {
                if var user = UserManager.shared.currentUser {
                    user.heartCount += 1
                    UserManager.shared.currentUser = user
                }
            }
            
            print("✅ 하트 1개 지급 완료")
        } catch {
            print("❌ 하트 지급 실패: \(error)")
        }
    }
    
    // MARK: - Transaction Updates
    private func startUpdateListener() {
        updateListenerTask = Task {
            // 구매 상태 변경 감지
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // 검증된 트랜잭션 처리
                    if transaction.productID == heartProductID {
                        await grantHeart()
                        await transaction.finish()
                    }
                
                case .unverified(_, let error):
                    print("❌ 트랜잭션 검증 실패: \(error)")
                }
            }
        }
    }
    
    // MARK: - Restore Purchases
    @MainActor
    func restorePurchases() async {
        isLoading = true
        
        do {
            // 이전 구매 내역 복원
            try await AppStore.sync()
            print("✅ 구매 복원 완료")
        } catch {
            print("❌ 구매 복원 실패: \(error)")
            errorMessage = "구매 복원에 실패했습니다."
        }
        
        isLoading = false
    }
    
    // MARK: - Price Formatting
    func formatPrice(_ product: Product) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ko_KR")
        let number = NSDecimalNumber(decimal: product.price)
        return formatter.string(from: number) ?? product.displayPrice
    }
}
