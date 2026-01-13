import SwiftUI
import AuthenticationServices
import LeanCloud

// Apple登录相关方法
extension UserManager {
    func loginWithApple(credential: ASAuthorizationAppleIDCredential, completion: @escaping () -> Void = {}) {
        
        let userID = credential.user
        let givenName = credential.fullName?.givenName ?? ""
        let familyName = credential.fullName?.familyName ?? ""
        let fullName = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
        let email = credential.email
        
        
        // 添加详细的调试信息
        
        // 读取本地存储备用数据
        let storedName = userDefaults.string(forKey: "apple_user_name_\(userID)")
        let storedEmail = userDefaults.string(forKey: "apple_user_email_\(userID)")
        
        // 确定显示的用户名 - 优化逻辑
        var displayName: String
        
        
        // 检查是否是首次登录且有姓名信息
        let isFirstLoginWithName = credential.fullName != nil && !fullName.isEmpty
        
        if isFirstLoginWithName {
            // 首次登录且有姓名，使用Apple ID获取的姓名
            displayName = fullName
            userDefaults.set(fullName, forKey: "apple_user_name_\(userID)")
        } else if let storedName = storedName, !storedName.isEmpty {
            // 非首次登录或没有姓名，优先使用本地存储
            displayName = storedName
        } else if let email = email ?? storedEmail {
            // 没有姓名但有邮箱，从邮箱提取用户名
            displayName = extractUsernameFromEmail(email)
            userDefaults.set(displayName, forKey: "apple_user_name_\(userID)")
        } else {
            // 最后回退到默认名称
            displayName = "Apple用户"
        }
        
        
        // 邮箱处理 - 优化逻辑
        let finalEmail: String?
        if let email = email {
            // 如果Apple ID返回了邮箱，保存并使用
            finalEmail = email
            userDefaults.set(email, forKey: "apple_user_email_\(userID)")
        } else if let storedEmail = storedEmail {
            // 使用本地存储的邮箱
            finalEmail = storedEmail
        } else {
            finalEmail = nil
        }
        
        // 使用LeanCloud Sign in with Apple (简化版本)
        loginWithLeanCloudApple(credential: credential, displayName: displayName, email: finalEmail, completion: completion)
    }
    
