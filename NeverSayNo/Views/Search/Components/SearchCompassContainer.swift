import SwiftUI

struct SearchCompassContainer: View {
    @ObservedObject var locationManager: LocationManager
    let randomRecord: LocationRecord?
    @State private var showAppIconBackground: Bool = true // 🎯 新增：控制是否显示app图标背景（高手时默认true）
    
    // 🎯 新增：检查当前匹配用户是否在前3名中
    private var isTop3RankingUser: Bool {
        guard let userId = randomRecord?.userId else { return false }
        let top3UserIds = UserDefaultsManager.getTop3RankingUserIds()
        return top3UserIds.contains(userId)
    }
    
    // 🎯 新增：计算指针是否应该显示
    private var shouldShowPointer: Bool {
        // 如果是高手，根据showAppIconBackground决定：显示app图标时隐藏指针，显示默认轮盘时显示指针
        if isTop3RankingUser {
            return !showAppIconBackground
        }
        return true
    }
    
    var body: some View {
        ZStack {
            // 🎯 修改：根据showAppIconBackground动态切换背景
            if isTop3RankingUser && showAppIconBackground {
                // 高手且显示app图标背景
                CompassBackgroundView(isTop3RankingUser: true)
            } else {
                // 默认轮盘背景
                CompassBackgroundView(isTop3RankingUser: false)
            }
            
            CompassDirectionMarkersView(locationManager: locationManager)
            SearchPointerView(
                locationManager: locationManager,
                randomRecord: randomRecord,
                showPointer: Binding(
                    get: { shouldShowPointer },
                    set: { _ in }
                )
            )
            
            // 🎯 修改：点击手势 - 高手匹配卡片时切换背景和指针显示
            Color.clear
                .frame(width: 250, height: 250)
                .contentShape(Circle())
                .onTapGesture {
                    if isTop3RankingUser {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showAppIconBackground.toggle()
                        }
                    }
                }
        }
        .onChange(of: randomRecord?.userId) { oldValue, newValue in
            // 🎯 新增：当匹配用户变化时，如果是高手，重置为app图标背景
            if isTop3RankingUser {
                showAppIconBackground = true
            }
        }
        .onAppear {
            // 初始化：高手默认显示app图标背景
            if isTop3RankingUser {
                showAppIconBackground = true
            }
        }
    }
}
