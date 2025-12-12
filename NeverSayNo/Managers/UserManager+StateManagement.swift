import SwiftUI
import AuthenticationServices
import LeanCloud

// 用户状态管理方法
extension UserManager {
    // 🎯 修改：添加完成回调以处理验证结果
    func updateUserName(_ newName: String, completion: @escaping (Bool, String?) -> Void = { _, _ in }) {
        guard let user = currentUser else {
            completion(false, "用户未登录")
            return
        }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            completion(false, "用户名不能为空")
            return
        }
        
        // 🎯 新增：如果用户名没有变化，直接返回成功
        if user.fullName == trimmedName {
            completion(true, nil)
            return
        }
        
        // 🎯 新增：验证用户名唯一性（排除当前用户）
        LeanCloudService.shared.checkUserNameUnique(username: trimmedName, excludingUserId: user.id) { [weak self] isUnique, error in
            guard let self = self else {
                completion(false, "操作失败")
                return
            }
            
            guard isUnique else {
                DispatchQueue.main.async {
                    completion(false, error ?? "用户名已被使用")
                }
                return
            }
            
            // 用户名唯一，继续更新流程
            DispatchQueue.main.async {
                self.performUserNameUpdate(userId: user.id, loginType: user.loginType, newName: trimmedName, userEmail: user.email)
                completion(true, nil)
            }
        }
    }
    
    // 🎯 新增：执行用户名更新的实际逻辑
    private func performUserNameUpdate(userId: String, loginType: UserInfo.LoginType, newName: String, userEmail: String?) {
        // 更新当前用户信息
        guard var user = currentUser else { return }
        user.fullName = newName
        self.currentUser = user

        // 保存到本地存储 - 🔧 统一使用 objectId 作为 userId
        if loginType == .apple {
                userDefaults.set(newName, forKey: "apple_user_name_\(userId)")
            if let originalAppleUID = UserDefaults.standard.string(forKey: "apple_original_uid_\(userId)") {
                userDefaults.set(newName, forKey: "apple_user_name_\(originalAppleUID)")
            }
        } else if loginType == .guest {
            userDefaults.set(newName, forKey: "guest_user_name_\(userId)")
        }

        // 同时更新全局 UserDefaults 中的用户名（用于自动登录恢复）
        UserDefaultsManager.setCurrentUserName(newName)

        // 更新钻石管理器的用户信息 - 🔧 统一使用 objectId 作为 userId
        diamondManager?.setCurrentUser(userId: userId, loginType: loginType == .apple ? "apple" : "guest", userName: newName, userEmail: userEmail)

        // 本地缓存用户名，确保UI立即刷新
        LeanCloudService.shared.cacheUserName(newName, for: userId)

        // 🎯 新增：更新 UserManager 的 userNameFromServer，让主页面和个人信息界面同步
        self.userNameFromServer = newName

        // 立即发送通知，让所有UI立刻显示新用户名
        let loginTypeString = loginType == .apple ? "apple" : "guest"
        let userInfo: [String: Any] = [
            "userName": newName,
            "userId": userId,
            "loginType": loginTypeString
        ]
        NotificationCenter.default.post(name: NSNotification.Name("UserNameUpdated"), object: nil, userInfo: userInfo)

        // 上传用户名到LeanCloud服务器
        LeanCloudService.shared.uploadUserNameIfNotExists(objectId: userId, loginType: loginTypeString, userName: newName, userEmail: userEmail) { success, message in
            DispatchQueue.main.async {
                if success {
                    // 再次广播，确保晚到的观察者也能收到
                    NotificationCenter.default.post(name: NSNotification.Name("UserNameUpdated"), object: nil, userInfo: userInfo)

                    // 静默运行数据同步，确保UserScore表中的数据与最新用户名保持一致

                    // 只同步当前用户的用户名数据 - 🔧 统一使用 objectId 作为 userId
                    LeanCloudService.shared.syncCurrentUserNameData(objectId: userId, loginType: loginTypeString, newUserName: newName) { success in
                    }
                } else {
                }
            }
        }
    }

    // 🎯 修改：添加完成回调以处理验证结果
    func updateUserEmail(_ newEmail: String, completion: @escaping (Bool, String?) -> Void = { _, _ in }) {
        guard let user = currentUser else {
            completion(false, "用户未登录")
            return
        }
        
        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 🎯 新增：如果邮箱没有变化，直接返回成功
        if (user.email ?? "") == trimmedEmail {
            completion(true, nil)
            return
        }
        
        // 🎯 新增：验证邮箱唯一性（排除当前用户）
        LeanCloudService.shared.checkUserEmailUnique(email: trimmedEmail, excludingUserId: user.id) { [weak self] isUnique, error in
            guard let self = self else {
                completion(false, "操作失败")
                return
            }
            
            guard isUnique else {
                DispatchQueue.main.async {
                    completion(false, error ?? "邮箱地址已被使用")
                }
                return
            }
            
            // 邮箱唯一，继续更新流程
            DispatchQueue.main.async {
                self.performUserEmailUpdate(userId: user.id, loginType: user.loginType, newEmail: trimmedEmail)
                completion(true, nil)
            }
        }
    }
    
    // 🎯 新增：执行邮箱更新的实际逻辑
    private func performUserEmailUpdate(userId: String, loginType: UserInfo.LoginType, newEmail: String) {
        guard var user = currentUser else { return }
        user.email = newEmail.isEmpty ? nil : newEmail
        self.currentUser = user

        // 保存到本地存储 - 🔧 统一使用 objectId 作为 userId
        if user.loginType == .apple {
            UserDefaultsManager.setAppleUserEmail(userId: userId, email: newEmail)
            if let originalAppleUID = UserDefaults.standard.string(forKey: "apple_original_uid_\(userId)") {
                UserDefaults.standard.set(newEmail, forKey: "apple_user_email_\(originalAppleUID)")
            }
        } else if user.loginType == .guest {
            UserDefaultsManager.setGuestUserEmail(userId: userId, email: newEmail)
        }

        // 同时更新全局 UserDefaults 中的邮箱（用于自动登录恢复）
        UserDefaultsManager.setCurrentUserEmail(newEmail)
        
        // 🎯 新增：如果设置了真实邮箱（非默认邮箱），重置默认邮箱点击计数
        let isDefaultEmail = newEmail.hasSuffix("@apple.com") || 
                           newEmail.hasSuffix("@guest.com")
        if !isDefaultEmail && !newEmail.isEmpty {
            UserDefaultsManager.resetDefaultEmailSearchClickCount(userId: userId)
        }

        // 更新钻石管理器的用户信息 - 🔧 统一使用 objectId 作为 userId
        diamondManager?.setCurrentUser(userId: userId, loginType: loginType == .apple ? "apple" : "guest", userName: user.fullName, userEmail: user.email)

        // 上传邮箱到LeanCloud服务器 - 与用户名更新逻辑一致
        let loginTypeString = loginType == .apple ? "apple" : "guest"

        // 使用智能上传逻辑处理邮箱更新 - 🔧 统一使用 objectId 作为 userId
        LeanCloudService.shared.uploadUserEmailIfNotExists(objectId: userId, loginType: loginTypeString, userEmail: newEmail) { success, message in
            DispatchQueue.main.async {
                if success {
                } else {
                }
            }
        }
    }

    func logout() {
        let logoutTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let _ = formatter.string(from: logoutTime)

        // 🎯 符合内建账户开发指南：调用 LCUser.logOut() 清除 session token
        // 0. 调用 LeanCloud 的 logOut() 方法清除 session token
        if let currentLCUser = LCApplication.default.currentUser {
            // 清除内部账户保存的 session token
            if let userId = currentLCUser.objectId?.value {
                UserDefaults.standard.removeObject(forKey: "internal_session_token_\(userId)")
            }
            // 调用 LCUser.logOut() 清除 LeanCloud 的 session token
            LCUser.logOut()
        }

        // 1. 断开 IM 触发器
        disconnectIMTrigger()

        // 2. 清除对话缓存
        PatConversationManager.shared.clearConversations()

        // 3. 清除钻石管理器的用户信息
        diamondManager?.clearUser()

        // 4. 清除 Badge（应用角标）
        // 🎯 修复：发送通知清除 newFriendsCountManager.count，让它自动同步清除 badge
        NotificationCenter.default.post(name: NSNotification.Name("ClearAllNotifications"), object: nil)

        // 本地清空角标（双重保险）
        // iOS 17+ 使用 UNUserNotificationCenter 设置角标
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        // currentInstallation 的角标清零
        let installation = LCApplication.default.currentInstallation
        installation.badge = 0
        installation.save { result in
            switch result {
            case .success:
                break
            case .failure:
                break
            }
        }

        // 5. 退订所有频道并清除 Installation 的 owner 属性
        if let user = currentUser {
            // 退订用户ID对应的频道
            do {
                try installation.remove("channels", element: user.userId)
            } catch {
            }

            // 如果还有其他频道，也尝试退订（获取所有频道并逐个退订）
            if let channels = installation.channels?.value as? [String] {
                for channel in channels {
                    do {
                        try installation.remove("channels", element: channel)
                    } catch {
                    }
                }
            } else if let channelsLCArray = installation.channels?.value as? LCArray,
                      let arrayValue = channelsLCArray.arrayValue {
                for element in arrayValue {
                    if let channelString = element as? LCString,
                       let channelValue = channelString.stringValue {
                        do {
                            try installation.remove("channels", element: channelValue)
                        } catch {
                        }
                    }
                }
            }

            // 清除 Installation 的 owner 属性
            do {
                try installation.set("owner", value: NSNull())
            } catch {
            }
        }

        // 保存 Installation 的更改
        installation.save { result in
            switch result {
            case .success:
                break
            case .failure:
                break
            }
        }

        // 6. 清除本地存储的登录状态
        UserDefaultsManager.setLoggedIn(false)
        UserDefaultsManager.setCurrentUserId("")
        UserDefaultsManager.setCurrentUserName("")
        UserDefaultsManager.setCurrentUserEmail("")
        UserDefaultsManager.setLoginType("")

        // 7. 清除用户状态
        self.currentUser = nil
        self.isLoggedIn = false
        
        // 🎯 新增：清除上次登录记录上传时间，确保重新登录时能正常上传
        self.lastLoginRecordUploadTime = nil
    }

    // 新增：测试Apple ID信息获取的方法
    func testAppleIDInfoRetrieval() {
        // 检查当前用户状态
        if currentUser != nil {
            // 用户已登录
        } else {
            // 用户未登录
        }

        // 检查本地存储
        let userDefaults = UserDefaults.standard
        let currentUserId = userDefaults.string(forKey: "current_user_id")

        if let userId = currentUserId {
            _ = userDefaults.string(forKey: "apple_user_name_\(userId)")
            _ = userDefaults.string(forKey: "apple_user_email_\(userId)")
            // 存储信息已获取
        }

        // 尝试刷新Apple ID信息
        if currentUser?.loginType == .apple {
            forceRefreshAppleIDInfo()
        } else {
            // 非Apple ID用户
        }
    }

    // 新增：清除所有本地存储的Apple ID信息
    func clearAppleIDStoredInfo() {
        let userDefaults = UserDefaults.standard
        let currentUserId = userDefaults.string(forKey: "current_user_id")
        let loginType = userDefaults.string(forKey: "loginType")

        if let userId = currentUserId {
            // 清除Apple ID相关数据
            userDefaults.removeObject(forKey: "apple_user_name_\(userId)")
            userDefaults.removeObject(forKey: "apple_user_email_\(userId)")
            userDefaults.removeObject(forKey: "apple_original_uid_\(userId)")
            
            // 🗑️ 清除用户相关的所有本地数据
            // 头像和钻石
            userDefaults.removeObject(forKey: "custom_avatar_\(userId)")
            userDefaults.removeObject(forKey: "custom_diamonds_\(userId)")
            
            // 用户名和邮箱（通用）
            userDefaults.removeObject(forKey: "current_user_name")
            userDefaults.removeObject(forKey: "current_user_email")
            
            // 游客相关数据（如果存在）
            if loginType == "guest" {
                // 清除游客映射关系
                let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                let guestID = "guest_\(deviceID)"
                userDefaults.removeObject(forKey: "guest_leancloud_id_\(guestID)")
                userDefaults.removeObject(forKey: "guest_username_\(userId)")
                userDefaults.removeObject(forKey: "guest_user_name_\(userId)")
                userDefaults.removeObject(forKey: "guest_user_email_\(userId)")
            }
            
            // 清除所有用户相关的记录键（使用当前用户信息）
            if let user = self.currentUser {
                userDefaults.removeObject(forKey: StorageKeyUtils.getHistoryKey(for: user))
                userDefaults.removeObject(forKey: StorageKeyUtils.getFavoriteRecordsKey(for: user))
                userDefaults.removeObject(forKey: StorageKeyUtils.getReportRecordsKey(for: user))
            } else {
                // 如果没有currentUser，尝试根据loginType推断键名
                if loginType == "guest" {
                    let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                    let shortDeviceID = String(deviceID.prefix(8))
                    userDefaults.removeObject(forKey: "randomMatchHistory_guest_\(shortDeviceID)")
                    userDefaults.removeObject(forKey: "favorite_records_\(userId)")
                    userDefaults.removeObject(forKey: "report_records_guest_\(shortDeviceID)")
                } else if loginType == "apple" {
                    let email = userDefaults.string(forKey: "current_user_email") ?? "unknown"
                    userDefaults.removeObject(forKey: "randomMatchHistory_apple_\(email)")
                    userDefaults.removeObject(forKey: "favorite_records_apple_\(userId)")
                    userDefaults.removeObject(forKey: "report_records_apple_\(email)")
                }
            }
            
            // 清除其他可能的键
            userDefaults.removeObject(forKey: "likeRecords_\(userId)")
            userDefaults.removeObject(forKey: "messages_\(userId)")
            userDefaults.removeObject(forKey: "location_history_\(userId)")
            userDefaults.removeObject(forKey: "randomMatchHistory_\(loginType ?? "guest")_\(userId)")
            userDefaults.removeObject(forKey: "favorite_records_\(userId)")
            userDefaults.removeObject(forKey: "report_records_\(userId)")
            userDefaults.removeObject(forKey: "first_login_time_\(userId)")
            userDefaults.removeObject(forKey: "max_combo_count_\(userId)")
            userDefaults.removeObject(forKey: "internal_session_token_\(userId)")
            userDefaults.removeObject(forKey: "internal_user_email_\(userId)")
        }

        // 清除登录状态
        userDefaults.removeObject(forKey: "is_logged_in")
        userDefaults.removeObject(forKey: "loginType")
        userDefaults.removeObject(forKey: "current_user_id")
        
        // 清除全局数据（如果适用）
        userDefaults.removeObject(forKey: "locationHistory")
        userDefaults.removeObject(forKey: "blacklistedUserIds")
        
        NSLog("🗑️ [UserManager] 本地数据已清除")
    }
}
