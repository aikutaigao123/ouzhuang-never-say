import SwiftUI
import LeanCloud

// 用户操作相关部分
extension ProfileView {
    // 编辑用户名功能
    func editUserName() {
        let loginType = userManager.currentUser?.loginType
        if loginType == .guest {
            // 游客用户显示提示
            showGuestNameAlert = true
        } else {
            // Apple ID 用户显示编辑框
            // 🎯 修改：使用与个人信息界面显示相同的逻辑 - 优先使用 userNameFromServer，否则使用 userManager.currentUser?.fullName
            let displayedName: String = {
                if let serverName = userNameFromServer, !serverName.isEmpty {
                    return serverName
                } else {
                    return userManager.currentUser?.fullName ?? ""
                }
            }()
            newUserName = displayedName
            showEditNameAlert = true
        }
    }
    
    // 编辑邮箱功能
    func editEmail() {
        // 显示修改邮箱弹窗
        newEmail = emailFromServer ?? ""
        showEditEmailInputAlert = true
    }
    
    // 保存邮箱地址
    func saveEmail() {
        // 去除首尾空格
        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 验证邮箱格式（如果邮箱不为空）
        if !trimmedEmail.isEmpty && !isValidEmail(trimmedEmail) {
            emailEditMessage = "请输入有效的邮箱地址"
            showEmailEditAlert = true
            return
        }
        
        // 使用去除空格后的邮箱
        let finalEmail = trimmedEmail
        
        // 清除旧的邮箱缓存
        if let user = userManager.currentUser {
            if user.loginType == .apple {
                UserDefaultsManager.removeAppleUserEmail(userId: user.id)
            } else if user.loginType == .guest {
                UserDefaultsManager.removeGuestUserEmail(userId: user.id)
            }
        }
        
        // 🎯 新增：验证并更新邮箱
        userManager.updateUserEmail(finalEmail) { success, error in
            if success {
                // 🔧 立即更新 emailFromServer，使界面立即刷新
                // 如果邮箱为空，设置为 nil；否则设置为新邮箱
                emailFromServer = finalEmail.isEmpty ? nil : finalEmail
                
                // 清除邮箱缓存，确保下次查询时获取最新数据
                if let userId = userManager.currentUser?.id {
                    LeanCloudService.shared.clearCacheForUser(userId)
                }
                
                // 显示成功消息
                if finalEmail.isEmpty {
                    emailEditMessage = "邮箱地址已清除"
                } else {
                    emailEditMessage = "邮箱地址已更新为：\(finalEmail)"
                }
                showEmailEditAlert = true
            } else {
                // 显示错误信息
                if let error = error {
                    userEmailErrorMessage = error
                    showUserEmailError = true
                }
            }
        }
    }
    
    // 验证邮箱格式
    func isValidEmail(_ email: String) -> Bool {
        // 基本格式检查
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 先检查是否是邮箱格式
        if trimmedEmail.contains("@") {
            // 检查@符号是否在开头或结尾
            let parts = trimmedEmail.components(separatedBy: "@")
            guard parts.count == 2 else { return false }
            
            let localPart = parts[0]
            let domainPart = parts[1]
            
            // 检查本地部分
            guard !localPart.isEmpty && localPart.count <= 64 else { return false }
            
            // 检查域名部分
            guard !domainPart.isEmpty && domainPart.contains(".") else { return false }
            
            // 检查域名格式
            let domainParts = domainPart.components(separatedBy: ".")
            guard domainParts.count >= 2 else { return false }
            
            // 检查顶级域名长度
            guard let topLevelDomain = domainParts.last, topLevelDomain.count >= 2 else { return false }
            
            // 使用正则表达式进行最终验证
            let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
            let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
            return emailPredicate.evaluate(with: trimmedEmail)
        }
        
        let wechatIdRegex = "^[a-zA-Z][a-zA-Z0-9_-]{5,19}$"
        let wechatIdPredicate = NSPredicate(format:"SELF MATCHES %@", wechatIdRegex)
        return wechatIdPredicate.evaluate(with: trimmedEmail)
    }
    
    // 删除用户账户
    func deleteUserAccount() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 🎯 使用 userId 而不是 id，确保与上传数据时使用的字段一致
        let userId = currentUser.userId
        
        // 🗑️ 显示删除进度
        deleteProgressCurrentTable = "准备删除..."
        deleteProgressCompletedTables = 0
        deleteProgressTotalTables = 17
        deleteProgressCurrentDeletedCount = 0
        showDeleteProgress = true
        
        // 🗑️ 立即删除用户在所有表中的数据
        LeanCloudService.shared.deleteAllUserDataFromTables(
            userId: userId,
            progressCallback: { currentTable, completedTables, totalTables, deletedCount in
                // 更新进度
                DispatchQueue.main.async {
                    self.deleteProgressCurrentTable = currentTable
                    self.deleteProgressCompletedTables = completedTables
                    self.deleteProgressTotalTables = totalTables
                    self.deleteProgressCurrentDeletedCount = deletedCount
                }
            }
        ) { success, deletedCounts, errors in
            DispatchQueue.main.async {
                if success {
                    if !errors.isEmpty {
                    }
                } else {
                }
                
                // 无论删除是否成功，都清除本地数据并退出登录
                // 获取设备ID
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                
                // 发送账户删除请求到LeanCloud（记录删除请求）
                LeanCloudService.shared.requestAccountDeletion(
                    userId: userId,
                    userName: currentUser.fullName,
                    deviceId: deviceId
                ) { _ in
                    // 无论请求是否成功，都清除本地数据
                    DispatchQueue.main.async {
                        // 关闭进度显示
                        self.showDeleteProgress = false
                        
                        // 清除本地存储的用户信息
                        userManager.clearAppleIDStoredInfo()
                        // 清除历史记录
                        self.onClearAllHistory()
                        // 退出登录并关闭个人信息界面
                        userManager.logout()
                        dismiss()
                    }
                }
            }
        }
    }
    

}
