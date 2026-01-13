import SwiftUI
import UIKit

// 🎯 新增：用于处理点击外部关闭 alert 的自定义视图类
class TapDetectingView: UIView {
    weak var alertController: UIAlertController?
    weak var dismissHandler: AlertDismissHandler?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        // 检查视图层级
        if superview != nil {
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        
        // 首先检查点是否在当前视图范围内
        if !bounds.contains(point) {
            return super.hitTest(point, with: event)
        }
        
        // 检查视图是否能够接收事件
        // 🎯 修复：移除 alpha 检查，因为即使 alpha 很小，视图也应该能接收事件
        if !isUserInteractionEnabled || isHidden {
            return super.hitTest(point, with: event)
        }
        
        guard let alertController = alertController else {
            return super.hitTest(point, with: event)
        }
        
        // 检查点击位置是否在 alert.view 外部
        if alertController.view.superview != nil {
            let alertFrame = alertController.view.convert(alertController.view.bounds, to: self)
            
            if !alertFrame.contains(point) {
                DispatchQueue.main.async {
                    alertController.dismiss(animated: true)
                }
                return self // 返回自己，表示处理了这个点击
            } else {
                return nil // 返回 nil，让系统继续查找其他视图
            }
        }
        
        // 如果点击在 alert 内部，让系统正常处理
        return nil
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        _ = super.point(inside: point, with: event)
        return true // 🎯 强制返回 true，确保视图能接收所有触摸事件
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
    }
    
    // 🎯 新增：清理方法
    func cleanup() {
        self.removeFromSuperview()
    }
}

// 🎯 新增：用于处理点击外部关闭 alert 的辅助类
class AlertDismissHandler: NSObject, UIGestureRecognizerDelegate {
    weak var alertController: UIAlertController?
    
    // 🎯 新增：实现 UIGestureRecognizerDelegate，允许同时识别其他手势
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // 🎯 新增：允许手势识别器识别点击
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        guard let alertController = alertController else {
            return false
        }
        
        if touch.view == nil {
            return true
        }
        
        // 检查触摸点是否在 alert 视图内部
        if let alertSuperview = alertController.view.superview {
            let touchLocation = touch.location(in: alertSuperview)
            let alertFrame = alertController.view.convert(alertController.view.bounds, to: alertSuperview)
            
            
            // 如果触摸点在 alert 视图内部，不处理（让 alert 内部的按钮处理）
            if alertFrame.contains(touchLocation) {
                return false
            }
        }
        
        return true
    }
    
    // 🎯 新增：允许手势识别器开始识别
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    @objc func handleTapOutside(_ gesture: UITapGestureRecognizer) {
        
        guard let alertController = alertController else {
            return
        }
        
        guard gesture.view != nil else {
            return
        }
        
        // 🎯 简化逻辑：直接检查点击位置是否在 alert.view 外部
        let alertViewLocation = gesture.location(in: alertController.view.superview)
        if let alertSuperview = alertController.view.superview {
            // 检查点击位置是否在 alert.view 的 frame 外部
            let alertFrame = alertController.view.convert(alertController.view.bounds, to: alertSuperview)
            
            if !alertFrame.contains(alertViewLocation) {
                alertController.dismiss(animated: true)
            } else {
            }
        } else {
            // 如果找不到 superview，直接关闭
            alertController.dismiss(animated: true)
        }
    }
}

