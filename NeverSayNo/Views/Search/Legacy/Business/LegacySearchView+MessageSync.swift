//
//  LegacySearchView+MessageSync.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import LeanCloud

extension LegacySearchView {
    // MARK: - Message Sync Methods
    
    
    /// 验证拍一拍消息同步结果
    func verifyPatMessageSync(friendId: String, beforeSyncCount: Int, beforeFriendCount: Int) {
        
        // 获取当前数据状态
        let currentPatCount = messageViewPatMessages.count
        let currentFriendPatCount = messageViewPatMessages.filter { message in
            let isFriendPatMe = message.senderId == friendId && message.receiverId == userManager.currentUser?.id
            let isIPatFriend = message.senderId == userManager.currentUser?.id && message.receiverId == friendId
            return isFriendPatMe || isIPatFriend
        }.count
        
        
        // 验证同步结果
        let totalMessagesIncreased = currentPatCount > beforeSyncCount
        let friendMessagesMaintained = currentFriendPatCount >= beforeFriendCount
        let dataActuallyChanged = currentPatCount != beforeSyncCount
        
        
        if totalMessagesIncreased && friendMessagesMaintained {
        } else if !dataActuallyChanged {
        } else {
            
            if !totalMessagesIncreased {
            }
            if !friendMessagesMaintained {
            }
        }
        
    }
    
    /// 获取并打印消息
    func fetchAndPrintMessages() {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        LeanCloudService.shared.fetchMessages(userId: currentUser.id) { messages, error in
            DispatchQueue.main.async {
                
                if error != nil {
                } else if messages != nil {
                    // 消息获取成功，继续处理
                }
                
                // 显示消息界面
                showMessageSheet = true
            }
        }
        
    }
    
    /// 处理消息按钮点击
    func handleMessageButtonTap() {
        // 🎯 新增：检查消息按钮点击次数限制
        guard let currentUser = userManager.currentUser else {
            return
        }
        let userId = currentUser.id
        let (canClick, message) = UserDefaultsManager.canClickMessageButton(userId: userId)
        if !canClick {
            // 超过限制，显示提示
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MessageButtonLimitExceeded"),
                    object: nil,
                    userInfo: ["message": message, "showAlert": true]
                )
            }
            return
        }
        
        // 🎯 新增：每次点击消息按钮时检查邮箱格式
        let loginType = currentUser.loginType
        // 游客账号不检查邮箱格式
        if loginType != .guest {
            // 从 UserNameRecord 表查询邮箱
            LeanCloudService.shared.fetchUserEmailByUserId(objectId: userId) { email, error in
                DispatchQueue.main.async {
                    if error == nil, let currentEmail = email, !currentEmail.isEmpty {
                        // 检查是否是默认邮箱格式
                        let isDefaultEmail = currentEmail.hasSuffix("@internal.com") || 
                                           currentEmail.hasSuffix("@apple.com") || 
                                           currentEmail.hasSuffix("@guest.com")
                        
                        if isDefaultEmail {
                            // 是默认邮箱格式，显示提示
                            NotificationCenter.default.post(name: NSNotification.Name("ShowDefaultEmailAlert"), object: nil)
                            return // 不继续执行，先显示提示
                        }
                    }
                    
                    // 不是默认邮箱或查询失败，继续执行（显示消息界面）
                    self.continueMessageButtonTap(userId: userId)
                }
            }
        } else {
            // 游客账号，直接继续执行
            continueMessageButtonTap(userId: userId)
        }
    }
    
    /// 继续执行消息按钮点击（显示消息界面）
    private func continueMessageButtonTap(userId: String) {
        // 记录点击
        UserDefaultsManager.recordMessageButtonClick(userId: userId)
        
        // 显示消息界面
        showMessageSheet = true
    }
    
    /// 打印Message表数据
    func printMessageTable() {
        
        // 打印本地消息数据
        
        if messageViewMessages.isEmpty {
        } else {
            for (_, _) in messageViewMessages.enumerated() {
            }
        }
        
        // 从LeanCloud获取Message表数据
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        LeanCloudService.shared.fetchMessages(userId: currentUser.id) { messages, error in
            DispatchQueue.main.async {
                if error != nil {
                } else if let messages = messages {
                    
                    if messages.isEmpty {
                    } else {
                        for (_, _) in messages.enumerated() {
                        }
                    }
                } else {
                }
                
            }
        }
    }
    
    /// 删除好友申请相关的消息（双向删除）
    func deleteFriendRequestMessages(user1Id: String, user2Id: String, completion: @escaping () -> Void) {
        
        let group = DispatchGroup()
        
        // 删除 user1 -> user2 的所有相关消息
        group.enter()
        LeanCloudService.shared.deleteAllMessagesBetweenUsers(senderId: user1Id, receiverId: user2Id) { success, error in
            if success {
            } else {
            }
            group.leave()
        }
        
        // 删除 user2 -> user1 的所有相关消息
        group.enter()
        LeanCloudService.shared.deleteAllMessagesBetweenUsers(senderId: user2Id, receiverId: user1Id) { success, error in
            if success {
            } else {
            }
            group.leave()
        }
        
        // 等待所有删除操作完成
        group.notify(queue: .main) {
            completion()
        }
    }
    
    /// 更新消息界面数据 - 优化版本，后台处理数据
    func updateMessageViewData() {
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        // 在后台线程获取和处理消息数据，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            // 获取消息数据
            LeanCloudService.shared.fetchMessages(userId: currentUser.id) { messages, error in
                DispatchQueue.global(qos: .userInitiated).async {
                    if let messages = messages {
                        // 在后台线程处理数据过滤和去重
                        // 🎯 方案1：完全使用 _FriendshipRequest 表管理好友申请
                        // 不再从 Message 表过滤好友申请消息，好友申请由 FriendshipManager 管理
                        // 只处理拍一拍消息
                        let patMessages = MessageUtils.filterPatMessagesByUserId(messages, currentUserId: currentUser.id)
                        
                        // 处理拍一拍消息
                        let processedPatMessages = MessageUtils.processPatMessages(patMessages)
                        
                        // 🎯 好友申请消息由 FriendshipManager 管理，不在这里处理
                        // messageViewMessages 应该由 FriendshipManager 的数据填充
                        // 这里只更新拍一拍消息
                        
                        // 回到主线程更新UI
                        DispatchQueue.main.async {
                            // 🚀 新增：详细的消息同步调试信息
                            
                            // 更新消息界面数据（只更新拍一拍消息）
                            // messageViewMessages 由 FriendshipManager 管理，不在这里更新
                            self.messageViewPatMessages = processedPatMessages
                            
                            // 缓存拍一拍消息数据
                            self.cachePatMessages(processedPatMessages)
                            
                            // 🎯 好友申请消息由 FriendshipManager 管理，不在这里缓存
                            
                            
                            // 数据更新完成后，检查MessageView的状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                // 🚀 新增：设置消息数据后，检测匹配状态
                                self.detectAndUpdateMatchStatus()
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.messageViewMessages = []
                            self.messageViewPatMessages = []
                            
                            // 🚀 新增：设置消息数据后，检测匹配状态
                            self.detectAndUpdateMatchStatus()
                        }
                    }
                }
            }
        }
        
        // ⚠️ 已废弃：不再从 MatchRecord 表获取好友数据
        // 好友列表现在由 FriendshipManager 从 _Followee 表获取
        
        // 清空缓存数据，让 MessageView 重新加载
        self.messageViewAvatarCache = [:]
        self.messageViewUserNameCache = [:]
    }
}



