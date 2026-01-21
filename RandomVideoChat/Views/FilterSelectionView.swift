import SwiftUI

// MARK: - FilterSelectionView
/// 얼굴 필터 선택 UI
struct FilterSelectionView: View {
    @ObservedObject var filterRenderer = FaceFilterRenderer.shared
    @Binding var isPresented: Bool
    
    @State private var selectedCategory: FilterCategory = .arOverlay
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView
            
            // 카테고리 탭
            categoryTabs
            
            // 필터 그리드
            filterGrid
            
            // ARKit 상태 표시
            if filterRenderer.currentFilter.requiresARKit {
                arkitStatusView
            }
        }
        .background(Color.black.opacity(0.9))
        .cornerRadius(20, corners: [.topLeft, .topRight])
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            Text("필터 선택")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding()
    }
    
    // MARK: - Category Tabs
    private var categoryTabs: some View {
        HStack(spacing: 12) {
            ForEach(FilterCategory.allCases.filter { $0 != .none }, id: \.self) { category in
                CategoryTabButton(
                    title: category.rawValue,
                    isSelected: selectedCategory == category
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
    }
    
    // MARK: - Filter Grid
    private var filterGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 16) {
                // "없음" 옵션 (항상 표시)
                FilterItemView(
                    filter: .none,
                    isSelected: filterRenderer.currentFilter == .none
                ) {
                    selectFilter(.none)
                }
                
                // 현재 카테고리의 필터들
                ForEach(selectedCategory.filters, id: \.id) { filter in
                    FilterItemView(
                        filter: filter,
                        isSelected: filterRenderer.currentFilter == filter
                    ) {
                        selectFilter(filter)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(height: 120)
    }
    
    // MARK: - ARKit Status
    private var arkitStatusView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ARFaceTrackingManager.shared.faceDetected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            
            Text(ARFaceTrackingManager.shared.faceDetected ? "얼굴 감지됨" : "얼굴을 찾는 중...")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text("품질: \(ARFaceTrackingManager.shared.trackingQuality.description)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
    }
    
    // MARK: - Actions
    private func selectFilter(_ filter: FaceFilterType) {
        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // 필터 적용
        AgoraManager.shared.setFaceFilter(filter)
    }
}

// MARK: - Category Tab Button
struct CategoryTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
                )
        }
    }
}

// MARK: - Filter Item View
struct FilterItemView: View {
    let filter: FaceFilterType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color.white.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: filter.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                
                // 라벨
                Text(filter.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(width: 80)
        }
    }
}

// MARK: - Compact Filter Button (VideoCallView용)
struct FilterToggleButton: View {
    @Binding var showFilterSelection: Bool
    @ObservedObject var filterRenderer = FaceFilterRenderer.shared
    
    var body: some View {
        Button {
            showFilterSelection.toggle()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 44, height: 44)
                
                Image(systemName: filterRenderer.currentFilter == .none ? "face.smiling" : "face.smiling.fill")
                    .font(.system(size: 20))
                    .foregroundColor(filterRenderer.currentFilter == .none ? .white : .yellow)
            }
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview
#if DEBUG
struct FilterSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.ignoresSafeArea()
            
            VStack {
                Spacer()
                FilterSelectionView(isPresented: .constant(true))
            }
        }
    }
}
#endif
