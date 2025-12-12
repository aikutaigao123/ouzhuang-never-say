import SwiftUI

extension MessageView {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Group { EmptyView() }
                    .onAppear {
                    }
                    .onChange(of: existingFriends.count) { _, _ in
                    }
                    .onChange(of: showFriendsList) { _, _ in
                    }
                    .onChange(of: isNewFriendsVisible) { _, _ in
                    }
                    .onChange(of: existingMessages.count) { _, _ in
                    }
                    .onChange(of: existingPatMessages.count) { _, _ in
                    }
                // 消息内容区域
                NavigationStack {
                    Group { EmptyView() }
                        .onAppear {
                        }
                    Group { EmptyView() }
                        .onAppear {
                        }
                    messagesTabView
                        .onAppear {
                        }
                        .navigationTitle("消息")
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu {
                                    Button(action: {
                                        // 🎯 修改：无论是否有新的朋友未读消息，都执行一键已读（包括拍一拍消息）
                                        markAllAsRead()
                                    }) {
                                        Label("一键已读", systemImage: "checkmark.circle")
                                            .foregroundColor(newFriendsCountManager.count == 0 ? .secondary : .primary)
                                    }
                                    
                                    Button(action: {
                                        // 处理添加朋友按钮点击
                                        handleAddFriendButtonTap()
                                    }) {
                                        Label("添加朋友", systemImage: "person.badge.plus")
                                    }
                                    
                                    Button(action: {
                                        // 处理新的朋友按钮点击
                                        handleNewFriendsButtonTap()
                                    }) {
                                        Label("新的朋友\(newFriendsCountManager.count > 0 ? " (\(newFriendsCountManager.count))" : "")", systemImage: "person.2.badge.plus")
                                    }
                                    
                                    
                                } label: {
                                    HStack(spacing: 8) {
                                        // 位置图标带数字徽章
                                        ZStack(alignment: .topTrailing) {
                                            Image("位置图标")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 24, height: 24)
                                            
                                            // 新朋友数量徽章 - 现在在位置图标的右上角
                                            let badgeCount = newFriendsCountManager.count
                                            if badgeCount > 0 {
                                                Text("\(badgeCount)")
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 2)
                                                    .background(Color.red)
                                                    .clipShape(Circle())
                                                    .offset(x: 6, y: -6)
                                                    .zIndex(1)
                                            }
                                        }
                                        
                                        Text("Never say No")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: geometry.size.height)
            }
        }
        .onAppear {
            // 🔍 新增：打印所有拍一拍消息的详细信息
            if !existingPatMessages.isEmpty {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                for (_, patMessage) in existingPatMessages.enumerated() {
                    let _ = formatter.string(from: patMessage.timestamp)
                }
            } else {
            }
            
            // 🎯 新增：点击次数追踪（使用静态变量避免重置）
            MessageView.globalClickCount += 1
            messageButtonClickCount = MessageView.globalClickCount
            
            // 🚀 移除自动匹配调用，避免无限循环导致闪退
            
            // 🔍 调试信息：MessageView界面打开时的状态
            if userManager.currentUser != nil {
            } else {
            }
            
            // 🔍 调试信息：传入的数据状态
            
            // 🔍 新增调试：详细检查好友数据状态
            if !existingFriends.isEmpty {
            } else {
            }
            
            // 🔧 新增：检查数据传递状态
            
            // 🔧 新增：检查数据传递状态 - 详细分析
            
            // 🔧 新增：检查数据传递状态 - 超详细分析
            
            // 🔧 新增：详细检查existingFriends内容
            if !existingFriends.isEmpty {
                for (_, _) in existingFriends.enumerated() {
                }
            } else {
            }
            
            // 🔧 新增：检查favoriteRecords内容
            if !favoriteRecords.isEmpty {
                for (_, _) in favoriteRecords.enumerated() {
                }
            } else {
            }
            
            // 每次进入时重置消息列表为折叠状态
            isMessagesExpanded = false
            
            // 🔧 新增：监听自动显示新的朋友列表的通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AutoShowNewFriends"),
                object: nil,
                queue: .main
            ) { _ in
                // 自动显示新的朋友列表
                withAnimation(.easeInOut(duration: 0.3)) {
                    isNewFriendsVisible = true
                }
                // 🔧 新增：自动展开新的朋友列表
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isMessagesExpanded = true
                    }
                }
            }
            
            // 新朋友列表默认隐藏，只有点击"新的朋友"按钮时才显示
            isNewFriendsVisible = false
            
            // 🔍 调试信息：好友列表显示状态
            
            // 打印好友列表详情
            if existingFriends.isEmpty {
            } else {
                for (_, friend) in existingFriends.enumerated() {
                    let _ = userManager.currentUser?.id ?? "未知"
                    let _ = friend.user1Id == (userManager.currentUser?.id ?? "未知") ? friend.user2Id : friend.user1Id
                    let _ = friend.user1Id == (userManager.currentUser?.id ?? "未知") ? friend.user2Name : friend.user1Name
                    let _ = friend.user1Id == (userManager.currentUser?.id ?? "未知") ? friend.user2LoginType : friend.user1LoginType
                    let _ = friend.matchTime
                    
                }
            }
            
            // 移除持久化缓存恢复，与历史记录按钮保持一致
            
            // 移除缓存数据显示，与历史记录按钮保持一致
            
            // 🚀 修改：实时更新机制，与拍一拍消息一致
            // 优先从全局缓存恢复头像和用户名数据，确保MessageView打开时立即显示缓存内容
            restoreCacheFromGlobal()
            
            // 立即实时更新所有用户头像，与拍一拍消息一致
            refreshAllUserAvatarsInRealTime()
            
            // 新增：启动定期缓存刷新定时器（每2分钟检查一次，提高频率）
            startCacheRefreshTimer()
            
            // 移除后台缓存更新，与历史记录按钮保持一致
            
            // 移除预加载消息相关用户的缓存数据，与历史记录按钮保持一致
            
            // 移除监听用户操作，与历史记录按钮保持一致
            
            // 移除监听好友列表刷新通知，与历史记录按钮保持一致
            
            // 移除监听一致性检查通知，与历史记录按钮保持一致
        
            // 移除监听新的朋友刷新通知，与历史记录按钮保持一致
            
            // 🎯 新增：监听新好友申请通知，立即刷新列表
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshNewFriends"),
                object: nil,
                queue: .main
            ) { _ in
                self.refreshNewFriendsList()
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NewFriendshipRequest"),
                object: nil,
                queue: .main
            ) { _ in
                self.refreshNewFriendsList()
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FriendshipRequestUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                self.refreshNewFriendsList()
            }
            
            // 移除监听应用恢复前台通知，与历史记录按钮保持一致
            
            // 移除后台缓存更新定时器，与历史记录按钮保持一致
            
            // 设置 IM 触发器监听
            setupIMListener()
            
        // 监听好友列表刷新通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshFriendsList"),
            object: nil,
            queue: .main
        ) { _ in
            // 当收到好友列表刷新通知时，重新加载好友列表
            self.loadFriendsSilently()
        }
        
        // 🎯 新增：监听拍一拍消息添加通知，立即更新 existingPatMessages
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PatMessageAdded"),
            object: nil,
            queue: .main
        ) { notification in
            // 当收到拍一拍消息添加通知时，立即刷新消息列表
            if let message = notification.userInfo?["message"] as? MessageItem {
                // 检查是否已存在
                let messageId = message.objectId ?? message.id.uuidString
                let exists = self.existingPatMessages.contains { existing in
                    let existingId = existing.objectId ?? existing.id.uuidString
                    return existingId == messageId
                }
                
                if !exists {
                    // 添加到列表开头
                    var updatedMessages = self.existingPatMessages
                    updatedMessages.insert(message, at: 0)
                    
                    // 按时间排序
                    updatedMessages.sort { $0.timestamp > $1.timestamp }
                    
                    // 更新 existingPatMessages，触发UI刷新
                    self.existingPatMessages = updatedMessages
                    
                    // 保存到本地
                    if let currentUser = self.userManager.currentUser {
                        UserDefaultsManager.savePatMessages(updatedMessages, userId: currentUser.id)
                    }
                }
            }
            
            // 同时触发消息刷新，确保从服务器获取最新数据
            self.loadMessagesSilently()
        }
            
            // 🔧 修复：每次点击都重新排序，确保排序一致性
            if !existingMessages.isEmpty || !existingPatMessages.isEmpty || !existingFriends.isEmpty {
                // 有现有数据，但仍然需要重新排序以确保一致性
                if !existingFriends.isEmpty {
                    // 重新排序现有好友列表
                    processLoadedFriends(existingFriends)
                } else {
                    // 没有好友数据，重新加载
                    loadFriends()
                }
                
                // 🎯 新增：重新进入时刷新新朋友列表，确保应用"一键已读"状态
                refreshNewFriendsList()
            } else {
                // 没有现有数据，先从本地加载拍一拍消息
                if let currentUser = userManager.currentUser {
                    let localPatMessages = UserDefaultsManager.getPatMessages(userId: currentUser.id)
                    if !localPatMessages.isEmpty {
                        existingPatMessages = localPatMessages
                    }
                }
                
                // 显示加载状态
                loadMessages()
                loadFriends()
                
                // 🎯 新增：首次加载时也刷新新朋友列表
                refreshNewFriendsList()
            }
        }
        .onChange(of: existingFriends.count) { oldCount, newCount in
            // 🔧 修复：当好友数据更新时自动刷新界面
            if newCount > oldCount {
            } else if newCount < oldCount {
            } else {
            }
            
            // 🚀 修改：不自动显示新的朋友列表，保持隐藏状态
            if oldCount == 0 && newCount > 0 {
            }
        }
        .onDisappear {
            // 🔍 新增：打印MessageView消失的信息
            let _ = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            
            // 界面关闭
            
            // 停止缓存刷新定时器
            stopCacheRefreshTimer()
            
            // 取消 IM 触发器监听
            cancellables.removeAll()
            
            // 移除好友列表刷新通知监听
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshFriendsList"), object: nil)
            
            // 移除停止消息刷新定时器，与历史记录按钮保持一致
            
            // 移除后台缓存更新定时器，与历史记录按钮保持一致
            
            // 移除监听器，与历史记录按钮保持一致
        }
        .sheet(isPresented: $showingAddFriendSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    // 🎯 与赠与按钮一致：实时搜索，至少2个字符
                    HStack {
                        TextField("输入用户名或邮箱", text: Binding(
                            get: { addFriendSearchText },
                            set: { newValue in
                                let limitedValue = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                                addFriendSearchText = limitedValue
                                performFriendSearch(query: limitedValue)
                            }
                        ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if isSearchingFriend {
                            ProgressView()
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.top, 16)
                    
                    // 搜索结果列表 - 与赠与按钮一致：使用 UserResultRow 组件
                    if !addFriendSearchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(addFriendSearchResults, id: \.id) { user in
                                    UserResultRow(user: user) {
                                        handleFriendSelection(user: user)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .padding(.top, 8)
                    } else if !addFriendSearchText.isEmpty && addFriendSearchText.count >= 2 && !isSearchingFriend {
                        Spacer()
                        Text("未找到匹配的用户")
                            .foregroundColor(.secondary)
                        Spacer()
                    } else {
                        Spacer()
                        Text("输入用户名或邮箱进行搜索（至少2个字符）")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .navigationTitle("搜索添加朋友")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") {
                            showingAddFriendSheet = false
                            addFriendSearchText = ""
                            addFriendSearchResults = []
                            addFriendErrorMessage = nil
                        }
                    }
                }
            }
        }
    }
}



