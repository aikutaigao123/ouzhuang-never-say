import SwiftUI

struct AvatarBackpackView: View {
    @ObservedObject var userManager: UserManager
    @Binding var currentAvatarEmoji: String?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var avatarManager = AvatarManager()
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var searchText = ""
    @State private var showCopySuccess = false
    @State private var copySuccessMessage = ""
    @State private var ownedAvatarsQueryRetryCount = 0  // 🎯 新增：已拥有头像查询重试计数器
    
    var body: some View {
        NavigationView {
            ZStack {
                // 主要内容
                VStack {
                    // 顶部间距，让整体内容下移
                    Spacer()
                        .frame(height: 20)
                    
                    // 双头像模式组件
                    if avatarManager.isDualAvatarMode {
                        DualAvatarModeView(
                            avatarManager: avatarManager,
                            onConfirmDualAvatar: {
                                AvatarSelectionHandler.confirmDualAvatar(
                                    avatarManager: avatarManager,
                                    currentAvatarEmoji: &currentAvatarEmoji,
                                    userManager: userManager,
                                    dismiss: { dismiss() }
                                )
                            }
                        )
                    }
                    
                    // 模式切换组件
                    AvatarModeToggleView(
                        avatarManager: avatarManager,
                        userManager: userManager,
                        searchText: $searchText
                    )
                    
                    // 头像选择网格
                    AvatarSelectionGrid(
                        avatarManager: avatarManager,
                        currentAvatarEmoji: $currentAvatarEmoji,
                        userManager: userManager,
                        searchText: $searchText,
                        onCopyEmoji: { emoji in
                            UIPasteboard.general.string = emoji
                            copySuccessMessage = "头像已复制"
                            showCopySuccess = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showCopySuccess = false
                            }
                        }
                    )
                    
                    // 底部间距
                    Spacer()
                }
                
                // 复制成功提示 - 覆盖在内容之上
                if showCopySuccess {
                    VStack {
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18))
                            Text(copySuccessMessage)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false) // 强制不换行
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.green)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .padding(.bottom, 10) // 距离屏幕底部的距离
                        .transition(.opacity.combined(with: .scale))
                        .animation(.easeInOut(duration: 0.3), value: showCopySuccess)
                        .allowsHitTesting(false) // 防止遮挡下方内容
                    }
                }
            }
        }
        .navigationTitle("头像背包")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("完成") { dismiss() })
        .alert("提示", isPresented: $showAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            avatarManager.loadOwnedAvatars(userManager: userManager)
            avatarManager.checkDualAvatarMode()
            // 🎯 新增：每次打开头像背包界面时重新查询已拥有头像列表（带重试机制）
            ownedAvatarsQueryRetryCount = 0  // 重置重试计数器
            queryOwnedAvatarsWithRetry()
        }
    }
    
    // 🎯 新增：查询已拥有头像列表（带重试机制，参考充值界面的钻石查询）
    private func queryOwnedAvatarsWithRetry() {
        guard let diamondManager = userManager.diamondManager,
              let userId = userManager.currentUser?.id,
              let loginType = userManager.currentUser?.loginType else {
            return
        }
        
        let loginTypeString = loginType == .apple ? "apple" : "guest"
        
        // 直接调用 LeanCloudService 的查询方法，这样可以获得 completion 回调
        LeanCloudService.shared.fetchOwnedAvatars(userId: userId, loginType: loginTypeString) { ownedAvatars, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 查询失败，如果未达到最大重试次数（2次），则重试
                    if self.ownedAvatarsQueryRetryCount < 2 {
                        self.ownedAvatarsQueryRetryCount += 1
                        
                        // 根据重试次数决定延迟时间（与用户名重试机制一致）
                        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
                        let delay: TimeInterval = self.ownedAvatarsQueryRetryCount == 1 ? 1.0 / 17.0 : 0.5
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.queryOwnedAvatarsWithRetry()
                        }
                    }
                } else {
                    // 查询成功
                    if let ownedAvatars = ownedAvatars {
                        // 更新 DiamondManager 的 ownedAvatars
                        diamondManager.ownedAvatars = ownedAvatars
                        // 更新 AvatarManager 的 ownedAvatars
                        self.avatarManager.loadOwnedAvatars(userManager: self.userManager)
                    } else {
                        // 查询成功但返回空数组，也更新
                        diamondManager.ownedAvatars = []
                        self.avatarManager.loadOwnedAvatars(userManager: self.userManager)
                    }
                    self.ownedAvatarsQueryRetryCount = 0  // 重置重试计数器
                }
            }
        }
    }
}
