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
        }
    }
}
