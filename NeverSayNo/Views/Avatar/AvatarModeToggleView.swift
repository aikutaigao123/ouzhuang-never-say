import SwiftUI

// 扩展Character来检查是否为emoji
extension Character {
    var isEmoji: Bool {
        // 检查字符是否为emoji
        if let firstScalar = unicodeScalars.first {
            return firstScalar.properties.isEmoji
        }
        return false
    }
}

struct AvatarModeToggleView: View {
    @ObservedObject var avatarManager: AvatarManager
    @ObservedObject var userManager: UserManager
    @Binding var searchText: String
    @State private var isColorfulEnabled: Bool = false // 🎯 新增：彩色开关状态
    @State private var hasLoadedColorfulMode: Bool = false // 🎯 新增：是否已从服务器加载彩色模式状态
    
    var body: some View {
        VStack(spacing: 12) {
            // 解锁进度显示和搜索框在同一行
            HStack(spacing: 12) {
                // 解锁进度显示
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        
                        Text("解锁进度")
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    HStack(spacing: 8) {
                        Spacer()
                        
                        Text("\(unlockPercentage)%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    // 进度条
                    ProgressView(value: Double(ownedAvatarsCount), total: Double(totalEmojisCount))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(y: 0.8)
                }
                
                // 搜索输入框
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                                                                    TextField("搜索头像...", text: Binding(
                            get: { searchText },
                            set: { newValue in
                                searchText = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                            }
                        ))
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            // 切换模式按钮
            HStack {
                Spacer()
                
                // 🎯 新增：彩色开关按钮（在切换模式按钮左侧，只有解锁所有头像的用户才能看到）
                if canSwitchToDualAvatarMode {
                    Text("彩色")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Button(action: {
                        isColorfulEnabled.toggle()
                        
                        // 🎯 新增：更新 UserNameRecord 中的彩色模式状态
                        if let currentUser = userManager.currentUser {
                            let loginTypeString = currentUser.loginType == .apple ? "apple" : "guest"
                            LeanCloudService.shared.updateColorfulModeEnabled(
                                objectId: currentUser.id,
                                loginType: loginTypeString,
                                isEnabled: isColorfulEnabled
                            ) { success in
                                if success {
                                    // 更新成功，发送通知
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("ColorfulModeUpdated"),
                                        object: nil,
                                        userInfo: [
                                            "userId": currentUser.id,
                                            "enabled": isColorfulEnabled
                                        ]
                                    )
                                    // 更新 UserDefaults 缓存
                                    UserDefaultsManager.setColorfulModeEnabled(userId: currentUser.id, enabled: isColorfulEnabled)
                                } else {
                                    // 更新失败，但不影响用户体验，静默处理
                                }
                            }
                        }
                    }) {
                        ZStack {
                            // 背景
                            RoundedRectangle(cornerRadius: 16)
                                .fill(isColorfulEnabled ? 
                                      LinearGradient(
                                          colors: [
                                              .red,
                                              .orange,
                                              .yellow,
                                              .green,
                                              .blue,
                                              .indigo,
                                              .purple,
                                              .pink
                                          ],
                                          startPoint: .leading,
                                          endPoint: .trailing
                                      ) : 
                                      LinearGradient(
                                          colors: [.gray.opacity(0.3)],
                                          startPoint: .leading,
                                          endPoint: .trailing
                                      )
                                )
                                .frame(width: 50, height: 30)
                            
                            // 开关圆点
                            Circle()
                                .fill(.white)
                                .frame(width: 24, height: 24)
                                .offset(x: isColorfulEnabled ? 10 : -10)
                                .animation(.spring(response: 0.3), value: isColorfulEnabled)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 添加间距
                    Spacer()
                        .frame(width: 8)
                }
                
                if canSwitchToDualAvatarMode {
                    Button(action: { avatarManager.switchToDualAvatarMode() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.circle")
                                .font(.system(size: 14))
                            Text("切换模式")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        .onAppear {
            // 🎯 新增：从 UserNameRecord 加载彩色模式状态
            if canSwitchToDualAvatarMode && !hasLoadedColorfulMode {
                loadColorfulModeFromServer()
            }
        }
        .onChange(of: canSwitchToDualAvatarMode) { oldValue, newValue in
            // 🎯 新增：当解锁所有头像时，加载彩色模式状态
            if newValue && !hasLoadedColorfulMode {
                loadColorfulModeFromServer()
            }
        }
    }
    
    // 🎯 新增：从服务器加载彩色模式状态
    private func loadColorfulModeFromServer() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let loginTypeString = currentUser.loginType == .apple ? "apple" : "guest"
        
        LeanCloudService.shared.fetchColorfulModeEnabled(
            objectId: currentUser.id,
            loginType: loginTypeString
        ) { isEnabled in
            DispatchQueue.main.async {
                if let isEnabled = isEnabled {
                    self.isColorfulEnabled = isEnabled
                } else {
                    // 如果查询失败或字段不存在，默认为 false
                    self.isColorfulEnabled = false
                }
                self.hasLoadedColorfulMode = true
            }
        }
    }
    
    // 解锁进度相关计算属性
    private var ownedAvatarsCount: Int {
        let diamondManager = userManager.diamondManager
        return diamondManager?.ownedAvatars.count ?? 0
    }
    
    private var totalEmojisCount: Int {
        return EmojiList.allEmojis.count
    }
    
    private var unlockPercentage: Int {
        guard totalEmojisCount > 0 else { return 0 }
        let percentage = Int((Double(ownedAvatarsCount) / Double(totalEmojisCount)) * 100)
        // 打印解锁进度（只在UI更新时打印，不会太频繁）
        return percentage
    }
    
    private var unlockProgressText: String {
        return "\(ownedAvatarsCount)/\(totalEmojisCount)"
    }
    
    private var canSwitchToDualAvatarMode: Bool {
        return !avatarManager.isDualAvatarMode && ownedAvatarsCount >= totalEmojisCount
    }
}

