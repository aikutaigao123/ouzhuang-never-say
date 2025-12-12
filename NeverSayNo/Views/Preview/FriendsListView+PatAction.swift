import SwiftUI

extension FriendsListView {
    /// 处理拍一拍好友
    func handlePatFriend(_ friend: MatchRecord) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 🎯 检查24小时内拍一拍数量限制（在点击时检查，不依赖API结果）
        let (canSend, limitErrorMessage) = UserDefaultsManager.canSendPatAction()
        if !canSend {
            // 超过限制，显示弹窗提示
            self.patFeedbackMessage = limitErrorMessage
            self.patFeedbackType = .failure
            self.showPatFeedback = true
            
            // 3秒后自动隐藏反馈
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.showPatFeedback = false
            }
            return
        }
        
        // 获取好友信息 - 先尝试用 id 比较，如果失败再用 userId 比较
        var friendId: String
        var friendName: String
        
        if friend.user1Id == currentUser.id {
            friendId = friend.user2Id
            friendName = friend.user2Name
        } else if friend.user1Id == currentUser.userId {
            friendId = friend.user2Id
            friendName = friend.user2Name
        } else if friend.user2Id == currentUser.id {
            friendId = friend.user1Id
            friendName = friend.user1Name
        } else if friend.user2Id == currentUser.userId {
            friendId = friend.user1Id
            friendName = friend.user1Name
        } else {
            // 如果都不匹配，使用原来的逻辑
            friendId = friend.user1Id == currentUser.id ? friend.user2Id : friend.user1Id
            friendName = friend.user1Id == currentUser.id ? friend.user2Name : friend.user1Name
        }
        
        
        // 🔧 修复：使用 objectId
        let fromUserId = currentUser.id
        let toUserId = friendId // friendId 应该是 objectId
        
        // 🎯 新增：拍一拍按钮点击时，更新 LoginRecord 表
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        let loginType: String
        switch currentUser.loginType {
        case .apple:
            loginType = "apple"
        case .guest:
            loginType = "guest"
        }
        let userEmail = currentUser.email
        
        
        if loginType == "apple" {
            // Apple 登录需要 authData，这里使用简化版本
            let authData: [String: Any] = [
                "lc_apple": [
                    "uid": fromUserId
                ]
            ]
            LeanCloudService.shared.recordAppleLoginWithAuthData(
                userId: fromUserId,
                userName: currentUser.fullName,
                userEmail: userEmail,
                authData: authData,
                deviceId: deviceID
            ) { loginRecordSuccess in
                if loginRecordSuccess {
                } else {
                }
            }
        } else {
            LeanCloudService.shared.recordLogin(
                userId: fromUserId,
                userName: currentUser.fullName,
                userEmail: userEmail,
                loginType: loginType,
                deviceId: deviceID
            ) { loginRecordSuccess in
                if loginRecordSuccess {
                } else {
                }
            }
        }
        
        // 🎯 立即记录发送时间（在点击时记录，不依赖API结果）
        let _ = UserDefaultsManager.getPatActionCountInLast24Hours()
        UserDefaultsManager.recordPatActionSent(to: toUserId)
        
        // 使用新的拍一拍消息服务（与测试按钮一致）
        PatMessageService.shared.sendPatMessage(
            fromUserId: fromUserId,
            toUserId: toUserId, // 🔧 修复：使用 objectId
            fromUserName: currentUser.fullName,
            toUserName: friendName
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 拍一拍发送成功
                    self.patFeedbackMessage = "已向 \(friendName) 发送拍一拍"
                    self.patFeedbackType = .success
                    self.showPatFeedback = true
                    
                    // 拍一拍成功后，重新加载好友列表以更新排序
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                        self.loadFriends(showLoading: false)
                    }
                    
                    // 3秒后自动隐藏反馈
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.showPatFeedback = false
                    }
                } else {
                    // 拍一拍发送失败
                    self.patFeedbackMessage = "拍一拍发送失败，请重试"
                    self.patFeedbackType = .failure
                    self.showPatFeedback = true
                    
                    // 3秒后自动隐藏反馈
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.showPatFeedback = false
                    }
                }
            }
        }
    }
}

