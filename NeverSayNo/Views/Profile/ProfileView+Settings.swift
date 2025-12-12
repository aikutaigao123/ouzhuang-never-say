import SwiftUI

// 设置选项部分
extension ProfileView {
    // 游客模式特殊按钮
    var guestUserButtons: some View {
        Group {
            // 游客模式下暂无特殊按钮
        }
    }
    
    // 内部用户特殊按钮
    var internalUserButtons: some View {
        Group {
            // 内部账号登录模式下暂无特殊按钮
        }
    }
    
    // 历史按钮
    var historyButton: some View {
        Button("📚 历史记录") {
            // 🎯 新增：检查历史记录按钮点击次数限制
            guard let userId = userManager.currentUser?.id else {
                onShowHistory()
                return
            }
            
            let (canClick, message) = UserDefaultsManager.canClickHistoryButton(userId: userId)
            if canClick {
                // 记录点击
                UserDefaultsManager.recordHistoryButtonClick(userId: userId)
                // 打开历史记录
                onShowHistory()
            } else {
                // 显示限制提示
                historyLimitMessage = message
                showHistoryLimitAlert = true
            }
        }
        .font(.caption)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.green)
        .cornerRadius(10)
        .contentShape(Rectangle())
        .alert("历史记录访问限制", isPresented: $showHistoryLimitAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(historyLimitMessage)
        }
    }
    
    // 🎯 新增：黑名单按钮
    var blacklistButton: some View {
        Button("🚫 黑名单") {
            showBlacklistView = true
        }
        .font(.caption)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.purple)
        .cornerRadius(10)
        .contentShape(Rectangle())
    }
    
    // 法律和帮助按钮
    var legalHelpButtons: some View {
        Group {
            Button("📄 隐私政策") {
                showPrivacyPolicy = true
            }
            .font(.caption)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .contentShape(Rectangle())
            
            Button("📋 用户协议") {
                showTermsOfService = true
            }
            .font(.caption)
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(10)
            .contentShape(Rectangle())
        }
    }
    
    // 删除账号按钮
    var deleteAccountButton: some View {
        Button(action: {
            NSLog("🔴 [ProfileView] 删除账号按钮被点击")
            fflush(stdout)
            showDeleteAccountAlert = true
        }) {
            Text("删除账号")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .cornerRadius(15)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
    
    // 退出登录按钮
    var logoutButton: some View {
        Button(action: {
            showLogoutAlert = true
        }) {
            Text("退出登录")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(15)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
    
    // 设置按钮组合
    var settingsButtons: some View {
        VStack(spacing: 10) {
            guestUserButtons
            internalUserButtons
            historyButton
            blacklistButton // 🎯 新增：黑名单按钮（在历史记录按钮下方）
            legalHelpButtons
            deleteAccountButton
            logoutButton
        }
    }
    
}