    private func loginWithLeanCloudApple(credential: ASAuthorizationAppleIDCredential, displayName: String, email: String?, completion: @escaping () -> Void = {}) {
        // 添加详细的调试信息
        
        // 构建LeanCloud authData结构 - 符合LeanCloud文档要求
        var lcAppleData: [String: Any] = [
            "uid": credential.user  // 必填：用户标识符
        ]
        
        
        // 添加identity_token（如果可用）- 用于验证身份
        if let identityToken = credential.identityToken,
           let identityTokenString = String(data: identityToken, encoding: .utf8) {
            lcAppleData["identity_token"] = identityTokenString
        } else {
        }
        
        // 添加authorization code（如果可用）- 用于获取access_token
        if let authorizationCode = credential.authorizationCode,
           let codeString = String(data: authorizationCode, encoding: .utf8) {
            lcAppleData["code"] = codeString
        } else {
        }
        
        
        // 按照LeanCloud文档要求，使用lc_apple包装
        let authData: [String: Any] = [
            "lc_apple": lcAppleData
        ]
        
        // 打印authData结构用于调试
        
        // 验证authData格式
        if let lcApple = authData["lc_apple"] as? [String: Any] {
            if lcApple["uid"] as? String != nil {
            } else {
            }
        } else {
        }
        
        // 使用LeanCloud SDK进行Apple登录
        let user = LCUser()
        user.logIn(authData: lcAppleData, platform: .apple) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // LeanCloud登录成功，获取用户信息
                    if let objectId = user.objectId,
                       let objectIdString = objectId.stringValue {
                        let credentialUserId = credential.user

                        let appleUser = UserInfo(
                            id: objectIdString,
                            userId: objectIdString,
                            fullName: displayName,
                            email: email,
                            loginType: .apple
                        )

                        self?.currentUser = appleUser
                        self?.isLoggedIn = true

                        // 设置钻石管理器的用户信息（统一使用 objectId 作为 userId）
                        self?.diamondManager?.setCurrentUser(userId: objectIdString, loginType: "apple", userName: displayName, userEmail: email)

                        // 记录登录到LeanCloud（使用authData结构，userId统一为objectId）
                        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                        LeanCloudService.shared.recordAppleLoginWithAuthData(
                            userId: objectIdString,
                            userName: displayName,
                            userEmail: email,
                            authData: authData,
                            deviceId: deviceID
                        ) { [weak self] success in
                            if success {
                                // 🎯 新增：更新上次上传时间，确保重新登录时能正常上传
                                self?.updateLastLoginRecordUploadTime()
                            }
                        }

                        // 记录 Apple 原始 credential.user 与 objectId 的映射
                        UserDefaults.standard.set(credentialUserId, forKey: "apple_original_uid_\(objectIdString)")

                        // 同步 Apple 用户名缓存：同时写入 objectId 和 credential.user 两个 key（兼容旧数据）
                        if !displayName.isEmpty {
                            UserDefaults.standard.set(displayName, forKey: "apple_user_name_\(objectIdString)")
                            UserDefaults.standard.set(displayName, forKey: "apple_user_name_\(credentialUserId)")
                        }

                        if let email = email, !email.isEmpty {
                            UserDefaults.standard.set(email, forKey: "apple_user_email_\(objectIdString)")
                            UserDefaults.standard.set(email, forKey: "apple_user_email_\(credentialUserId)")
                        }

                        // 初始化 IM 触发器
                        self?.initializeIMTrigger()

                        // 保存用户登录状态到本地存储（使用 objectId）
                        UserDefaultsManager.setLoggedIn(true)
                        UserDefaultsManager.setCurrentUserId(objectIdString)
                        UserDefaultsManager.setCurrentUserName(displayName)
                        UserDefaultsManager.setLoginType("apple")
                        if let email = email {
                            UserDefaultsManager.setCurrentUserEmail(email)
                        }

                        // 额外持久化 Apple credential.user，便于后续可能的登录流程
                        UserDefaults.standard.set(credentialUserId, forKey: "apple_credential_user_last")

                        // 调用完成回调
                        completion()
                    } else {
                    }
                    
                case .failure:
                    
                    // 尝试使用不同的authData格式
                    let alternativeAuthData = self?.createAlternativeAuthData(credential: credential)
                    if let altAuthData = alternativeAuthData {
                        self?.tryAlternativeLogin(credential: credential, displayName: displayName, email: email, authData: altAuthData, completion: completion)
                    } else {
                        // 登录失败，回退到本地登录方式
                        self?.fallbackToLocalAppleLogin(credential: credential, displayName: displayName, email: email, authData: authData, completion: completion)
                    }
                }
            }
        }
    }
    
    // 创建备用authData格式
    private func createAlternativeAuthData(credential: ASAuthorizationAppleIDCredential) -> [String: Any]? {
        
        // 尝试不同的格式
        var alternativeData: [String: Any] = [:]
        
        // 格式1: 直接使用uid作为顶级字段
        alternativeData["uid"] = credential.user
        
        if let identityToken = credential.identityToken,
           let identityTokenString = String(data: identityToken, encoding: .utf8) {
            alternativeData["identity_token"] = identityTokenString
        }
        
        if let authorizationCode = credential.authorizationCode,
           let codeString = String(data: authorizationCode, encoding: .utf8) {
            alternativeData["code"] = codeString
        }
        
        
        // 格式2: 使用apple作为平台名
        let appleFormat: [String: Any] = [
            "apple": alternativeData
        ]
        
        
        return appleFormat
    }
    
    // 尝试备用登录方式
    private func tryAlternativeLogin(credential: ASAuthorizationAppleIDCredential, displayName: String, email: String?, authData: [String: Any], completion: @escaping () -> Void = {}) {
        
        let user = LCUser()
        user.logIn(authData: authData, platform: .apple) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 处理成功登录
                    if let objectId = user.objectId,
                       let objectIdString = objectId.stringValue {
                        let credentialUserId = credential.user
                        let appleUser = UserInfo(
                            id: objectIdString,
                            userId: objectIdString,
                            fullName: displayName,
                            email: email,
                            loginType: .apple
                        )
                        
                        self?.currentUser = appleUser
                        self?.isLoggedIn = true
                        
                        // 🎯 修复：从服务器加载用户名并设置 userNameFromServer
                        LeanCloudService.shared.fetchUserNameByUserId(objectId: objectIdString) { [weak self] serverName, error in
                            DispatchQueue.main.async {
                                if error != nil {
                                    // 如果加载失败，使用本地用户名
                                    self?.userNameFromServer = displayName
                                    // 🎯 新增：更新 UserDefaults
                                    UserDefaultsManager.setCurrentUserName(displayName, userId: objectIdString)
                                } else if let serverName = serverName, !serverName.isEmpty {
                                    self?.userNameFromServer = serverName
                                    // 🎯 新增：更新 UserDefaults（如果与本地不同）
                                    let localUserName = UserDefaultsManager.getCurrentUserName(userId: objectIdString)
                                    if localUserName != serverName {
                                        UserDefaultsManager.setCurrentUserName(serverName, userId: objectIdString)
                                    }
                                } else {
                                    self?.userNameFromServer = displayName
                                    // 🎯 新增：更新 UserDefaults
                                    UserDefaultsManager.setCurrentUserName(displayName, userId: objectIdString)
                                }
                            }
                        }
                        
                        // 设置钻石管理器的用户信息（统一使用 objectId 作为 userId）
                        self?.diamondManager?.setCurrentUser(userId: objectIdString, loginType: "apple", userName: displayName, userEmail: email)

                        // 记录登录到LeanCloud（userId 统一为 objectId）
                        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                        LeanCloudService.shared.recordAppleLoginWithAuthData(
                            userId: objectIdString,
                            userName: displayName,
                            userEmail: email,
                            authData: authData,
                            deviceId: deviceID
                        ) { [weak self] success in
                            if success {
                                // 🎯 新增：更新上次上传时间，确保重新登录时能正常上传
                                self?.updateLastLoginRecordUploadTime()
                            }
                        }

                        // 映射 & 缓存
                        UserDefaults.standard.set(credentialUserId, forKey: "apple_original_uid_\(objectIdString)")
                        if !displayName.isEmpty {
                            UserDefaults.standard.set(displayName, forKey: "apple_user_name_\(objectIdString)")
                            UserDefaults.standard.set(displayName, forKey: "apple_user_name_\(credentialUserId)")
                        }
                        if let email = email, !email.isEmpty {
                            UserDefaults.standard.set(email, forKey: "apple_user_email_\(objectIdString)")
                            UserDefaults.standard.set(email, forKey: "apple_user_email_\(credentialUserId)")
                        }

                        // 初始化 IM 触发器
                        self?.initializeIMTrigger()

                        // 保存登录状态到本地存储（使用 objectId）
                        UserDefaultsManager.setLoggedIn(true)
                        UserDefaultsManager.setCurrentUserId(objectIdString)
                        UserDefaultsManager.setCurrentUserName(displayName)
                        UserDefaultsManager.setLoginType("apple")
                        if let email = email {
                            UserDefaultsManager.setCurrentUserEmail(email)
                        }

                        // 保留最后一次 credential.user
                        UserDefaults.standard.set(credentialUserId, forKey: "apple_credential_user_last")

                        // 调用完成回调
                        completion()
                    }
                    
                case .failure:
                    
                    // 最终回退到本地登录方式
                    self?.fallbackToLocalAppleLogin(credential: credential, displayName: displayName, email: email, authData: authData, completion: completion)
                }
            }
        }
    }
    
    // 回退到本地Apple登录方式
    private func fallbackToLocalAppleLogin(credential: ASAuthorizationAppleIDCredential, displayName: String, email: String?, authData: [String: Any], completion: @escaping () -> Void = {}) {
        
        let userID = credential.user
        
        let appleUser = UserInfo(
            id: userID,
            userId: userID,
            fullName: displayName,
            email: email,
            loginType: .apple
        )
        
        self.currentUser = appleUser
        self.isLoggedIn = true
        
        // 🎯 修复：尝试从服务器加载用户名（使用 credential.user 作为 userId）
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userID) { [weak self] serverName, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 如果加载失败，使用本地用户名
                    self?.userNameFromServer = displayName
                    // 🎯 新增：更新 UserDefaults
                    UserDefaultsManager.setCurrentUserName(displayName, userId: userID)
                } else if let serverName = serverName, !serverName.isEmpty {
                    self?.userNameFromServer = serverName
                    // 🎯 新增：更新 UserDefaults（如果与本地不同）
                    let localUserName = UserDefaultsManager.getCurrentUserName(userId: userID)
                    if localUserName != serverName {
                        UserDefaultsManager.setCurrentUserName(serverName, userId: userID)
                    }
                } else {
                    self?.userNameFromServer = displayName
                    // 🎯 新增：更新 UserDefaults
                    UserDefaultsManager.setCurrentUserName(displayName, userId: userID)
                }
            }
        }
        
        // 设置钻石管理器的用户信息
        diamondManager?.setCurrentUser(userId: userID, loginType: "apple", userName: displayName, userEmail: email)
        
        // 记录登录到LeanCloud（使用authData结构）
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        LeanCloudService.shared.recordAppleLoginWithAuthData(
            userId: userID,
            userName: displayName,
            userEmail: email,
            authData: authData,
            deviceId: deviceID
        ) { [weak self] success in
            if success {
                // 🎯 新增：更新上次上传时间，确保重新登录时能正常上传
                self?.lastLoginRecordUploadTime = Date()
            }
        }
        
        // 初始化 IM 触发器
        initializeIMTrigger()
        
        // 保存用户登录状态到本地存储
        UserDefaultsManager.setLoggedIn(true)
        UserDefaultsManager.setCurrentUserId(userID)
        UserDefaultsManager.setCurrentUserName(displayName)
        UserDefaultsManager.setLoginType("apple")
        if let email = email {
            UserDefaultsManager.setCurrentUserEmail(email)
        }
        
        
        // 调用完成回调
        completion()
    }
    
    // 重新获取 Apple ID 信息
    func refreshAppleIDInfo() {
        guard let currentUser = currentUser, currentUser.loginType == .apple else {
            return
        }
        
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // 添加更多调试信息
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // 新增：强制刷新Apple ID信息的方法
    func forceRefreshAppleIDInfo() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // 测试 Apple ID 姓名获取
    func testAppleIDNameRetrieval() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    // 检查是否需要更新 Apple ID 信息
    func checkAndUpdateAppleIDInfo() {
        guard let currentUser = currentUser, currentUser.loginType == .apple else { return }
        
        // 检查是否有设置跳转记录
        if let userId = UserDefaultsManager.getCurrentUserId(),
           let jumpTime = UserDefaultsManager.getSettingsJumpTime(userId: userId) {
            let timeSinceJump = Date().timeIntervalSince(jumpTime)
            
            // 如果距离跳转时间超过5秒，说明用户可能已经返回
            if timeSinceJump > 5 {
                refreshAppleIDInfo()
                // 清除跳转时间记录
                if let userId = UserDefaultsManager.getCurrentUserId() {
                    UserDefaultsManager.removeSettingsJumpTime(userId: userId)
                }
            }
        }
    }
}
