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
    
    // 🎯 新增：清理本地缓存按钮
    var clearLocalCacheButton: some View {
        Button("🗑️ 清理本地缓存") {
            clearLocalCache()
        }
        .font(.caption)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.orange)
        .cornerRadius(10)
        .contentShape(Rectangle())
        .alert("✅ 清理完成", isPresented: Binding(
            get: { showClearCacheSuccessAlert },
            set: { showClearCacheSuccessAlert = $0 }
        )) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("本地缓存已清理，可以重新匹配之前匹配过的用户")
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
    
    // 🎯 新增：清理本地缓存功能
    private func clearLocalCache() {
        guard let userId = userManager.currentUser?.id else { return }
        
        // 1. 清除所有历史记录
        // 1.1 清除随机匹配历史记录
        let historyKey = StorageKeyUtils.getHistoryKey(for: userManager.currentUser)
        UserDefaults.standard.removeObject(forKey: historyKey)
        
        // 1.2 清除位置历史记录
        UserDefaults.standard.removeObject(forKey: "locationHistory_\(userId)")
        
        // 1.3 清除举报记录
        let reportKey = StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser)
        UserDefaults.standard.removeObject(forKey: reportKey)
        
        // 1.4 清除黑名单记录
        UserDefaults.standard.removeObject(forKey: "blacklistedUserIds_\(userId)")
        
        // 1.5 清除喜欢记录
        let favoriteKey = StorageKeyUtils.getFavoriteRecordsKey(for: userManager.currentUser)
        UserDefaults.standard.removeObject(forKey: favoriteKey)
        
        // 1.6 清除点赞记录
        let likeKey = "likeRecords_\(userId)"
        UserDefaults.standard.removeObject(forKey: likeKey)
        
        // 1.7 清除消息记录
        let messagesKey = "messages_\(userId)"
        UserDefaults.standard.removeObject(forKey: messagesKey)
        
        // 2. 清除排行榜按钮相关的所有缓存
        // 2.1 清除排行榜点击次数记录
        let rankingClicksKey = "ranking_clicks_\(userId)"
        UserDefaults.standard.removeObject(forKey: rankingClicksKey)
        
        // 2.2 清除排行榜按钮点击时间记录
        let rankingButtonClickTimeKey = "ranking_button_click_time_\(userId)"
        UserDefaults.standard.removeObject(forKey: rankingButtonClickTimeKey)
        
        // 2.3 清除推荐榜缓存
        UserDefaultsManager.setTop20Recommendations([], userId: userId)
        
        // 2.4 清除排行榜缓存
        UserDefaultsManager.setTop20RankingUserScores([], userId: userId)
        
        // 3. 清除用户操作缓存
        UserActionCacheManager.shared.clearUserCache(currentUserId: userId)
        
        // 发送通知，通知其他组件缓存已清除
        NotificationCenter.default.post(name: NSNotification.Name("HistoryCleared"), object: nil)
        
        // 显示清理成功的提示
        showClearCacheSuccessAlert = true
    }
    
}
