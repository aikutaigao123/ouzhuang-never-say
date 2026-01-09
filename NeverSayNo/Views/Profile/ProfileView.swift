import SwiftUI

// 个人信息界面主结构
struct ProfileView: View {
    @ObservedObject var userManager: UserManager
    @ObservedObject var diamondManager: DiamondManager
    @Binding var showLogoutAlert: Bool
    @Binding var showRechargeSheet: Bool
    @Binding var newUserName: String
    let isUserBlacklisted: Bool
    let onClearAllHistory: () -> Void
    let onShowHistory: () -> Void
    @ObservedObject var newFriendsCountManager: NewFriendsCountManager
    let onNavigateToTab: (Int) -> Void
    let showBottomTabBar: Bool
    
    @Environment(\.dismiss) var dismiss
    @State var showPrivacyPolicy = false
    @State var showTermsOfService = false
    @State var showGuestNameAlert = false
    @State var showDeleteAccountAlert = false
    @State var showEditNameAlert = false
    @State var showAvatarZoom = false
    @State var showEditEmailInputAlert = false // 修改邮箱输入弹窗
    @State var newEmail = ""
    @State var showEmailEditAlert = false
    @State var emailEditMessage = ""
    @State var showUserNameError = false // 🎯 新增：用户名错误提示
    @State var userNameErrorMessage = "" // 🎯 新增：用户名错误信息
    @State var showUserEmailError = false // 🎯 新增：邮箱错误提示
    @State var userEmailErrorMessage = "" // 🎯 新增：邮箱错误信息
    @State var userAvatarFromServer: String? = nil // 从 UserAvatarRecord 表读取的头像
    @State var userNameFromServer: String? = nil // 从 UserNameRecord 表读取的用户名
    @State var emailFromServer: String? = nil // 从 UserNameRecord 表读取的邮箱
    @State var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    @State var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    @State var showHistoryLimitAlert = false // 🎯 历史记录按钮限制提示（internal 以便扩展访问）
    @State var historyLimitMessage = "" // 🎯 历史记录按钮限制提示信息（internal 以便扩展访问）
    @State var showBlacklistView = false // 🎯 新增：显示黑名单界面
    @State var showClearCacheSuccessAlert = false // 🎯 新增：清理本地缓存成功提示
    // 🎯 移除：diamondsFromServer 不再需要，使用 diamondManager.diamonds（通过 DiamondStore 自动同步）
    
    @State private var selectedProfileTab = 0
    @State var showDeleteProgress = false // 🗑️ 新增：显示删除进度
    @State var deleteProgressCurrentTable = "" // 🗑️ 当前正在删除的表
    @State var deleteProgressCompletedTables = 0 // 🗑️ 已完成的表数
    @State var deleteProgressTotalTables = 17 // 🗑️ 总表数
    @State var deleteProgressCurrentDeletedCount = 0 // 🗑️ 当前表已删除的记录数
    @State var deleteConfirmationText = "" // 🗑️ 删除确认输入文字
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 用户基本信息
                    userInfoCard
                    
                    // 钻石信息
                    diamondInfoCard
                    
