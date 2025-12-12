import SwiftUI

extension FriendRowView {
    var body: some View {
        
        return VStack(spacing: 0) {
            // 好友行
            HStack(spacing: 12) {
                // 头像（带拍一拍数字徽章）
                ZStack(alignment: .topTrailing) {
                    let avatar = displayedAvatar
                    let friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                    let isSFSymbol = UserAvatarUtils.isSFSymbol(avatar)
                    
                    if !avatar.isEmpty {
                        
                        // 检查是否是 SF Symbol
                        if isSFSymbol {
                            // SF Symbol 头像显示
                            if avatar == "applelogo" || avatar == "apple_logo" {
                                // Apple Logo 特殊处理
                                Image(systemName: "applelogo")
                                    .font(.system(size: 40))
                                    .foregroundColor(.black)
                                    .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                                    .onAppear {
                                    }
                            } else {
                                // 🔧 修复：统一处理所有 SF Symbol
                                Image(systemName: avatar)
                                    .font(.system(size: 40))
                                    .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                                    .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                                    .onAppear {
                                    }
                            }
                        } else {
                            // Emoji 或文本头像显示 - 根据emoji数量调整字体大小
                            let emojiCount = avatar.count
                            let fontSize: CGFloat = emojiCount > 1 ? 24 : 40
                            
                            Text(avatar)
                                .font(.system(size: fontSize))
                                .fixedSize(horizontal: true, vertical: false)
                                .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                                .onAppear {
                                }
                        }
                    } else {
                        // 使用默认头像（基于 loginType）- 与用户头像界面一致：Apple账号与内部账号使用相同的默认头像
                        ZStack {
                            Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50)
                            if friendInfo.loginType == "apple" {
                                // Apple账号与内部账号使用相同的默认头像
                                Image(systemName: "person.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 24))
                            } else {
                                // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                                Image(systemName: "person.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 24))
                            }
                        }
                        .onAppear {
                        }
                    }
                    
                    // 拍一拍数字徽章
                    if patCount > 0 {
                        Text("\(patCount)")
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
                                // 监听数字变化
                                checkPatCountChange()
                            }
                            .onChange(of: patCount) { _, newCount in
                                // 数字变化时打印
                                printPatCountChange(newCount: newCount)
                            }
                            .onChange(of: isPatMessagesExpanded) { _, expanded in
                                // 🎯 新增：展开时立即清0数字
                                if expanded {
                                    let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                    markPatMessagesAsRead(for: friendId)
                                }
                            }
                    } else {
                        // 即使数字为0也要监听变化
                        Color.clear
                            .frame(width: 1, height: 1)
                            .onAppear {
                                // 监听数字变化
                                checkPatCountChange()
                            }
                            .onChange(of: patCount) { _, newCount in
                                // 数字变化时打印
                                printPatCountChange(newCount: newCount)
                            }
                            .onChange(of: isPatMessagesExpanded) { _, expanded in
                                // 🎯 新增：展开时立即清0数字
                                if expanded {
                                    let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                    markPatMessagesAsRead(for: friendId)
                                }
                            }
                    }
                }
                .frame(width: 50, height: 50)
                .contentShape(Circle()) // 确保整个头像区域都可以点击
                .onTapGesture {
                    // 🎯 新增：点击头像时触发好友匹配逻辑（与历史记录按钮一致）
                    onTap()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 用户名（优先使用实时查询结果）
                    ColorfulUserNameText(
                        userName: displayedName,
                        userId: friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id,
                        loginType: friendInfo.loginType,
                        font: .headline,
                        fontWeight: .regular,
                        lineLimit: 1,
                        truncationMode: .tail
                    )
                        .onAppear {
                            if let objectId = friend.objectId, !objectId.isEmpty {
                            }
                        }
                    
                    // 在线状态
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isOnline ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        if isOnline {
                            Text("在线")
                                .font(.caption)
                                .foregroundColor(.green)
                                .onAppear {
                                    // UI渲染诊断：在线状态显示
                                    let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                }
                        } else {
                            HStack(spacing: 2) {
                                Text("离线")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .onAppear {
                                        // UI渲染诊断：离线状态显示
                                        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                    }
                                
                                if let lastActive = lastActiveTime {
                                    let now = Date()
                                    let timeInterval = now.timeIntervalSince(lastActive)
                                    
                                    // 如果超过7天，统一显示"7天前"
                                    if timeInterval >= 7 * 24 * 3600 {
                                        Text("最近上线 7天前")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .onAppear {
                                                // UI渲染诊断：最后活跃时间显示
                                                let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                                let formatter = DateFormatter()
                                                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                                            }
                                    } else {
                                        let formattedTime = formatLastActiveTime(lastActive)
                                        Text("最近上线 \(formattedTime)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .onAppear {
                                                // UI渲染诊断：最后活跃时间显示
                                                let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                                let formatter = DateFormatter()
                                                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                                            }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 🎯 新增：显示最新拍一拍消息摘要
                    if let latestPatMessage = getLatestPatMessage() {
                        Text(latestPatMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // 登录类型标签
                    HStack {
                        Text(loginTypeDisplayName(friendInfo.loginType))
                            .font(.caption)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(loginTypeColor(friendInfo.loginType))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // 拍一拍按钮
                Button(action: {
                    // 防止重复点击
                    let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                    let friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                    
                    
                    // 检查是否已经在处理中
                    if patButtonPressed[friendId] == true {
                        return
                    }
                    
                    
                    // 设置按钮状态，防止重复点击
                    patButtonPressed[friendId] = true
                    
                    // 延迟恢复按钮状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        patButtonPressed[friendId] = false
                    }
                    
                    // 自动展开拍一拍消息界面（如果未展开则展开，已展开则保持）
                    if !isPatMessagesExpanded {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            setPatMessagesExpanded(true)
                        }
                    } else {
                    }
                    
                    // 调用 onPat() 回调
                    onPat()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.tap")
                            .font(.caption)
                        Text("拍一拍")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(patButtonPressed[friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id] == true ? Color.blue.opacity(0.7) : Color.blue)
                    )
                    .scaleEffect(patButtonPressed[friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id] == true ? 0.98 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: patButtonPressed[friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id])
                }
                .buttonStyle(PlainButtonStyle())
                
                // 展开/折叠按钮（所有好友都显示）
                Button(action: {
                    let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                    let friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                    let currentState = isPatMessagesExpanded
                    
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        setPatMessagesExpanded(!isPatMessagesExpanded)
                    }
                }) {
                    Image(systemName: isPatMessagesExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isPatMessagesExpanded ? 0 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isPatMessagesExpanded)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle()) // 确保整个区域都可以点击
            #if os(iOS)
            .onTapGesture {
                // 🎯 修改：点击好友行（非头像区域）时切换拍一拍消息的展开/折叠状态
                // 注意：头像区域有自己的点击事件，不会触发这里
                let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                let friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                let currentState = isPatMessagesExpanded
                
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    setPatMessagesExpanded(!isPatMessagesExpanded)
                }
            }
            #elseif os(macOS)
            .onTapGesture {
                // 🎯 修改：macOS: 左键点击好友行（非头像区域）时切换展开/折叠
                // 注意：头像区域有自己的点击事件，不会触发这里
                let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                let friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                let currentState = isPatMessagesExpanded
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    setPatMessagesExpanded(!isPatMessagesExpanded)
                }
            }
            #endif
            .onAppear {
                let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                // 与用户头像界面一致：不使用全局缓存，直接使用行内的 loginType
                let _: String = friendInfo.loginType
                
                // 🔍 追踪：打印调用栈和状态
                
                // UI渲染诊断：FriendRowView出现
                
                // 🔧 新增：实时查询头像和用户名（与用户头像界面逻辑一致）
                if !hasLoadedFromServer && (avatarFromServer == nil || userNameFromServer == nil) {
                    hasLoadedFromServer = true
                    let friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                    
                    
                    // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
                    LeanCloudService.shared.fetchUserAvatarByUserId(objectId: friendId) { avatar, error in
                        DispatchQueue.main.async {
                            if error != nil {
                            } else if let avatar = avatar, !avatar.isEmpty {
                                
                                // 🔍 检查 UserDefaults 与服务器数据是否一致
                                let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: friendId)
                                if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                                    if defaultsAvatar != avatar {
                                        // 🔧 自动更新 UserDefaults 以保持一致性
                                        UserDefaultsManager.setCustomAvatar(userId: friendId, emoji: avatar)
                                    } else {
                                    }
                                } else {
                                    UserDefaultsManager.setCustomAvatar(userId: friendId, emoji: avatar)
                                }
                                
                                self.avatarFromServer = avatar
                                // 命中后写入本地缓存，减少后续查询
                                self.avatarCache[friendId] = avatar
                            } else {
                            }
                        }
                    }
                    
                    // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
                    let defaultName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                    LeanCloudService.shared.fetchUserNameByUserId(objectId: friendId) { name, error in
                        DispatchQueue.main.async {
                            if error != nil {
                            } else if let name = name, !name.isEmpty {
                                self.userNameFromServer = name
                                // 命中后写入本地缓存，减少后续查询
                                self.userNameCache[friendId] = name
                                
                                // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                                let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: friendId)
                                if userDefaultsUserName != name {
                                    UserDefaultsManager.setFriendUserName(userId: friendId, userName: name)
                                }
                                
                                if defaultName != name {
                                }
                            } else {
                            }
                        }
                    }
                } else {
                }
                
                // 🎯 优化：参考头像查询方式，统一查询逻辑
                // 查询在线时间（与头像查询方式一致）
                // 🔧 修复：先从缓存读取，如果没有缓存再查询服务器（与头像逻辑一致）
                if !hasLoadedOnlineStatus {
                    // 先尝试从本地缓存读取
                    if let cachedStatus = onlineStatusCache[friendId] {
                        // 有缓存，直接使用
                        self.isOnline = cachedStatus.0
                        self.lastActiveTime = cachedStatus.1
                        self.hasLoadedOnlineStatus = true
                    } else {
                        // 没有缓存，查询服务器
                        if !isLoadingOnlineStatus && lastActiveTime == nil {
                            isLoadingOnlineStatus = true
                            
                            // 直接使用 LCQuery 实时查询（参考 fetchUserAvatar 的方式）
                            LeanCloudService.shared.fetchUserLastOnlineTimeWithLCQuery(userId: friendId) { online, lastActive in
                                DispatchQueue.main.async {
                                    if let lastActive = lastActive {
                                        // 使用动画来平滑更新状态
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            self.isOnline = online
                                            self.lastActiveTime = lastActive
                                        }
                                        
                                        // 🎯 优化：更新缓存（与头像查询一致）
                                        self.onlineStatusCache[friendId] = (online, lastActive)
                                        
                                        // 🎯 优化：更新全局缓存（与头像查询一致）
                                        LeanCloudService.shared.cacheOnlineStatus(online, lastActiveTime: lastActive, for: friendId)
                                        
                                    } else {
                                        // 🔧 修复：查询失败时，回退到全局缓存（与头像查询一致）
                                        if let globalCachedStatus = LeanCloudService.shared.getCachedOnlineStatus(for: friendId) {
                                            // 有全局缓存，使用全局缓存
                                            self.isOnline = globalCachedStatus.0
                                            self.lastActiveTime = globalCachedStatus.1
                                            // 同时更新本地缓存
                                            self.onlineStatusCache[friendId] = globalCachedStatus
                                        } else {
                                            // 没有全局缓存，设置为默认值
                                            self.isOnline = false
                                            self.lastActiveTime = nil
                                        }
                                    }
                                    self.hasLoadedOnlineStatus = true
                                    self.isLoadingOnlineStatus = false
                                }
                            }
                        }
                    }
                }
                
                // 异步获取用户类型
                // 🔧 修复：先从缓存读取，如果没有缓存再查询服务器（与头像逻辑一致）
                if !hasLoadedLoginType {
                    // 先尝试从本地缓存读取
                    if let cachedLoginType = loginTypeCache[friendId], !cachedLoginType.isEmpty, cachedLoginType != "unknown" {
                        // 有缓存，直接使用
                        self.userLoginType = cachedLoginType
                        self.hasLoadedLoginType = true
                    } else {
                        // 没有缓存，查询服务器
                        hasLoadedLoginType = true
                        LeanCloudService.shared.fetchUserLoginType(objectId: friendInfo.id) { loginType in
                            DispatchQueue.main.async {
                                if let loginType = loginType, !loginType.isEmpty, loginType != "unknown" {
                                    self.userLoginType = loginType
                                    // 🎯 更新缓存（与头像查询一致）
                                    self.loginTypeCache[friendId] = loginType
                                } else {
                                    // 🔧 修复：查询失败时，使用推断逻辑作为兜底（与最近上线时间逻辑一致）
                                    let inferredType = UserTypeUtils.getLoginTypeFromUserId(friendId)
                                    if inferredType != "unknown" {
                                        self.userLoginType = inferredType
                                        // 更新缓存（使用推断的类型）
                                        self.loginTypeCache[friendId] = inferredType
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .task {
                // 🎯 新增：检查查询是否失败，如果失败则重试
                let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                // 检查是否查询失败且未达到最大重试次数
                let shouldRetryAvatar = avatarFromServer == nil && avatarRetryCount < 2
                let shouldRetryUserName = userNameFromServer == nil && userNameRetryCount < 2
                if shouldRetryAvatar {
                    retryLoadAvatarFromServer(friendId: friendId)
                }
                if shouldRetryUserName {
                    retryLoadUserNameFromServer(friendId: friendId)
                }
            }
            
            // 拍一拍消息列表（可折叠）
            if isPatMessagesExpanded {
                VStack(spacing: 8) {
                    // 查看对方最新位置功能（所有好友都显示）
                    HStack(spacing: 12) {
                        // 位置图标
                        Image(systemName: "location.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.green.opacity(0.1)))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            // 位置功能标题
                            Text("查看对方最新位置")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                              // 位置功能描述
                              Text("获取好友最新的位置信息")
                                  .font(.caption)
                                  .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 查看位置按钮 - 🎯 修改：与查看详情按钮完全一致，调用 onTap()
                        Button(action: {
                            // 🎯 修改：与查看详情按钮完全一致，调用 onTap() 而不是 onViewLocation
                            onTap()
                        }) {
                            Text("查看位置")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
                    
                    // 🔧 修复：展开时显示所有消息（包括已读消息），不限制于未读消息数量
                    if allFriendPatMessages.count > 0 {
                        ForEach(allFriendPatMessages, id: \.id) { patMessage in
                            // 🎯 新增：判断是"你拍了朋友"还是"朋友拍了你"
                            let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                            let friendObjectId = friend.objectId
                            
                            // 🔧 修复：判断消息方向
                            // 你拍了朋友：senderId == currentUserId && receiverId == friendId (或 friendObjectId)
                            let isIPatFriend = patMessage.senderId == currentUserId && 
                                             (patMessage.receiverId == friendId || (friendObjectId != nil && patMessage.receiverId == friendObjectId))
                            
                            // 朋友拍了你：senderId == friendId (或 friendObjectId) && receiverId == currentUserId
                            let isFriendPatMe = (patMessage.senderId == friendId || (friendObjectId != nil && patMessage.senderId == friendObjectId)) && 
                                               patMessage.receiverId == currentUserId
                            
                            // 🎯 使用 displayedName 获取朋友名字（可能来自服务器查询或缓存）
                            let friendDisplayName = displayedName
                            
                            // 生成显示文本
                            let displayText: String = {
                                if isIPatFriend {
                                    // 你拍了朋友
                                    return "你拍了拍 \(friendDisplayName)"
                                } else if isFriendPatMe {
                                    // 朋友拍了你
                                    // 优先使用消息中的发送者名字，如果没有或为"未知用户"则使用好友列表中的名字
                                    let senderName = (!patMessage.senderName.isEmpty && patMessage.senderName != "未知用户") ? patMessage.senderName : friendDisplayName
                                    return "\(senderName) 拍了拍你"
                                } else {
                                    // 默认显示原始内容（兜底逻辑）
                                    return patMessage.content
                                }
                            }()
                            
                            HStack(spacing: 12) {
                                // 拍一拍图标
                                Image(systemName: "hand.tap")
                                    .font(.system(size: 20))
                                    .foregroundColor(isIPatFriend ? .green : .blue) // 🎯 修改：你拍了朋友显示绿色，朋友拍了你显示蓝色
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill((isIPatFriend ? Color.green : Color.blue).opacity(0.1)))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    // 🎯 修改：显示"你拍了拍 [朋友名]" 或 "[朋友名] 拍了拍你"
                                    Text(displayText)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                    
                                    // 时间戳
                                    Text(formatTimeAgo(patMessage.timestamp))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                            .onAppear {
                                // 🔍 新增：打印拍一拍消息列表详细信息
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                                
                            }
                        }
                    } else {
                        // 没有拍一拍消息时显示的内容
                        HStack(spacing: 12) {
                            // 好友信息图标
                            Image(systemName: "person.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.gray.opacity(0.1)))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                // 好友信息
                                Text("点击查看好友详情")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                // 提示信息
                                Text("暂无拍一拍消息")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // 查看详情按钮
                            Button(action: {
                                onTap()
                            }) {
                                Text("查看详情")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        #if os(macOS)
        .contextMenu {
            if let onUnfriend = onUnfriend {
                Button(role: .destructive) {
                    onUnfriend()
                } label: {
                    Label("解除关系", systemImage: "person.crop.circle.badge.minus")
                }
            } else {
                Button(role: .destructive) {
                } label: {
                    Label("解除关系（未实现）", systemImage: "person.crop.circle.badge.minus")
                }
                .disabled(true)
            }
        }
        #endif
        .onAppear {
            #if os(macOS)
            #elseif os(iOS)
            #endif
        }
    }
    
    // 格式化时间差
    func formatTimeAgo(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)

        if timeInterval < 60 {
            return "刚刚"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟前"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)小时前"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)天前"
        } else {
            // 超过7天的都显示"7天前"
            return "7天前"
        }
    }
    
    // 获取登录类型显示名称（使用统一的UserTypeUtils）
    func loginTypeDisplayName(_ loginType: String) -> String {
        return UserTypeUtils.getUserTypeText(loginType)
    }
    
    // 获取登录类型颜色（使用统一的UserTypeUtils）
    func loginTypeColor(_ loginType: String) -> Color {
        return UserTypeUtils.getUserTypeColor(loginType)
    }
}