struct SearchButton: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var diamondManager: DiamondManager
    @Binding var isLoading: Bool
    @Binding var isUserBlacklisted: Bool
    let onSearch: () -> Void
    let onRecharge: () -> Void
    // 🎯 新增：钻石为0时的随机匹配回调
    let onRandomMatch: ((LocationRecord) -> Void)?
    
    var body: some View {
        Button(action: handleButtonAction) {
            SearchButtonContent(
                isLoading: isLoading,
                isUserBlacklisted: isUserBlacklisted
            )
        }
        .disabled(isButtonCurrentlyDisabled)
        .background(buttonBackgroundColor)
        .cornerRadius(10)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .onChange(of: isLoading) { oldValue, newValue in
        }
        .onChange(of: locationManager.location) { oldValue, newValue in
        }
        .onChange(of: isUserBlacklisted) { oldValue, newValue in
        }
    }
    
    private var isButtonCurrentlyDisabled: Bool {
        // 🎯 修改：即使钻石为0也不禁用按钮（会随机匹配排行榜/推荐榜）
        let disabled = isLoading || locationManager.location == nil || isUserBlacklisted
        return disabled
    }
    
    private var buttonBackgroundColor: Color {
        if isUserBlacklisted { return .gray }
        return (locationManager.location != nil && diamondManager.hasEnoughDiamonds(2)) ? .blue : .gray
    }
    
    private var accessibilityLabel: String {
        if isLoading { return "寻找中，请稍候" }
        if isUserBlacklisted { return "已被禁用，无法使用" }
        if locationManager.location == nil { return "需要位置权限才能寻找" }
        if !diamondManager.hasEnoughDiamonds(2) { return "钻石不足，需要充值" }
        return "寻找按钮"
    }
    
    private var accessibilityHint: String {
        if isLoading { return "正在搜索附近用户" }
        if isUserBlacklisted { return "您的账户已被禁用" }
        if locationManager.location == nil { return "点击获取位置权限" }
        if !diamondManager.hasEnoughDiamonds(2) { return "点击进行充值" }
        return "点击开始寻找附近用户"
    }
    
    private func handleButtonAction() {
        // 🎯 修改：先检查本地余额，如果不足则从服务器重新验证
        let localHasEnough = diamondManager.checkDiamondsWithDebug(2)
        
        if localHasEnough {
            onSearch()
        } else {
            // 🎯 新增：从服务器重新验证钻石余额
            diamondManager.checkDiamondsWithServerConfirmation(2) { hasEnough in
                if hasEnough {
                    onSearch()
                } else {
                    // 🎯 新增：钻石为0时，随机匹配排行榜/推荐榜的一条
                    self.performRandomMatchFromRankings()
                }
            }
        }
    }
    
    // 🎯 新增：从排行榜和推荐榜中随机选择一条
    private func performRandomMatchFromRankings() {
        // 🎯 修改：直接从 UserDefaults 读取数据
        guard let userId = UserDefaultsManager.getCurrentUserId(), !userId.isEmpty else {
            showNoDataAlert()
            return
        }
        
        // 🎯 新增：检查1小时内免费匹配次数限制（最多6次）
        if !UserDefaultsManager.canPerformFreeMatch(userId: userId) {
            // 超过限制，显示"免费寻找额度已用完"的弹窗
            showFreeQuotaExhaustedAlert()
            return
        }
        
        // 从 UserDefaults 读取推荐榜数据
        let recommendationItems = UserDefaultsManager.getTop20Recommendations(userId: userId)
        
        // 从 UserDefaults 读取排行榜数据
        let rankingUserScores = UserDefaultsManager.getTop20RankingUserScores(userId: userId)
        
        // 合并推荐榜和排行榜的数据（最多40条）
        var allRecords: [LocationRecord] = []
        
        // 添加推荐榜数据（转换为 LocationRecord）

        for item in recommendationItems {
            let record = item.toLocationRecord()
            allRecords.append(record)
        }
        
        // 添加排行榜数据（转换为 LocationRecord）

        for userScore in rankingUserScores {
            if let latitude = userScore.latitude, let longitude = userScore.longitude {
                let record = LocationRecord(
                    id: 0,
                    objectId: userScore.id,
                    timestamp: ISO8601DateFormatter().string(from: Date()),
                    latitude: latitude,
                    longitude: longitude,
                    accuracy: 0.0,
                    userId: userScore.id,
                    userName: userScore.userName,
                    loginType: userScore.loginType,
                    userEmail: userScore.userEmail,
                    userAvatar: userScore.userAvatar,
                    deviceId: userScore.deviceId ?? "",
                    clientTimestamp: nil,
                    timezone: nil,
                    status: "active",
                    recordCount: nil,
                    likeCount: userScore.likeCount,
                    placeName: nil,
                    reason: nil
                )
                allRecords.append(record)
            }
        }
        
        // 🎯 新增：去重处理（推荐榜和排行榜可能有重复用户）
        var uniqueRecords: [LocationRecord] = []
        var seenUserIds = Set<String>()
        
        for record in allRecords {
            if seenUserIds.contains(record.userId) {
                continue
            }
            seenUserIds.insert(record.userId)
            uniqueRecords.append(record)
        }
        
        // 🎯 新增：如果没有数据，提示用户先打开排行榜获取免费寻找额度
        guard !uniqueRecords.isEmpty else {
            showNoDataAlert()
            return
        }
        
        // 🎯 新增：排除历史记录
        // 获取历史记录中的用户ID（从UserDefaults加载）
        let historyKey = getRandomMatchHistoryKey()
        
        var excludedUserIds = Set<String>()
        
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([RandomMatchHistory].self, from: data) {
            excludedUserIds = Set(history.map { $0.record.userId })
        }
        
        // 过滤掉历史记录中的用户
        let availableRecords = uniqueRecords.filter { record in
            let recordUserId = record.userId
            let isInExcluded = excludedUserIds.contains(recordUserId)
            return !isInExcluded
        }
        
        // 🎯 新增：如果没有可用记录，显示"免费寻找额度已用完"
        guard !availableRecords.isEmpty else {
            // 显示提示：免费额度已用完
            showFreeQuotaExhaustedAlert()
            return
        }
        
        // 从可用记录中随机选择一条
        if let randomRecord = availableRecords.randomElement() {
            // 🎯 新增：记录免费匹配时间戳（在成功匹配后）
            UserDefaultsManager.recordFreeMatch(userId: userId)
            
            // 调用随机匹配回调
            if let onRandomMatch = onRandomMatch {
                onRandomMatch(randomRecord)
            }
        }
    }
    
    // 🎯 新增：获取历史记录的存储键
    private func getRandomMatchHistoryKey() -> String {
        // 🎯 修复：使用正确的键名 "current_user_email" 而不是 "currentUserEmail"
        let loginType = UserDefaultsManager.getLoginType()
        let email = UserDefaultsManager.getCurrentUserEmail()
        let userId = UserDefaultsManager.getCurrentUserId()
        
        // 🎯 新增：如果 email 为空但 loginType 是 apple，尝试通过 userId 获取 email
        var finalEmail = email
        if finalEmail.isEmpty, let loginType = loginType, loginType == "apple", let userId = userId {
            if let appleEmail = UserDefaultsManager.getAppleUserEmail(userId: userId) {
                finalEmail = appleEmail
            }
        }
        
        // 根据不同用户类型返回不同的键
        if let loginType = loginType {
            if loginType == "apple" {
                if !finalEmail.isEmpty {
                    return "randomMatchHistory_apple_\(finalEmail)"
                } else if let userId = userId {
                    // 🎯 新增：如果 email 为空，使用 userId 作为标识（兼容旧数据）
                    return "randomMatchHistory_apple_\(userId)"
                }
            } else if loginType == "internal" {
                if !finalEmail.isEmpty {
                    return "randomMatchHistory_internal_\(finalEmail)"
                } else if let userId = userId {
                    // 🎯 新增：如果 email 为空，使用 userId 作为标识
                    return "randomMatchHistory_internal_\(userId)"
                }
            }
        }
        
        // 游客用户使用设备ID
        if let deviceID = UIDevice.current.identifierForVendor?.uuidString {
            let shortDeviceID = String(deviceID.prefix(8))
            return "randomMatchHistory_guest_\(shortDeviceID)"
        }
        
        // 默认键（不应该到这里）
        return "randomMatchHistory_default"
    }
    
    // 🎯 新增：显示数据为空的提示（排行榜和推荐榜未加载）
    private func showNoDataAlert() {
        DispatchQueue.main.async {
            // 🎯 修改：在显示弹窗前，先自动打开排行榜
            NotificationCenter.default.post(name: NSNotification.Name("ShowRankingSheet"), object: nil)
            
            // 延迟一下再显示弹窗，让排行榜先打开
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 创建并显示Alert
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    let alert = UIAlertController(
                        title: "💡 免费寻找额度需要获取",
                        message: "你已获取免费额度",
                        preferredStyle: .alert
                    )
                    
                    // 体验虚拟匹配按钮
                    alert.addAction(UIAlertAction(title: "体验 - 开启虚拟匹配", style: .default) { _ in
                        // 发送通知打开排行榜（虽然已经自动打开，但保留按钮以防万一）
                        NotificationCenter.default.post(name: NSNotification.Name("ShowRankingSheet"), object: nil)
                    })
                    
                    // 充值钻石按钮（备选方案）
                    alert.addAction(UIAlertAction(title: "💎 充值钻石 - 开启真实匹配", style: .default) { _ in
                        self.onRecharge()
                    })
                    
                    // 取消按钮
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
                    })
                    
                    // 找到最顶层的 ViewController 来显示 Alert
                    var topController = rootViewController
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    
                    // 🎯 新增：创建 dismiss handler 来处理点击外部关闭
                    let dismissHandler = AlertDismissHandler()
                    dismissHandler.alertController = alert
                    
                    // 🎯 新增：创建清理函数
                    let cleanupViews: () -> Void = {
                        
                        // 移除所有 TapDetectingView
                        if let tapDetectingView = objc_getAssociatedObject(alert, "tapDetectingView") as? TapDetectingView {
                            tapDetectingView.cleanup()
                        }
                        
                        if let windowTapDetectingView = objc_getAssociatedObject(alert, "windowTapDetectingView") as? TapDetectingView {
                            windowTapDetectingView.cleanup()
                        }
                        
                        if let adjacentTapDetectingView = objc_getAssociatedObject(alert, "adjacentTapDetectingView") as? TapDetectingView {
                            adjacentTapDetectingView.cleanup()
                        }
                        
                        // 移除手势识别器
                        if let tapGesture = objc_getAssociatedObject(alert, "tapGesture") as? UITapGestureRecognizer {
                            tapGesture.view?.removeGestureRecognizer(tapGesture)
                        }
                        
                        if let directTapGesture = objc_getAssociatedObject(alert, "directTapGesture") as? UITapGestureRecognizer {
                            directTapGesture.view?.removeGestureRecognizer(directTapGesture)
                        }
                        
                        // 清除所有关联对象
                        objc_setAssociatedObject(alert, "dismissHandler", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        objc_setAssociatedObject(alert, "tapGesture", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        objc_setAssociatedObject(alert, "directTapGesture", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        objc_setAssociatedObject(alert, "tapDetectingView", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        objc_setAssociatedObject(alert, "windowTapDetectingView", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        objc_setAssociatedObject(alert, "adjacentTapDetectingView", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        objc_setAssociatedObject(alert, "cleanupViews", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        objc_setAssociatedObject(alert, "dismissObserver", nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                        
                    }
                    
                    // 保存 cleanupViews 以便在关闭时调用
                    objc_setAssociatedObject(alert, "cleanupViews", cleanupViews, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    
                    // 🎯 新增：监听弹窗关闭事件
                    // 使用 KVO 监听 alert 的 isBeingDismissed
                    let observer = alert.observe(\.isBeingDismissed, options: [.new]) { _, change in
                        if change.newValue == true {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                cleanupViews()
                            }
                        }
                    }
                    
                    // 保存 observer 以便后续移除
                    objc_setAssociatedObject(alert, "dismissObserver", observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    
                    topController.present(alert, animated: true) {
                        
                        // 🎯 新增：在 alert 显示后，添加点击外部关闭功能
                        // 延迟一下，确保 alert 的视图已经添加到视图层次结构中
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            
                            // 🎯 优先使用 UITransitionView（alert 的直接父视图）
                            var targetView: UIView? = nil
                            
                            // 方法1：优先使用 superview（UITransitionView），这是 alert 的直接容器
                            if let transitionView = alert.view.superview {
                                targetView = transitionView
                            }
                            
                            // 方法2：如果方法1失败，尝试 superview?.superview (UIWindow)
                            if targetView == nil {
                                if let windowView = alert.view.superview?.superview {
                                    targetView = windowView
                                }
                            }
                            
                            // 方法3：如果都失败，尝试找到 window
                            if targetView == nil {
                                if let window = UIApplication.shared.connectedScenes
                                    .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                                   let windowView = window.windows.first {
                                    targetView = windowView
                                }
                            }
                            
                            if let alertSuperview = targetView {
                                
                                // 🎯 使用文件顶部定义的 TapDetectingView 类来捕获点击事件
                                // 创建自定义视图
                                let tapDetectingView = TapDetectingView(frame: alertSuperview.bounds)
                                tapDetectingView.backgroundColor = UIColor.clear
                                tapDetectingView.isUserInteractionEnabled = true
                                tapDetectingView.alpha = 1.0 // 🎯 修复：设置为 1.0，确保能接收事件（视图本身是透明的，所以不影响视觉效果）
                                tapDetectingView.alertController = alert
                                tapDetectingView.dismissHandler = dismissHandler
                                
                                
                                // 🎯 尝试多种方式添加视图
                                // 方法1: 放在最底层（可能被其他视图遮挡）
                                alertSuperview.insertSubview(tapDetectingView, at: 0)
                                
                                // 方法2: 也尝试添加到 UIWindow 上（更上层）
                                if let window = alert.view.superview?.superview as? UIWindow {
                                    let windowTapView = TapDetectingView(frame: window.bounds)
                                    windowTapView.backgroundColor = UIColor.clear
                                    windowTapView.isUserInteractionEnabled = true
                                    windowTapView.alpha = 1.0 // 🎯 修复：设置为 1.0，确保能接收事件
                                    windowTapView.alertController = alert
                                    windowTapView.dismissHandler = dismissHandler
                                    
                                    // 找到 alert 视图在 window 中的位置，将 tapView 放在它下面
                                    if let alertSuperview = alert.view.superview {
                                        let alertIndex = window.subviews.firstIndex(of: alertSuperview) ?? 0
                                        window.insertSubview(windowTapView, at: alertIndex)
                                        objc_setAssociatedObject(alert, "windowTapDetectingView", windowTapView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                                    }
                                }
                                
                                // 方法3: 尝试将视图放在 alert.view 的同一层级（紧挨着）
                                if let alertSuperview = alert.view.superview {
                                    let alertIndex = alertSuperview.subviews.firstIndex(of: alert.view) ?? 0
                                    // 如果 alert 在索引 4，我们尝试在索引 3 添加另一个视图
                                    if alertIndex > 0 {
                                        let adjacentTapView = TapDetectingView(frame: alertSuperview.bounds)
                                        adjacentTapView.backgroundColor = UIColor.clear
                                        adjacentTapView.isUserInteractionEnabled = true
                                        adjacentTapView.alpha = 1.0 // 🎯 修复：设置为 1.0，确保能接收事件
                                        adjacentTapView.alertController = alert
                                        adjacentTapView.dismissHandler = dismissHandler
                                        alertSuperview.insertSubview(adjacentTapView, at: alertIndex)
                                        objc_setAssociatedObject(alert, "adjacentTapDetectingView", adjacentTapView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                                    }
                                }
                                
                                
                                // 延迟检查视图状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    _ = tapDetectingView.superview
                                }
                                
                                // 保存引用
                                objc_setAssociatedObject(alert, "dismissHandler", dismissHandler, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                                objc_setAssociatedObject(alert, "tapDetectingView", tapDetectingView, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                                
                                // 🎯 备选方案：也在 UITransitionView 上添加手势识别器
                                let tapGesture = UITapGestureRecognizer(target: dismissHandler, action: #selector(AlertDismissHandler.handleTapOutside(_:)))
                                tapGesture.cancelsTouchesInView = false
                                tapGesture.delegate = dismissHandler
                                tapGesture.numberOfTapsRequired = 1
                                tapGesture.numberOfTouchesRequired = 1
                                alertSuperview.addGestureRecognizer(tapGesture)
                                
                                objc_setAssociatedObject(alert, "tapGesture", tapGesture, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                            } else {
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 🎯 新增：显示免费额度用完的提示
    private func showFreeQuotaExhaustedAlert() {
        DispatchQueue.main.async {
            // 🎯 修改：在显示弹窗前，先自动打开排行榜
            NotificationCenter.default.post(name: NSNotification.Name("ShowRankingSheet"), object: nil)
            
            // 延迟一下再显示弹窗，让排行榜先打开
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // 创建并显示Alert
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    
                    let alert = UIAlertController(
                        title: "💎 免费寻找额度已用完",
                        message: "可以选择：\n• 充值钻石解锁更多用户\n• 等待排行榜更新\n• 在历史记录中查看之前匹配的用户",
                        preferredStyle: .alert
                    )
                    
                    // 充值按钮
                    alert.addAction(UIAlertAction(title: "💎 充值钻石 - 开启真实匹配", style: .default) { _ in
                        self.onRecharge()
                    })
                    
                    // 查看历史按钮
                    alert.addAction(UIAlertAction(title: "📜 查看历史记录", style: .default) { _ in
                        // 发送通知打开历史记录
                        NotificationCenter.default.post(name: NSNotification.Name("ShowProfileSheet"), object: nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(name: NSNotification.Name("ShowHistoryFromProfile"), object: nil)
                        }
                    })
                    
                    // 取消按钮
                    alert.addAction(UIAlertAction(title: "取消", style: .cancel))
                    
                    // 找到最顶层的 ViewController 来显示 Alert
                    var topController = rootViewController
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }
                    
                    topController.present(alert, animated: true)
                }
            }
        }
    }
    
    // 获取位置权限状态描述
    private func getLocationPermissionStatus() -> String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "未确定"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限制"
        case .authorizedWhenInUse:
            return "使用时授权"
        case .authorizedAlways:
            return "始终授权"
        @unknown default:
            return "未知状态"
        }
    }
}