                    // 设置选项
                    settingsButtons
                }
                .padding()
            }
            .navigationTitle("个人信息")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HistoryButtonLimitExceeded"))) { notification in
                // 🎯 新增：监听历史记录按钮限制通知
                if let message = notification.userInfo?["message"] as? String {
                    historyLimitMessage = message
                    showHistoryLimitAlert = true
                }
            }
            .onAppear {
                // 🔧 修复：在 ProfileView 出现时刷新用户名和头像
                // 这会触发 userInfoCard 中的 onAppear，从而调用 loadUserNameFromServer()
                
                // 🎯 新增：检查并自动创建UserNameRecord（如果没有数据则生成随机用户名）
                if let userId = userManager.currentUser?.id,
                   let loginType = userManager.currentUser?.loginType {
                    let loginTypeString = loginType == .apple ? "apple" : "guest"
                    
                    LeanCloudService.shared.ensureCurrentUserUserNameRecordExists(
                        objectId: userId,
                        loginType: loginTypeString,
                        userName: nil, // 传入nil会自动生成随机用户名
                        userEmail: userManager.currentUser?.email
                    ) { success, message in
                        if success {
                            // 刷新UI显示
                            let userName = UserDefaultsManager.getCurrentUserName()
                            if !userName.isEmpty {
                                DispatchQueue.main.async {
                                    // 🎯 修改：同时更新 ProfileView 的本地状态和 UserManager 的共享状态
                                    userNameFromServer = userName
                                    userManager.userNameFromServer = userName
                                }
                            }
                        }
                    }
                    
                    // 🎯 新增：检查并自动创建UserAvatarRecord（如果没有数据则生成随机emoji头像）
                    LeanCloudService.shared.ensureCurrentUserAvatarRecordExists(
                        objectId: userId,
                        loginType: loginTypeString,
                        userAvatar: nil // 传入nil会自动生成随机emoji
                    ) { success, message in
                        if success {
                            // 刷新UI显示
                            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
                                if let avatar = avatar, !avatar.isEmpty {
                                    DispatchQueue.main.async {
                                        userAvatarFromServer = avatar
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showBlacklistView) {
            LocalBlacklistView()
        }
        .sheet(isPresented: $showAvatarZoom) {
            AvatarZoomView(userManager: userManager, showRandomButton: true)
        }
        .alert("提示", isPresented: $showGuestNameAlert) {
            Button("确定") { }
        } message: {
            let messageText = "游客登录模式下，信息无法修改。如需修改信息，请使用 Apple ID 登录。"
            Text(messageText)
        }
        .sheet(isPresented: $showEditNameAlert) {
            EditUserNameSheet(
                userManager: userManager,
                isPresented: $showEditNameAlert,
                userNameFromServer: $userNameFromServer
            )
            .presentationBackground(.clear)
        }
        .alert("删除账号", isPresented: $showDeleteAccountAlert) {
            TextField("请输入\"删除\"以确认", text: $deleteConfirmationText)
                .autocapitalization(.none)
                .autocorrectionDisabled()
            
            Button("取消", role: .cancel) {
                deleteConfirmationText = "" // 取消时清空输入
            }
            
            Button("删除", role: .destructive) {
                deleteUserAccount()
                deleteConfirmationText = "" // 删除后清空输入
            }
            .disabled(deleteConfirmationText.trimmingCharacters(in: .whitespacesAndNewlines) != "删除")
        } message: {
            Text("删除账号后，您的所有数据将立即从服务器永久删除，此操作不可恢复。\n\n请在下方输入框中输入「删除」以确认此操作。")
        }
        .sheet(isPresented: $showEditEmailInputAlert) {
            EditEmailSheet(
                userManager: userManager,
                isPresented: $showEditEmailInputAlert,
                emailFromServer: $emailFromServer
            )
            .presentationBackground(.clear)
        }
        .alert("用户名错误", isPresented: $showUserNameError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(userNameErrorMessage)
        }
        .alert("邮箱错误", isPresented: $showUserEmailError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(userEmailErrorMessage)
        }
        .alert("邮箱编辑", isPresented: $showEmailEditAlert) {
            Button("确定") { }
        } message: {
            Text(emailEditMessage)
        }
        .alert("邮箱错误", isPresented: $showUserEmailError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(userEmailErrorMessage)
        }
        .sheet(isPresented: $showDeleteProgress) {
            DeleteAccountProgressView(
                currentTable: $deleteProgressCurrentTable,
                completedTables: $deleteProgressCompletedTables,
                totalTables: $deleteProgressTotalTables,
                currentDeletedCount: $deleteProgressCurrentDeletedCount
            )
            .presentationDetents([.medium])
            .interactiveDismissDisabled(true) // 禁用下拉关闭，防止误操作
        }
    }
}
