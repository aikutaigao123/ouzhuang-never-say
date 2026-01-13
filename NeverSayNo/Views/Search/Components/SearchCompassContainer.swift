import SwiftUI

struct SearchCompassContainer: View {
    @ObservedObject var locationManager: LocationManager
    let randomRecord: LocationRecord?
    @State private var showCompassDetailView: Bool = false // 🎯 新增：控制是否显示罗盘详情界面
    @State private var isTop3RankingUser: Bool = false // 🎯 新增：改为 @State 以便监听变化
    
    init(locationManager: LocationManager, randomRecord: LocationRecord?) {
        self.locationManager = locationManager
        self.randomRecord = randomRecord
    }
    
    // 🎯 新增：检查当前匹配用户是否在前3名中
    private func updateIsTop3RankingUser() {
        guard let userId = randomRecord?.userId,
              let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            isTop3RankingUser = false
            return
        }
        let top3UserIds = UserDefaultsManager.getTop3RankingUserIds(userId: currentUserId)
        let newValue = top3UserIds.contains(userId)
        isTop3RankingUser = newValue
    }
    
    var body: some View {
        ZStack {
            // 🎯 修改：根据是否为前3名用户显示不同背景
            CompassBackgroundView(isTop3RankingUser: isTop3RankingUser)
                .allowsHitTesting(false) // 🎯 新增：背景不拦截点击
            
            CompassDirectionMarkersView(locationManager: locationManager)
                .allowsHitTesting(false) // 🎯 新增：方向标记不拦截点击
            
            SearchPointerView(
                locationManager: locationManager,
                randomRecord: randomRecord,
                showPointer: .constant(isTop3RankingUser ? false : true) // 🎯 修改：前3名用户隐藏指针，其他用户显示指针
            )
            .allowsHitTesting(false) // 🎯 新增：指针不拦截点击
            
            // 🎯 新增：添加一个透明的点击捕获层，确保点击事件能被捕获
            Color.clear
                .frame(width: 250, height: 250)
                .contentShape(Circle())
                .onTapGesture {
                    // 🎯 新增：检查目标位置信息
                    guard let record = randomRecord else {
                        return
                    }
                    
                    // 🎯 检查目标位置的经纬度是否有效（0.0 可能是无效位置）
                    let hasValidLocation = record.latitude != 0.0 && record.longitude != 0.0
                    guard hasValidLocation else {
                        return
                    }
                    
                    // 前3名用户点击时，进入详情界面
                    showCompassDetailView = true
                }
        }
        .frame(width: 250, height: 250) // 🎯 新增：限制容器大小，避免被其他视图遮挡
        .contentShape(Circle()) // 🎯 新增：设置点击区域为圆形
        .zIndex(1000) // 🎯 修改：提高 zIndex，确保罗盘容器在最上层，不被匹配卡片遮挡
        .onTapGesture {
            // 🎯 新增：检查目标位置信息
            guard let record = randomRecord else {
                return
            }
            
            // 🎯 检查目标位置的经纬度是否有效（0.0 可能是无效位置）
            let hasValidLocation = record.latitude != 0.0 && record.longitude != 0.0
            guard hasValidLocation else {
                return
            }
            
            // 前3名用户点击时，进入详情界面
            showCompassDetailView = true
        }
        .fullScreenCover(isPresented: $showCompassDetailView) {
            CompassDetailView(
                locationManager: locationManager,
                randomRecord: randomRecord
            )
        }
        .onAppear {
            updateIsTop3RankingUser()
        }
        .onChange(of: randomRecord?.userId) { oldValue, newValue in
            updateIsTop3RankingUser()
        }
        .onChange(of: isTop3RankingUser) { oldValue, newValue in
            // 状态已更新
        }
        // 🎯 移除：UserDefaults.didChangeNotification 太宽泛，会导致频繁更新
    }
}

