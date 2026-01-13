import SwiftUI
import Foundation

struct OnAppearHelpers {
    // 应用启动时的初始化逻辑
    static func handleAppStartup(
        userManager: UserManager,
        setupIMListener: @escaping () -> Void,
        startMessageRefreshTimer: @escaping () -> Void,
        loadHistoryAndCheckLatestMatch: @escaping () -> Void,
        path: Binding<[String]>
    ) {
        
        // 与用户头像界面一致：不再使用全局缓存，改为各个组件onAppear时实时查询
        // let cacheStartTime = Date()
        // LeanCloudService.shared.initializeGlobalUserCache { success in
        //     // 已删除：不再使用全局缓存
        // }
        
        // 设置 IM 消息监听
        setupIMListener()
        
        // 启动消息刷新定时器
        startMessageRefreshTimer()
        
        // 应用启动时加载历史记录并显示最新一条
        loadHistoryAndCheckLatestMatch()
        
        // 导航路径类型安全检查
        if !path.wrappedValue.isEmpty {
            // 由于path是[String]类型，不需要类型检查
        }
    }
}
