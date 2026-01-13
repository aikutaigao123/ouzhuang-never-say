import SwiftUI
import Foundation

// 询问联系方式是否真实弹窗组件
struct ContactInquiryAlert: View {
    let isVisible: Bool
    let senderId: String
    let senderName: String
    let onGoToSettings: () -> Void
    let onConfirmReal: () -> Void
    let onDismiss: () -> Void
    let onAvatarTap: (() -> Void)? // 🎯 新增：头像点击回调
    
    @State private var avatar: String = ""
    @State private var userName: String = ""
    @State private var isLoadingAvatar = false
    @State private var isLoadingUserName = false
    
    var body: some View {
        if isVisible {
            ZStack {
                // 半透明背景
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        onDismiss()
                    }
                
                // 弹窗内容
                VStack(spacing: 0) {
                    // 顶部栏（标题和关闭按钮）
                    HStack {
                        Text("收到询问")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            onDismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)
                    
                    // 用户信息区域
                    VStack(spacing: 16) {
                        // 头像（可点击）
                        Button(action: {
                            onAvatarTap?()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 80, height: 80)
                                
                                if !avatar.isEmpty {
                                    if UserAvatarUtils.isSFSymbol(avatar) {
                                        if avatar == "applelogo" || avatar == "apple_logo" {
                                            Image(systemName: "applelogo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.black)
                                        } else {
                                            Image(systemName: avatar)
                                                .font(.system(size: 40))
                                                .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                                        }
                                    } else {
                                        Text(avatar)
                                            .font(.system(size: 40))
                                    }
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 用户名
                        Text(userName.isEmpty ? senderName : userName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // 询问内容
                        Text("询问你的联系方式是否真实")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    
                    // 按钮区域
                    HStack(spacing: 16) {
                        // 去设置按钮
                        Button(action: {
                            onGoToSettings()
                        }) {
                            Text("去设置")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        // 真实按钮
                        Button(action: {
                            onConfirmReal()
                        }) {
                            Text("真实")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .frame(width: 320)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .zIndex(1002)
            .onAppear {
                loadUserInfo()
            }
        }
    }
    
    // 加载用户信息（头像和用户名）
    private func loadUserInfo() {
        // 加载头像
        if !isLoadingAvatar {
            isLoadingAvatar = true
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: senderId) { fetchedAvatar, _ in
                DispatchQueue.main.async {
                    if let fetchedAvatar = fetchedAvatar, !fetchedAvatar.isEmpty {
                        self.avatar = fetchedAvatar
                    } else {
                        // 如果查询失败，尝试从 UserDefaults 获取
                        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: senderId), !customAvatar.isEmpty {
                            self.avatar = customAvatar
                        }
                    }
                    self.isLoadingAvatar = false
                }
            }
        }
        
        // 加载用户名
        if !isLoadingUserName {
            isLoadingUserName = true
            LeanCloudService.shared.fetchUserNameByUserId(objectId: senderId) { fetchedName, _ in
                DispatchQueue.main.async {
                    if let fetchedName = fetchedName, !fetchedName.isEmpty {
                        self.userName = fetchedName
                    } else {
                        // 如果查询失败，使用传入的 senderName
                        self.userName = senderName
                    }
                    self.isLoadingUserName = false
                }
            }
        }
    }
}
