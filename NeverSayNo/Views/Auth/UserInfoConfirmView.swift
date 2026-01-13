import SwiftUI

struct UserInfoConfirmView: View {
    @ObservedObject var userManager: UserManager
    var onConfirm: () -> Void
    var onBack: () -> Void
    @State private var showEditNameAlert = false
    @State private var showEditEmailAlert = false
    @State private var agreedToTerms = false
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    @State private var showEditEmailInputAlert = false // 修改邮箱输入弹窗
    @State private var newEmail = ""
    @State private var showEmailEditAlert = false
    @State private var emailEditMessage = ""
    @State private var newUserName = ""
    @State private var showUserNameError = false // 🎯 新增：用户名错误提示
    @State private var userNameErrorMessage = "" // 🎯 新增：用户名错误信息
    @State private var userNameFromServer: String? = nil // 从 UserNameRecord 表读取的用户名
    @State private var userAvatarFromServer: String? = nil // 从 UserAvatarRecord 表读取的头像
    @State private var emailFromServer: String? = nil // 从 UserNameRecord 表读取的邮箱
    
    // 优先使用 UserNameRecord 表中的用户名，否则使用 UserManager 中的用户名
    private var displayedUserName: String {
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        return userManager.currentUser?.fullName ?? "未知用户"
    }
    
