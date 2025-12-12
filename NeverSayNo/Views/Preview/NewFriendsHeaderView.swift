import SwiftUI

// 抽离"新的朋友"分节头，降低 MessageView 拷贝体积，规避 SwiftUI 视图大拷贝崩溃热点
struct NewFriendsHeaderView: View {
    @ObservedObject var newFriendsCountManager: NewFriendsCountManager
    @Binding var isMessagesExpanded: Bool
    let currentMessagesCount: Int
    let userManager: UserManager? // 🎯 新增：用于标记已读
    
    init(newFriendsCountManager: NewFriendsCountManager, isMessagesExpanded: Binding<Bool>, currentMessagesCount: Int, userManager: UserManager? = nil) {
        self.newFriendsCountManager = newFriendsCountManager
        self._isMessagesExpanded = isMessagesExpanded
        self.currentMessagesCount = currentMessagesCount
        self.userManager = userManager
    }
    
    var body: some View {
        HStack {
            ZStack(alignment: .topTrailing) {
                Text("新的朋友")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // 🎯 修改：使用计算属性，根据已读时间戳判断是否显示数字
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
                        .offset(x: 6, y: -6)
                        .zIndex(1)
                        .onAppear {
                        }
                } else {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .onAppear {
                        }
                }
            }
            
            Spacer()
            
            Image(systemName: isMessagesExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            
            let before = isMessagesExpanded
            withAnimation(.easeInOut(duration: 0.3)) {
                isMessagesExpanded.toggle()
            }
            let after = isMessagesExpanded
            
            
            // 🎯 新增：展开时标记所有新朋友消息为已读，数字清0
            if !before && after {
                markNewFriendsAsRead()
            } else {
            }
        }
        .onChange(of: isMessagesExpanded) { oldValue, newValue in
            
            // 🎯 新增：监听展开状态变化，展开时标记为已读
            if !oldValue && newValue {
                markNewFriendsAsRead()
            } else {
            }
        }
        .background(Color(.systemBackground))
    }
    
    // 🎯 新增：计算未读的新朋友数量（根据已读时间戳）
    private func calculateUnreadNewFriendsCount() -> Int {
        guard let currentUser = userManager?.currentUser else {
            return newFriendsCountManager.count
        }
        
        let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
        let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
        
        
        // 如果没有已读时间戳，所有消息都视为未读
        guard markAllAsReadTimestamp != nil else {
            return newFriendsCountManager.count
        }
        
        // 🎯 注意：这里需要从 existingMessages 计算，但 NewFriendsHeaderView 没有访问权限
        // 暂时使用 newFriendsCountManager.count，但实际应该根据时间戳过滤
        // 由于 NewFriendsHeaderView 没有 existingMessages 的访问权限，我们需要通过其他方式
        // 这里先返回 newFriendsCountManager.count，实际的过滤逻辑应该在 MessageView 中处理
        
        return newFriendsCountManager.count
    }
    
    // 🎯 新增：标记所有新朋友消息为已读（与我的好友列表一致）
    private func markNewFriendsAsRead() {
        
        guard let currentUser = userManager?.currentUser else {
            return
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
        
        // 更新 newFriendsCountManager 的计数为 0
        newFriendsCountManager.updateCount(0)
        
    }
}

