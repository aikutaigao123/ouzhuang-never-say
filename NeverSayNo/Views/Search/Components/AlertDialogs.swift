import SwiftUI

struct AlertDialogs: ViewModifier {
    @Binding var showAlert: Bool
    @Binding var showLogoutAlert: Bool
    @Binding var showEditNameAlert: Bool
    @Binding var showEditEmailAlert: Bool
    @Binding var showCancelDeletionAlert: Bool
    @Binding var showFriendRequestLimitAlert: Bool
    @Binding var showPatActionLimitAlert: Bool
    @Binding var showMessageButtonLimitAlert: Bool
    @Binding var newUserName: String
    @Binding var resultMessage: String
    @Binding var pendingDeletionDate: String
    @Binding var friendRequestLimitMessage: String
    @Binding var patActionLimitMessage: String
    @Binding var messageButtonLimitMessage: String
    
    let userManager: UserManager
    let onLogout: () -> Void
    let onUpdateUserName: (String) -> Void
    let onCancelDeletion: () -> Void
    let onContinueDeletion: () -> Void
    
    func body(content: Content) -> some View {
        content
            // 提示弹窗
            .alert("提示", isPresented: $showAlert) {
                Button("确定") { }
            } message: {
                Text(resultMessage)
            }
            
            // 确认退出弹窗
            .alert("确认退出", isPresented: $showLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    onLogout()
                }
            } message: {
                Text("确定要退出登录吗？")
            }
            
            // 自定义昵称弹窗
            .alert("自定义昵称", isPresented: $showEditNameAlert) {
                TextField("输入新昵称", text: Binding(
                    get: { newUserName },
                    set: { newValue in
                        newUserName = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                    }
                ))
                Button("取消", role: .cancel) {
                    newUserName = ""
                }
                Button("确定") {
                    if !newUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onUpdateUserName(newUserName.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    newUserName = ""
                }
            } message: {
                Text("请输入您喜欢的昵称")
            }
            
            // 更改邮箱弹窗
            .alert("更改邮箱", isPresented: $showEditEmailAlert) {
                Button("去设置") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl) { success in
                            if success {
                            } else {
                            }
                        }
                    } else {
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请输入您想要的新邮箱地址")
            }
            
            // 账号删除提醒弹窗
            .alert("账号状态通知", isPresented: $showCancelDeletionAlert) {
                Button("重新注册", role: .cancel) {
                    onCancelDeletion()
                }
                Button("退出", role: .destructive) {
                    onContinueDeletion()
                }
            } message: {
                Text("您的账号已被删除。如您希望继续使用此app，请点击\"重新注册\"按钮。")
            }
            
            // 好友申请限制弹窗
            .alert("今日好友申请已超过上限", isPresented: $showFriendRequestLimitAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(friendRequestLimitMessage)
            }
            
            // 拍一拍限制弹窗
            .alert("今日拍一拍已超过上限", isPresented: $showPatActionLimitAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(patActionLimitMessage)
            }
            .alert("消息访问限制", isPresented: $showMessageButtonLimitAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(messageButtonLimitMessage)
            }
    }
}
