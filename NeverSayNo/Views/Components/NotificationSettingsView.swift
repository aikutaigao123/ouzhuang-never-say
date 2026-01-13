//
//  NotificationSettingsView.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-09-30.
//

import SwiftUI
import UserNotifications

/// 通知设置界面
struct NotificationSettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var showingPermissionAlert = false
    @State private var showingClearAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // 通知状态部分
                Section(header: Text("通知状态")) {
                    HStack {
                        Image(systemName: notificationManager.isNotificationEnabled ? "bell.fill" : "bell.slash.fill")
                            .foregroundColor(notificationManager.isNotificationEnabled ? .green : .red)
                        
                        VStack(alignment: .leading) {
                            Text("推送通知")
                                .font(.headline)
                            Text(notificationManager.isNotificationEnabled ? "已启用" : "已禁用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !notificationManager.isNotificationEnabled {
                            Button("启用") {
                                requestNotificationPermission()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "app.badge")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("应用角标")
                                .font(.headline)
                            Text("未读消息数量: \(notificationManager.notificationCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if notificationManager.notificationCount > 0 {
                            Button("清除") {
                                showingClearAlert = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                // 通知类型部分
                Section(header: Text("通知类型")) {
                    NotificationTypeRow(
                        icon: "hand.tap.fill",
                        title: "拍一拍消息",
                        description: "收到拍一拍消息时推送通知",
                        isEnabled: true
                    )
                    
                    NotificationTypeRow(
                        icon: "person.badge.plus",
                        title: "好友申请",
                        description: "收到好友申请时推送通知",
                        isEnabled: true
                    )
                    
                    NotificationTypeRow(
                        icon: "checkmark.circle.fill",
                        title: "申请同意",
                        description: "好友申请被同意时推送通知",
                        isEnabled: true
                    )
                }
                
                // 设置说明部分
                Section(header: Text("设置说明")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 推送通知需要系统权限")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 即使应用在后台也能收到通知")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 通知会显示在锁屏和通知中心")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• 点击通知可直接跳转到相关界面")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // 测试通知部分
                Section(header: Text("测试通知")) {
                    Button(action: {
                        testPatMessageNotification()
                    }) {
                        HStack {
                            Image(systemName: "hand.tap.fill")
                                .foregroundColor(.orange)
                            Text("测试拍一拍通知")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: {
                        testFriendRequestNotification()
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .foregroundColor(.blue)
                            Text("测试好友申请通知")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("通知设置")
            .navigationBarTitleDisplayMode(.inline)
            .alert("需要通知权限", isPresented: $showingPermissionAlert) {
                Button("去设置") {
                    openAppSettings()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请在系统设置中允许通知权限，以便接收推送通知。")
            }
            .alert("清除所有通知", isPresented: $showingClearAlert) {
                Button("清除", role: .destructive) {
                    clearAllNotifications()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("这将清除所有未读通知和应用角标。")
            }
        }
    }
    
    /// 请求通知权限
    private func requestNotificationPermission() {
        notificationManager.requestNotificationPermission()
        
        // 延迟检查权限状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !notificationManager.isNotificationEnabled {
                showingPermissionAlert = true
            }
        }
    }
    
    /// 清除所有通知
    private func clearAllNotifications() {
        notificationManager.clearAllNotifications()
    }
    
    /// 打开应用设置
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    /// 测试拍一拍通知
    private func testPatMessageNotification() {
        notificationManager.sendPatMessageNotification(
            from: "测试用户",
            to: "你",
            messageId: UUID().uuidString
        )
    }
    
    /// 测试好友申请通知
    private func testFriendRequestNotification() {
        notificationManager.sendFriendRequestNotification(
            from: "测试用户",
            messageId: UUID().uuidString
        )
    }
}

/// 通知类型行组件
struct NotificationTypeRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .green : .gray)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NotificationSettingsView()
        .environmentObject(NotificationManager.shared)
}

