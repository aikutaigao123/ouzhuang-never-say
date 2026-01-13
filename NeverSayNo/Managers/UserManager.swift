import SwiftUI
import AuthenticationServices
import LeanCloud

// 用户状态管理器
class UserManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var currentUser: UserInfo?
    @Published var isLoggedIn: Bool = false
    @Published var userNameFromServer: String? = nil // 🎯 新增：从 UserNameRecord 表读取的用户名（主页面和个人信息界面共享）
    
    let userDefaults = UserDefaults.standard
    var diamondManager: DiamondManager?
    
    override init() {
        super.init()
        loadUserFromDefaults()
    }
    
    func loginAsGuest() {
        // 获取设备唯一标识符
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 使用设备ID作为游客用户的唯一标识
        let guestID = "guest_\(deviceID)"
        let shortDeviceID = String(deviceID.prefix(8))
        let displayName = "游客\(shortDeviceID)"
        
        
        // 创建LeanCloud用户
        let user = LCUser()
        user.username = LCString(guestID)
        user.password = LCString(deviceID) // 使用设备ID作为密码
        
        // 设置用户属性
        do {
            try user.set("displayName", value: displayName)
            try user.set("loginType", value: "guest")
            try user.set("deviceId", value: deviceID)
        } catch {
        }
        
        // 尝试注册新用户
        user.signUp { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.handleGuestLoginSuccess(user: user, guestID: guestID, displayName: displayName, deviceID: deviceID)
                    
                case .failure:
                    // 如果用户已存在，尝试登录
                    self?.loginExistingGuest(guestID: guestID, password: deviceID, displayName: displayName, deviceID: deviceID)
                }
            }
        }
    }
    
    // 处理游客登录成功
    private func handleGuestLoginSuccess(user: LCUser, guestID: String, displayName: String, deviceID: String) {
        // 获取LeanCloud用户信息
        guard let objectId = user.objectId?.stringValue else {
            return
        }
        
        
        // 创建本地用户信息 - 🎯 修改：统一使用 objectId 作为 userId
        let guestUser = UserInfo(
            id: objectId, // 使用LeanCloud的objectId
            userId: objectId, // 🎯 修改：统一使用 objectId 作为 userId，与 Apple 和内部账号保持一致
            fullName: displayName,
            email: nil,
            loginType: .guest
        )
        
        self.currentUser = guestUser
        self.isLoggedIn = true
        
        // 保存登录状态到本地存储 - 🎯 修改：使用 objectId
        UserDefaultsManager.setLoggedIn(true)
        UserDefaultsManager.setCurrentUserId(objectId) // 🎯 修改：使用 objectId 而不是 guestID
        UserDefaultsManager.setCurrentUserName(displayName)
        UserDefaultsManager.setLoginType("guest")
        
        // 保存映射关系：guestID -> objectId（用于后续登录时查找）
        userDefaults.set(objectId, forKey: "guest_leancloud_id_\(guestID)")
        userDefaults.set(guestID, forKey: "guest_username_\(objectId)") // 反向映射：objectId -> guestID
        userDefaults.set(displayName, forKey: "guest_user_name_\(objectId)") // 🎯 修改：使用 objectId 作为 key
        
        // 设置钻石管理器的用户信息 - 🎯 修改：使用 objectId
        diamondManager?.setCurrentUser(userId: objectId, loginType: "guest", userName: displayName, userEmail: nil)
        
        // 记录登录到LeanCloud - 🎯 修改：使用 objectId
        LeanCloudService.shared.recordLogin(
            userId: objectId, // 🎯 修改：使用 objectId 而不是 guestID
            userName: displayName,
            userEmail: nil,
            loginType: "guest",
            deviceId: deviceID
        ) { [weak self] success in
            if success {
                // 🎯 新增：更新上次上传时间，确保重新登录时能正常上传
                self?.lastLoginRecordUploadTime = Date()
            }
        }
        
        // 初始化 IM 触发器
        initializeIMTrigger()
        
    }
    
    // 登录已存在的游客账号
    private func loginExistingGuest(guestID: String, password: String, displayName: String, deviceID: String) {
        
        _ = LCUser.logIn(username: guestID, password: password) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(object: let user):
                    self?.handleGuestLoginSuccess(user: user, guestID: guestID, displayName: displayName, deviceID: deviceID)
                    
                case .failure:
                    // 如果登录也失败，回退到本地游客模式
                    self?.fallbackToLocalGuest(guestID: guestID, displayName: displayName, deviceID: deviceID)
                }
            }
        }
    }
    
    // 回退到本地游客模式
    private func fallbackToLocalGuest(guestID: String, displayName: String, deviceID: String) {
        
        let guestUser = UserInfo(
            id: guestID,
            userId: guestID,
            fullName: displayName,
            email: nil,
            loginType: .guest
        )
        
        self.currentUser = guestUser
        self.isLoggedIn = true
        
        // 保存登录状态到本地存储
        UserDefaultsManager.setLoggedIn(true)
        UserDefaultsManager.setCurrentUserId(guestID)
        UserDefaultsManager.setCurrentUserName(displayName)
        UserDefaultsManager.setLoginType("guest")
        
        // 设置钻石管理器的用户信息
        diamondManager?.setCurrentUser(userId: guestID, loginType: "guest", userName: displayName, userEmail: nil)
        
        // 初始化 IM 触发器
        initializeIMTrigger()
        
    }
    
    func loginAsGuestWithInfo(displayName: String, email: String?, completion: @escaping () -> Void = {}) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        
        
        // 获取设备唯一标识符
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 使用设备ID作为游客用户的唯一标识
        let guestID = "guest_\(deviceID)"
        
        // 使用用户提供的显示名称，如果为空则使用默认名称
        let finalDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 
            "游客\(String(deviceID.prefix(8)))" : displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let finalEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        
        // 创建LeanCloud用户
        let user = LCUser()
        user.username = LCString(guestID)
        user.password = LCString(deviceID) // 使用设备ID作为密码
        
        // 设置用户属性
        do {
            try user.set("displayName", value: finalDisplayName)
            try user.set("loginType", value: "guest")
            try user.set("deviceId", value: deviceID)
            if let email = finalEmail, !email.isEmpty {
                try user.set("email", value: email)
            }
        } catch {
        }
        
        // 尝试注册新用户
        user.signUp { [weak self] result in
            DispatchQueue.main.async {
                
                switch result {
                case .success:
                    self?.handleGuestLoginSuccessWithInfo(user: user, guestID: guestID, displayName: finalDisplayName, email: finalEmail, deviceID: deviceID)
                    // 登录成功后调用completion
                    completion()
                    
                case .failure:
                    // 如果用户已存在，尝试登录
                    self?.loginExistingGuestWithInfo(guestID: guestID, password: deviceID, displayName: finalDisplayName, email: finalEmail, deviceID: deviceID) {
                        completion()
                    }
                }
            }
        }
    }
    
    // 处理带信息的游客登录成功
    private func handleGuestLoginSuccessWithInfo(user: LCUser, guestID: String, displayName: String, email: String?, deviceID: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        
        // 获取LeanCloud用户信息
        guard let objectId = user.objectId?.stringValue else {
            return
        }
        
        
        // 创建本地用户信息 - 🎯 修改：统一使用 objectId 作为 userId
        let guestUser = UserInfo(
            id: objectId, // 使用LeanCloud的objectId
            userId: objectId, // 🎯 修改：统一使用 objectId 作为 userId，与 Apple 和内部账号保持一致
            fullName: displayName,
            email: email,
            loginType: .guest
        )
        
        self.currentUser = guestUser
        self.isLoggedIn = true
        
        // 🎯 修复：从服务器加载用户名并设置 userNameFromServer
        LeanCloudService.shared.fetchUserNameByUserId(objectId: objectId) { [weak self] serverName, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 如果加载失败，使用本地用户名
                    self?.userNameFromServer = displayName
                    // 🎯 新增：更新 UserDefaults
                    UserDefaultsManager.setCurrentUserName(displayName, userId: objectId)
                } else if let serverName = serverName, !serverName.isEmpty {
                    self?.userNameFromServer = serverName
                    // 🎯 新增：更新 UserDefaults（如果与本地不同）
                    let localUserName = UserDefaultsManager.getCurrentUserName(userId: objectId)
                    if localUserName != serverName {
                        UserDefaultsManager.setCurrentUserName(serverName, userId: objectId)
                    }
                } else {
                    self?.userNameFromServer = displayName
                    // 🎯 新增：更新 UserDefaults
                    UserDefaultsManager.setCurrentUserName(displayName, userId: objectId)
                }
            }
        }
        
        // 保存登录状态到本地存储 - 🎯 修改：使用 objectId
        UserDefaultsManager.setLoggedIn(true)
        UserDefaultsManager.setCurrentUserId(objectId) // 🎯 修改：使用 objectId 而不是 guestID
        UserDefaultsManager.setCurrentUserName(displayName)
        UserDefaultsManager.setLoginType("guest")
        if let email = email, !email.isEmpty {
            UserDefaultsManager.setCurrentUserEmail(email)
        }
        
        // 保存映射关系：guestID -> objectId（用于后续登录时查找）
        userDefaults.set(objectId, forKey: "guest_leancloud_id_\(guestID)")
        userDefaults.set(guestID, forKey: "guest_username_\(objectId)") // 反向映射：objectId -> guestID
        userDefaults.set(displayName, forKey: "guest_user_name_\(objectId)") // 🎯 修改：使用 objectId 作为 key
        if let email = email, !email.isEmpty {
            userDefaults.set(email, forKey: "guest_user_email_\(objectId)") // 🎯 修改：使用 objectId 作为 key
        }
        
        // 设置钻石管理器的用户信息 - 🎯 修改：使用 objectId
        diamondManager?.setCurrentUser(userId: objectId, loginType: "guest", userName: displayName, userEmail: email)
        
        // 记录登录到LeanCloud - 🎯 修改：使用 objectId
        LeanCloudService.shared.recordLogin(
            userId: objectId, // 🎯 修改：使用 objectId 而不是 guestID
            userName: displayName,
            userEmail: email,
            loginType: "guest",
            deviceId: deviceID
        ) { [weak self] success in
            if success {
                // 🎯 新增：更新上次上传时间，确保重新登录时能正常上传
                self?.lastLoginRecordUploadTime = Date()
            }
        }
        
        // 初始化 IM 触发器
        initializeIMTrigger()
        
    }
    
    // 登录已存在的带信息游客账号
    private func loginExistingGuestWithInfo(guestID: String, password: String, displayName: String, email: String?, deviceID: String, completion: @escaping () -> Void = {}) {
        
        _ = LCUser.logIn(username: guestID, password: password) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(object: let user):
                    self?.handleGuestLoginSuccessWithInfo(user: user, guestID: guestID, displayName: displayName, email: email, deviceID: deviceID)
                    completion()
                    
                case .failure:
                    // 如果登录也失败，回退到本地游客模式
                    self?.fallbackToLocalGuestWithInfo(guestID: guestID, displayName: displayName, email: email, deviceID: deviceID)
                    completion()
                }
            }
        }
    }
    
    // 回退到本地游客模式（带信息）
    private func fallbackToLocalGuestWithInfo(guestID: String, displayName: String, email: String?, deviceID: String) {
        
        let guestUser = UserInfo(
            id: guestID,
            userId: guestID,
            fullName: displayName,
            email: email,
            loginType: .guest
        )
        
        self.currentUser = guestUser
        self.isLoggedIn = true
        
        // 保存登录状态到本地存储
        UserDefaultsManager.setLoggedIn(true)
        UserDefaultsManager.setCurrentUserId(guestID)
        UserDefaultsManager.setCurrentUserName(displayName)
        UserDefaultsManager.setLoginType("guest")
        if let email = email, !email.isEmpty {
            UserDefaultsManager.setCurrentUserEmail(email)
        }
        
        // 设置钻石管理器的用户信息
        diamondManager?.setCurrentUser(userId: guestID, loginType: "guest", userName: displayName, userEmail: email)
        
        // 初始化 IM 触发器
        initializeIMTrigger()
        
    }
    
    func extractUsernameFromEmail(_ email: String) -> String {
        let username = email.components(separatedBy: "@").first ?? email
        return username.isEmpty ? "Apple用户" : username
    }
    
    private func loadUserFromDefaults() {
        // 检查是否已登录
        guard UserDefaultsManager.isLoggedIn() else {
            return
        }
        
        // 获取保存的用户信息
        guard let userId = UserDefaultsManager.getCurrentUserId(),
              let loginType = UserDefaultsManager.getLoginType() else {
            return
        }
        
        
        // 恢复用户信息
        restoreUserFromDefaults(userId: userId, loginType: loginType)
    }
    
    private func restoreUserFromDefaults(userId: String, loginType: String) {
        
        let userName = UserDefaultsManager.getCurrentUserName()
        var userEmail = UserDefaultsManager.getCurrentUserEmail()
        
        // 🎯 新增：如果是游客账号且 userId 是旧格式（guest_xxx），尝试迁移到 objectId
        var finalUserId = userId
        if loginType == "guest" && userId.hasPrefix("guest_") {
            // 检查是否有保存的 objectId 映射
            if let objectId = userDefaults.string(forKey: "guest_leancloud_id_\(userId)") {
                // 找到映射，使用 objectId
                finalUserId = objectId
                // 更新保存的 userId
                UserDefaultsManager.setCurrentUserId(objectId)
                // 迁移用户名和邮箱的 key
                if let savedName = userDefaults.string(forKey: "guest_user_name_\(userId)") {
                    userDefaults.set(savedName, forKey: "guest_user_name_\(objectId)")
                }
                if let savedEmail = userDefaults.string(forKey: "guest_user_email_\(userId)") {
                    userDefaults.set(savedEmail, forKey: "guest_user_email_\(objectId)")
                    userEmail = savedEmail
                }
            }
            // 如果没有找到映射，保持使用 guestID（回退情况）
        }
        
        // 如果是游客账号，尝试从新的 key 获取邮箱
        if loginType == "guest" && userEmail.isEmpty {
            if let savedEmail = UserDefaultsManager.getGuestUserEmail(userId: finalUserId) {
                userEmail = savedEmail
            }
        }
        
        // 根据登录类型创建用户信息
        let userLoginType: UserInfo.LoginType
        switch loginType {
        case "apple":
            userLoginType = .apple
        case "guest":
            userLoginType = .guest
        default:
            return
        }
        
        let user = UserInfo(
            id: finalUserId, // 🎯 修改：使用迁移后的 userId
            userId: finalUserId, // 🎯 修改：使用迁移后的 userId
            fullName: userName,
            email: userEmail.isEmpty ? nil : userEmail,
            loginType: userLoginType
        )
        
        
        // 恢复用户状态
        self.currentUser = user
        self.isLoggedIn = true
        
        // 🎯 修复：从服务器加载用户名并设置 userNameFromServer
        LeanCloudService.shared.fetchUserNameByUserId(objectId: finalUserId) { [weak self] serverName, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 如果加载失败，使用本地用户名
                    self?.userNameFromServer = userName
                    // 🎯 新增：更新 UserDefaults
                    UserDefaultsManager.setCurrentUserName(userName, userId: finalUserId)
                } else if let serverName = serverName, !serverName.isEmpty {
                    self?.userNameFromServer = serverName
                    // 🎯 新增：更新 UserDefaults（如果与本地不同）
                    let localUserName = UserDefaultsManager.getCurrentUserName(userId: finalUserId)
                    if localUserName != serverName {
                        UserDefaultsManager.setCurrentUserName(serverName, userId: finalUserId)
                    }
                } else {
                    self?.userNameFromServer = userName
                    // 🎯 新增：更新 UserDefaults
                    UserDefaultsManager.setCurrentUserName(userName, userId: finalUserId)
                }
            }
        }
        
        // 设置钻石管理器的用户信息
        diamondManager?.setCurrentUser(
            userId: finalUserId, // 🎯 修改：使用迁移后的 userId
            loginType: loginType,
            userName: userName,
            userEmail: userEmail.isEmpty ? nil : userEmail
        )
        
        // 初始化 IM 触发器
        initializeIMTrigger()
        
        // 上传登录记录（自动登录时也需要记录）
        uploadLoginRecordForAutoLogin(userId: finalUserId, userName: userName, loginType: loginType) // 🎯 修改：使用迁移后的 userId
    }
    
    /**
     * 为自动登录上传登录记录
     */
    private func uploadLoginRecordForAutoLogin(userId: String, userName: String, loginType: String) {
        
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 获取用户邮箱信息
        let userEmail = UserDefaultsManager.getCurrentUserEmail()
        
        // 🎯 修改：统一使用 LoginRecord 表，取消 InternalLoginRecord 表
        // 上传到LoginRecord表（统一登录记录表）
        LeanCloudService.shared.recordLogin(
            userId: userId,
            userName: userName,
            userEmail: userEmail.isEmpty ? nil : userEmail,
            loginType: loginType,
            deviceId: deviceID
        ) { [weak self] success in
            if success {
                // 更新上次上传时间，防止启动时重复上传
                self?.lastLoginRecordUploadTime = Date()
            } else {
            }
        }
    }
    
    /**
     * 为应用从后台恢复上传登录记录
     * 🎯 新增：当应用从后台恢复到前台时，也上传一次登录记录
     * 
     * 注意：应用启动时也会触发 didBecomeActive，但此时 loadUserFromDefaults() 已经上传过登录记录
     * 为了区分启动和恢复，使用时间戳判断：如果距离上次上传时间小于5秒，则认为是启动时的重复调用，跳过
     */
    var lastLoginRecordUploadTime: Date? // 🔧 修改：改为 internal，允许 extension 访问
    
    /**
     * 🎯 新增：更新上次登录记录上传时间
     * 用于手动登录成功后更新上传时间，确保后续的上传逻辑正常工作
     */
    func updateLastLoginRecordUploadTime() {
        lastLoginRecordUploadTime = Date()
    }
    
    func uploadLoginRecordForForeground() {
        // 检查用户是否已登录
        guard isLoggedIn, let user = currentUser else {
            return
        }
        
        // 🔧 防止启动时重复上传：如果距离上次上传时间小于5秒，跳过
        if let lastUploadTime = lastLoginRecordUploadTime {
            let timeInterval = Date().timeIntervalSince(lastUploadTime)
            if timeInterval < 5.0 {
                return
            }
        }
        
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        let loginType: String
        switch user.loginType {
        case .apple:
            loginType = "apple"
        case .guest:
            loginType = "guest"
        }
        
        // 获取用户邮箱信息
        let userEmail = UserDefaultsManager.getCurrentUserEmail()
        
        // 上传到LoginRecord表
        LeanCloudService.shared.recordLogin(
            userId: user.userId,
            userName: user.fullName,
            userEmail: userEmail.isEmpty ? nil : userEmail,
            loginType: loginType,
            deviceId: deviceID
        ) { [weak self] success in
            if success {
                // 更新上次上传时间
                self?.lastLoginRecordUploadTime = Date()
            } else {
            }
        }
    }
}
