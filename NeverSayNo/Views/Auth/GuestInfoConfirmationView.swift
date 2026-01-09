import SwiftUI

struct GuestInfoConfirmationView: View {
    @Binding var displayName: String
    @Binding var email: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    var userManager: UserManager? // 可选的 UserManager，用于获取用户信息
    @State private var showEditAlert = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var userNameFromServer: String? = nil // 从 UserNameRecord 表读取的用户名
    @State private var userAvatarFromServer: String? = nil // 从 UserAvatarRecord 表读取的头像
    @State private var emailFromServer: String? = nil // 从 UserNameRecord 表读取的邮箱
    @State private var agreedToTerms = false
    
    // 优先使用 UserNameRecord 表中的用户名，否则使用传入的 displayName
    private var displayedUserName: String {
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        return displayName.isEmpty ? "未填写" : displayName
    }
    
    // 头像显示逻辑：优先使用 UserAvatarRecord 表中的头像，否则使用系统图标
    // 与用户头像界面一致：支持SF Symbol和emoji/文本
    @ViewBuilder
    private var avatarView: some View {
        if let avatar = userAvatarFromServer, !avatar.isEmpty {
            if avatar == "apple_logo" || avatar == "applelogo" {
                Image(systemName: "applelogo")
                    .font(.system(size: 80))
                    .foregroundColor(.black)
            } else if UserAvatarUtils.isSFSymbol(avatar) {
                // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                Image(systemName: avatar)
                    .font(.system(size: 80))
                    .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
            } else {
                Text(avatar)
                    .font(.system(size: 80))
                    .fixedSize(horizontal: true, vertical: false)
            }
        } else {
            // 与用户头像界面一致：游客用户使用person.circle（蓝色）
            Image(systemName: "person.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue)
        }
    }
    
    init(displayName: Binding<String>, email: Binding<String>, onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void, userManager: UserManager? = nil) {
        self._displayName = displayName
        self._email = email
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        self.userManager = userManager
    }

    var body: some View {
        VStack(spacing: 30) {
            // 标题
            Text("游客信息确认")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)
            // 头像
            avatarView
                .padding(.bottom, 20)
            // 用户信息卡片
            VStack(spacing: 20) {
                // 用户名
                VStack(alignment: .leading, spacing: 8) {
                    Text("用户名")
                        .font(.headline)
                        .foregroundColor(.gray)
                    HStack {
                        let currentUserId = userManager?.currentUser?.id ?? userManager?.currentUser?.userId ?? ""
                        ColorfulUserNameText(
                            userName: displayedUserName,
                            userId: currentUserId,
                            loginType: "guest",
                            font: .title2,
                            fontWeight: .medium,
                            lineLimit: 1,
                            truncationMode: .tail
                        )
                        // 🔧 修复：监听用户名更新通知，立即更新显示
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserNameUpdated"))) { notification in
                                if let userInfo = notification.userInfo,
                                   let newUserName = userInfo["userName"] as? String,
                                   let userManager = userManager,
                                   let currentUserId = userManager.currentUser?.id {
                                    // 立即更新用户名显示
                                    self.userNameFromServer = newUserName
                                    // 更新 binding
                                    if newUserName != self.displayName {
                                        self.displayName = newUserName
                                    }
                                    // 清除用户名缓存
                                    LeanCloudService.shared.clearCacheForUser(currentUserId)
                                }
                            }
                        Spacer()
                        Button(action: {
                            // 游客用户不允许编辑，显示提示（与个人信息界面一致）
                            showEditAlert = true
                        }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    Text("该名称将用于与其他用户匹配时显示")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .onAppear {
                    
                    // 优先从 UserNameRecord 表读取用户名，从 UserAvatarRecord 表读取头像
                    guard let userManager = userManager,
                          let userId = userManager.currentUser?.userId,
                          let loginType = userManager.currentUser?.loginType else {
                        return
                    }
                    
                    let loginTypeString = loginType == .apple ? "apple" : "guest"
                    
                    // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
                    LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { serverName, error in
                        DispatchQueue.main.async {
                            if error != nil {
                                self.userNameFromServer = nil
                            } else if let serverName = serverName, !serverName.isEmpty {
                                self.userNameFromServer = serverName
                                // 更新 binding
                                if serverName != self.displayName {
                                    self.displayName = serverName
                                }
                                
                                // 🎯 新增：检查 UserDefaults 与服务器数据是否一致，自动同步更新（与个人信息界面一致）
                                let userDefaultsUserName = UserDefaultsManager.getCurrentUserName()
                                if !userDefaultsUserName.isEmpty {
                                    if userDefaultsUserName != serverName {
                                        // 🔧 自动更新 UserDefaults 以保持一致性
                                        UserDefaultsManager.setCurrentUserName(serverName)
                                    }
                                } else {
                                    UserDefaultsManager.setCurrentUserName(serverName)
                                }
                            } else {
                                self.userNameFromServer = nil
                            }
                        }
                    }
                    
                    // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
                    LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
                        DispatchQueue.main.async {
                            if error != nil {
                                self.userAvatarFromServer = nil
                            } else if let avatar = avatar, !avatar.isEmpty {
                                // 🎯 新增：检查 UserDefaults 与服务器数据是否一致，自动同步更新（与个人信息界面一致）
                                let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                                if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                                    if defaultsAvatar != avatar {
                                        // 🔧 自动更新 UserDefaults 以保持一致性
                                        UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                                    }
                                } else {
                                    UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                                }
                                self.userAvatarFromServer = avatar
                            } else {
                                self.userAvatarFromServer = nil
                            }
                        }
                    }
                    
                    // 读取邮箱 - 与用户名查询逻辑一致
                    LeanCloudService.shared.fetchUserEmail(objectId: userId, loginType: loginTypeString) { serverEmail, error in
                        DispatchQueue.main.async {
                            if error != nil {
                                self.emailFromServer = nil
                            } else if let serverEmail = serverEmail, !serverEmail.isEmpty {
                                self.emailFromServer = serverEmail
                                // 更新 binding
                                if serverEmail != self.email {
                                    self.email = serverEmail
                                }
                            } else {
                                self.emailFromServer = nil
                            }
                        }
                    }
                }
                // 邮箱
                VStack(alignment: .leading, spacing: 8) {
                    Text("邮箱地址（可选）")
                        .font(.headline)
                        .foregroundColor(.gray)
                    HStack {
                        // 与用户名显示逻辑一致：优先使用从服务器查询的邮箱
                        let displayedEmail = emailFromServer ?? email
                        Text(displayedEmail.isEmpty ? "未填写" : displayedEmail)
                            .font(.title2)
                            .foregroundColor(displayedEmail.isEmpty ? .gray : .blue)
                        Spacer()
                        Button(action: {
                            // 游客用户不允许编辑，显示提示（与个人信息界面一致）
                            showEditAlert = true
                        }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            Spacer()
            
            // 协议勾选区域
            VStack(spacing: 8) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: agreedToTerms ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(agreedToTerms ? .blue : .gray)
                        .font(.system(size: 18))
                        .onTapGesture { agreedToTerms.toggle() }
                    HStack(spacing: 0) {
                        Text("已阅读并同意")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button("📋 用户协议") {
                            showTermsOfService = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        Text("和")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button("📄 隐私政策") {
                            showPrivacyPolicy = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .onTapGesture { agreedToTerms.toggle() }
                    Spacer()
                }
            }
            .padding(.horizontal, 20)
            
            // 按钮区域
            VStack(spacing: 12) {
                Button(action: {
                    // 🎯 新增：上传登录记录到LoginRecord表
                    if let userManager = userManager,
                       let userId = userManager.currentUser?.userId,
                       let userName = userManager.currentUser?.fullName {
                        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                        let userEmail = userManager.currentUser?.email
                        
                        LeanCloudService.shared.recordLogin(
                            userId: userId,
                            userName: userName,
                            userEmail: userEmail,
                            loginType: "guest",
                            deviceId: deviceID
                        ) { success in
                            if success {
                                userManager.updateLastLoginRecordUploadTime()
                            }
                        }
                    }
                    onConfirm()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("确认并登录")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !agreedToTerms)
                Button(action: {
                    onCancel()
                }) {
                    Text("取消")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    onCancel()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .alert("提示", isPresented: $showEditAlert) {
            Button("确定") { }
        } message: {
            Text("游客登录模式下，信息无法修改。如需修改信息，请使用 Apple ID 登录。")
        }
    }
}
