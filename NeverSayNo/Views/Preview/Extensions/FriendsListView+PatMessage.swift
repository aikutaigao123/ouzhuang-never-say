//
//  FriendsListView+PatMessage.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import SwiftUI

// MARK: - Pat Message Extensions
extension FriendsListView {
    
    // 拍一拍反馈类型
    enum PatFeedbackType {
        case success
        case failure
    }
    
    // MARK: - Pat Message Methods
    
    // handlePatFriend 方法已移动到 FriendsListView+PatAction.swift
    
    /// 处理拍一拍消息刷新通知
    func handleRefreshPatMessages() {
        // 从 UserDefaults 重新加载拍一拍消息
        if let currentUser = userManager.currentUser {
            let loadedMessages = UserDefaultsManager.getPatMessages(userId: currentUser.id)
            
            // 更新 patMessages binding
            DispatchQueue.main.async {
                self.patMessages = loadedMessages
            }
        }
    }
    
    /// 拍一拍反馈 UI overlay
    @ViewBuilder
    var patFeedbackOverlay: some View {
        Group {
            if showPatFeedback {
                VStack {
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: patFeedbackType == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                        Text(patFeedbackMessage)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(patFeedbackType == .success ? Color.green : Color.red)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .padding(.bottom, 100) // 增加底部间距，避免被导航栏遮挡
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.2), value: showPatFeedback)
                    .allowsHitTesting(false)
                    .zIndex(1000) // 确保在最上层显示
                }
            }
        }
    }
    
    /// 拍一拍 Alert
    var patAlertView: some View {
        EmptyView()
            .alert("拍一拍", isPresented: $showPatAlert) {
                Button("确定") { }
            } message: {
                Text(patAlertMessage)
            }
    }
}

