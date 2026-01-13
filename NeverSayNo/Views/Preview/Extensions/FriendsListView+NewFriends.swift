//
//  FriendsListView+NewFriends.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import SwiftUI

// MARK: - New Friends Extensions
extension FriendsListView {
    
    // MARK: - New Friends Methods
    
    /// 新的朋友部分头部
    @ViewBuilder
    var newFriendsSectionHeader: some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                Text("好友申请")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // 未读消息数量徽章（与消息/好友按钮样式一致）
                // 🎯 修改：使用计算属性，根据展开状态和已读时间戳判断是否显示数字
                let unreadCount = calculateUnreadNewFriendsCount()
                
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 12, y: -8)
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    let wasExpanded = isNewFriendsExpanded
                    isNewFriendsExpanded.toggle()
                    
                    
                    // 🎯 新增：展开时标记所有新朋友消息为已读，数字清0
                    if !wasExpanded && isNewFriendsExpanded {
                        markNewFriendsAsRead()
                    } else {
                    }
                }
            }) {
                Image(systemName: isNewFriendsExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isNewFriendsExpanded ? 0 : 0))
                    .animation(.easeInOut(duration: 0.3), value: isNewFriendsExpanded)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                let wasExpanded = isNewFriendsExpanded
                isNewFriendsExpanded.toggle()
                
                
                // 🎯 新增：展开时标记所有新朋友消息为已读，数字清0
                if !wasExpanded && isNewFriendsExpanded {
                    markNewFriendsAsRead()
                } else {
                }
            }
        }
        .onChange(of: isNewFriendsExpanded) { oldValue, newValue in
            // 🎯 新增：监听展开状态变化，展开时标记为已读
            if !oldValue && newValue {
                markNewFriendsAsRead()
            } else {
            }
        }
    }
    
    /// 计算未读的新朋友数量（根据已读时间戳）
    func calculateUnreadNewFriendsCount() -> Int {
        guard let currentUser = userManager.currentUser else {
            return newFriends.count
        }
        
        let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
        let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
        
        // 如果没有已读时间戳，所有消息都视为未读
        guard let markAllTime = markAllAsReadTimestamp else {
            return newFriends.count
        }
        
        // 统计未读消息数量（创建时间晚于已读时间戳的消息）
        let unreadCount = newFriends.filter { message in
            let timeDifference = message.timestamp.timeIntervalSince(markAllTime)
            let isUnread = timeDifference > 1.0 // 允许1秒容差
            if isUnread {
            }
            return isUnread
        }.count
        
        return unreadCount
    }
    
    /// 标记所有新朋友消息为已读（与我的好友列表一致）
    func markNewFriendsAsRead() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 打印所有新朋友消息的时间戳
        for (_, _) in newFriends.enumerated() {
        }
        
        // 更新"一键已读"的时间戳，用于后续刷新时判断已读状态
        let markAllAsReadTimestamp = Date()
        let key = "MarkAllAsReadTimestamp_\(currentUser.id)"
        UserDefaults.standard.set(markAllAsReadTimestamp, forKey: key)
        
        // 验证时间戳是否保存成功
        if UserDefaults.standard.object(forKey: key) as? Date != nil {
        } else {
        }
        
        // 发送通知，更新新朋友计数管理器
        NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
        
        // 重新计算未读数量
        let _ = calculateUnreadNewFriendsCount()
    }
    
    /// 删除好友申请消息
    func deleteFriendRequestMessage(senderId: String) {
        guard let currentUser = userManager.currentUser else {
            // 当前用户为空
            return
        }
        
        // 开始删除好友申请消息
        
        // 从LeanCloud删除消息
        LeanCloudService.shared.deleteMessage(senderId: senderId, receiverId: currentUser.id) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 消息删除成功
                    // 从本地列表中移除该消息
                    self.newFriends.removeAll { $0.senderId == senderId }
                } else {
                }
            }
        }
    }
}