    // 头像显示逻辑：优先使用 UserAvatarRecord 表中的头像，否则使用系统图标 - Apple账号与内部账号使用相同的默认头像
    @ViewBuilder
    private var avatarView: some View {
        if let avatar = userAvatarFromServer, !avatar.isEmpty {
            // 与用户头像界面一致：支持SF Symbol和emoji/文本
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
            // Apple账号与内部账号使用相同的默认头像
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.purple)
        }
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("用户信息确认")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            avatarView
                .padding(.bottom, 20)
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("用户名")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        let currentUserId = userManager.currentUser?.id ?? ""
                        let currentLoginType = userManager.currentUser?.loginType == .apple ? "apple" : "guest"
                        ColorfulUserNameText(
                            userName: displayedUserName,
                            userId: currentUserId,
                            loginType: currentLoginType,
                            font: .title2,
                            fontWeight: .medium,
                            lineLimit: 1,
                            truncationMode: .tail
                        )
                        // 🔧 修复：监听用户名更新通知，立即更新显示
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserNameUpdated"))) { notification in
                                if let userInfo = notification.userInfo,
                                   let newUserName = userInfo["userName"] as? String,
                                   let currentUserId = userManager.currentUser?.id,
                                   let updatedUserId = userInfo["userId"] as? String,
                                   updatedUserId == currentUserId {
                                    // 立即更新用户名显示
                                    self.userNameFromServer = newUserName
                                    self.userManager.userNameFromServer = newUserName
                                    
                                    // 清除用户名缓存，确保下次查询时获取最新数据
                                    LeanCloudService.shared.clearCacheForUser(currentUserId)
                                }
                            }
                            .onChange(of: userManager.currentUser?.fullName) { oldValue, newValue in
                            }
                        
                        Spacer()
                        
                        Button(action: {
                            newUserName = displayedUserName
                            showEditNameAlert = true
                        }) {
                            Image(systemName: "pencil.circle")
                                .foregroundColor(.blue)
                                .font(.title3)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .onAppear {
                        // 优先从 UserNameRecord 表读取用户名，从 UserAvatarRecord 表读取头像
                        // 🔧 统一使用 objectId 作为 userId
                        guard let userId = userManager.currentUser?.id,
                              let loginType = userManager.currentUser?.loginType else {
                            return
                        }
                        
                        let loginTypeString = loginType == .apple ? "apple" : "guest"
                        
                        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
                        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { serverName, error in
                            DispatchQueue.main.async {
                                if error != nil {
                                    // 查询失败时使用 UserManager 中的用户名
                                    self.userNameFromServer = nil
                                } else if let serverName = serverName, !serverName.isEmpty {
                                    self.userNameFromServer = serverName
                                    
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
                                    
                                    // 如果服务器用户名与 UserManager 中的不一致，打印警告
                                    let managerName = userManager.currentUser?.fullName ?? "未知用户"
                                    if serverName != managerName {
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
                        LeanCloudService.shared.fetchUserEmail(objectId: userId, loginType: loginTypeString) { email, error in
                            DispatchQueue.main.async {
                                if error != nil {
                                    self.emailFromServer = nil
                                } else if let email = email, !email.isEmpty {
                                    self.emailFromServer = email
                                } else {
                                    self.emailFromServer = nil
                                }
                            }
                        }
                    }
                    .onChange(of: userManager.currentUser?.fullName) { oldValue, newValue in
                    }
                    
                    Text("该名称将用于与其他用户匹配时显示")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("邮箱地址（可选）")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        // 与用户名显示逻辑一致：优先使用从服务器查询的邮箱
                        let displayedEmail = emailFromServer ?? userManager.currentUser?.email ?? ""
                        Text(displayedEmail.isEmpty ? "未填写" : displayedEmail)
                            .font(.title2)
                            .foregroundColor(displayedEmail.isEmpty ? .gray : .blue)
                        Spacer()
                        Button(action: {
                            // 显示修改邮箱弹窗
                            newEmail = emailFromServer ?? userManager.currentUser?.email ?? ""
                            showEditEmailInputAlert = true
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
            
            VStack(spacing: 12) {
                Button(action: {
                    // 🎯 新增：上传登录记录到LoginRecord表
                    if let userId = userManager.currentUser?.userId,
                       let userName = userManager.currentUser?.fullName {
                        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                        let userEmail = userManager.currentUser?.email
                        let loginType = userManager.currentUser?.loginType == .apple ? "apple" : "guest"
                        
                        // Apple登录使用recordAppleLoginWithAuthData，其他使用recordLogin
                        if loginType == "apple" {
                            // 构建authData（简化版本，因为此时已经登录成功）
                            let authData: [String: Any] = [
                                "lc_apple": [
                                    "uid": userId
                                ]
                            ]
                            LeanCloudService.shared.recordAppleLoginWithAuthData(
                                userId: userId,
                                userName: userName,
                                userEmail: userEmail,
                                authData: authData,
                                deviceId: deviceID
                            ) { success in
                                if success {
                                    userManager.updateLastLoginRecordUploadTime()
                                }
                            }
                        } else {
                            LeanCloudService.shared.recordLogin(
                                userId: userId,
                                userName: userName,
                                userEmail: userEmail,
                                loginType: loginType,
                                deviceId: deviceID
                            ) { success in
                                if success {
                                    userManager.updateLastLoginRecordUploadTime()
                                }
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
                .disabled(!agreedToTerms)
                
                Button(action: {
                    onBack()
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
                    onBack()
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
        .alert("修改用户名", isPresented: $showEditNameAlert) {
            TextField("请输入新的用户名", text: Binding(
                get: { newUserName },
                set: { newValue in
                    newUserName = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                }
            ))
            Button("取消", role: .cancel) { }
            Button("确定") {
                let trimmedName = newUserName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else {
                    return
                }
                
                // 🎯 新增：验证并更新用户名
                userManager.updateUserName(trimmedName) { success, error in
                    if success {
                        // 🔧 立即更新 userNameFromServer，使界面立即刷新
                        userNameFromServer = trimmedName
                        
                        // 清除用户名缓存，确保下次查询时获取最新数据
                        if let userId = userManager.currentUser?.id {
                            LeanCloudService.shared.clearCacheForUser(userId)
                        }
                        
                        newUserName = ""
                    } else {
                        // 显示错误信息
                        if let error = error {
                            userNameErrorMessage = error
                            showUserNameError = true
                        }
                    }
                }
            }
        } message: {
            Text("请输入您想要的新用户名")
        }
        .alert("用户名错误", isPresented: $showUserNameError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(userNameErrorMessage)
        }
        .alert("修改邮箱", isPresented: $showEditEmailInputAlert) {
            let trackingBinding = Binding<String>(
                get: { newEmail },
                set: { newValue in
                    newEmail = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                }
            )
            TextField("请输入新的邮箱地址", text: trackingBinding)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button("取消", role: .cancel) {
                newEmail = ""
            }
            Button("确定") {
                saveEmail()
                newEmail = ""
            }
        } message: {
            Text("请输入您想要的新邮箱地址")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            userManager.checkAndUpdateAppleIDInfo()
        }
        .alert("邮箱编辑", isPresented: $showEmailEditAlert) {
            Button("确定") { }
        } message: {
            Text(emailEditMessage)
        }
    }
    
    private func saveEmail() {
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
        
        // 更新用户管理器中的邮箱
        userManager.updateUserEmail(finalEmail) { success, error in
            // 静默处理，不显示错误提示（在用户信息确认界面，用户通常不需要看到详细的错误信息）
        }
        
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
    }
    
    // 验证邮箱格式
    func isValidEmail(_ email: String) -> Bool {
        // 🎯 修改：使用统一的验证工具，支持emoji
        return ValidationUtils.isValidEmail(email)
    }
}
