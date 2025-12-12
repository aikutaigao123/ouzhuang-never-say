//
//  OptimizedSearchButton.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  基于Swift开发指南优化的寻找按钮
//

import SwiftUI
import LeanCloud

/**
 * 优化的寻找按钮组件
 * 基于Swift开发指南的最佳实践
 */
struct OptimizedSearchButton: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var diamondManager: DiamondManager
    @Binding var isLoading: Bool
    @Binding var isUserBlacklisted: Bool
    let onSearch: () -> Void
    let onRecharge: () -> Void
    
    // 错误处理状态
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        Button(action: handleButtonAction) {
            OptimizedSearchButtonContent(
                isLoading: isLoading,
                isUserBlacklisted: isUserBlacklisted,
                hasLocation: locationManager.location != nil,
                hasEnoughDiamonds: diamondManager.hasEnoughDiamonds(2)
            )
        }
        .disabled(isButtonDisabled)
        .background(buttonBackgroundColor)
        .cornerRadius(12)
        .scaleEffect(isLoading ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLoading)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .alert("操作失败", isPresented: $showErrorAlert) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - 计算属性
    
    private var isButtonDisabled: Bool {
        isLoading || locationManager.location == nil || isUserBlacklisted
    }
    
    private var buttonBackgroundColor: Color {
        if isUserBlacklisted { 
            return .gray.opacity(0.6) 
        }
        
        if locationManager.location == nil {
            return .orange.opacity(0.8)
        }
        
        return diamondManager.hasEnoughDiamonds(2) ? .blue : .red.opacity(0.8)
    }
    
    private var accessibilityLabel: String {
        if isLoading { return "寻找中，请稍候" }
        if isUserBlacklisted { return "已被禁用，无法使用" }
        if locationManager.location == nil { return "需要位置权限才能寻找" }
        if !diamondManager.hasEnoughDiamonds(2) { return "钻石不足，需要充值" }
        return "寻找按钮"
    }
    
    private var accessibilityHint: String {
        if isLoading { return "正在搜索附近用户" }
        if isUserBlacklisted { return "您的账户已被禁用" }
        if locationManager.location == nil { return "点击获取位置权限" }
        if !diamondManager.hasEnoughDiamonds(2) { return "点击进行充值" }
        return "点击开始寻找附近用户"
    }
    
    // MARK: - 按钮操作处理
    
    private func handleButtonAction() {
        // 记录按钮点击事件
        logButtonAction()
        
        // 检查各种状态
        guard !isLoading else {
            logWarning("按钮正在加载中，忽略点击")
            return
        }
        
        guard !isUserBlacklisted else {
            logWarning("用户已被拉黑，无法使用搜索功能")
            showError(message: "您的账户已被禁用，无法使用搜索功能")
            return
        }
        
        guard let _ = locationManager.location else {
            logWarning("位置信息不可用")
            showError(message: "需要位置权限才能使用搜索功能，请在设置中开启位置权限")
            return
        }
        
        // 检查钻石余额
        if diamondManager.checkDiamondsWithDebug(2) {
            logInfo("钻石余额充足，执行搜索操作")
            executeSearchWithErrorHandling()
        } else {
            logInfo("钻石余额不足，跳转到充值页面")
            onRecharge()
        }
        
    }
    
    // MARK: - 搜索执行
    
    private func executeSearchWithErrorHandling() {
        // 使用 LeanCloud 推荐的方式执行搜索
        // 这里可以添加 LeanCloud 相关的操作
        // 例如：记录搜索行为到 LeanCloud
        recordSearchActionToLeanCloud()
        
        // 执行搜索操作
        onSearch()
    }
    
    // MARK: - LeanCloud 集成
    
    private func recordSearchActionToLeanCloud() {
        
        // 使用 LeanCloud 记录搜索行为
        do {
            let searchRecord = LCObject(className: "SearchAction")
            
            try searchRecord.set("action", value: "search_button_click")
            try searchRecord.set("timestamp", value: Date())
            try searchRecord.set("hasLocation", value: locationManager.location != nil)
            try searchRecord.set("diamondBalance", value: diamondManager.diamonds)
            try searchRecord.set("userBlacklisted", value: isUserBlacklisted)
            try searchRecord.set("buttonDisabled", value: isButtonDisabled)
            
            _ = searchRecord.save { result in
                switch result {
                case .success:
                    logInfo("搜索行为记录成功")
                case .failure(let error):
                    logError("搜索行为记录失败: \(error.localizedDescription)")
                }
            }
        } catch {
            logError("搜索行为记录异常: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 错误处理
    
    private func showError(message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    // MARK: - 日志记录
    
    private func logButtonAction() {
        // 详细的按钮点击信息打印
        
        // 位置详细信息
        if locationManager.location != nil {
        } else {
        }
        
        // 权限状态
        
        // 服务器连接状态
        
        // 用户信息
        if diamondManager.currentUserId != nil {
        } else {
        }
        
        // 可访问性信息
        
    }
    
    // 获取按钮颜色描述
    private func getButtonColorDescription() -> String {
        if isUserBlacklisted {
            return "灰色(已被禁用)"
        } else if locationManager.location == nil {
            return "橙色(需要位置权限)"
        } else if diamondManager.hasEnoughDiamonds(2) {
            return "蓝色(可点击)"
        } else {
            return "红色(钻石不足)"
        }
    }
    
    // 获取位置权限状态描述
    private func getLocationPermissionStatus() -> String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "未确定"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限制"
        case .authorizedWhenInUse:
            return "使用时授权"
        case .authorizedAlways:
            return "始终授权"
        @unknown default:
            return "未知状态"
        }
    }
    
    private func logInfo(_ message: String) {
    }
    
    private func logWarning(_ message: String) {
    }
    
    private func logError(_ message: String) {
    }
}

// MARK: - 优化的按钮内容组件

struct OptimizedSearchButtonContent: View {
    let isLoading: Bool
    let isUserBlacklisted: Bool
    let hasLocation: Bool
    let hasEnoughDiamonds: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            statusIcon
            
            // 按钮文本
            Text(buttonText)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .frame(minWidth: 120)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if isLoading {
            ProgressView()
                .scaleEffect(0.8)
                .foregroundColor(.white)
        } else if isUserBlacklisted {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
        } else if !hasLocation {
            Image(systemName: "location.slash.fill")
                .foregroundColor(.white)
        } else if !hasEnoughDiamonds {
            Image(systemName: "diamond.fill")
                .foregroundColor(.white)
        } else {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white)
        }
    }
    
    private var buttonText: String {
        if isLoading { return "寻找中..." }
        if isUserBlacklisted { return "已被禁用" }
        if !hasLocation { return "需要位置" }
        if !hasEnoughDiamonds { return "钻石不足" }
        return "寻找"
    }
}

// MARK: - 预览

#Preview {
    VStack(spacing: 20) {
        // 正常状态
        OptimizedSearchButton(
            locationManager: LocationManager(),
            diamondManager: DiamondManager.shared,
            isLoading: .constant(false),
            isUserBlacklisted: .constant(false),
            onSearch: { },
            onRecharge: { }
        )
        
        // 加载状态
        OptimizedSearchButton(
            locationManager: LocationManager(),
            diamondManager: DiamondManager.shared,
            isLoading: .constant(true),
            isUserBlacklisted: .constant(false),
            onSearch: { },
            onRecharge: { }
        )
        
        // 被禁用状态
        OptimizedSearchButton(
            locationManager: LocationManager(),
            diamondManager: DiamondManager.shared,
            isLoading: .constant(false),
            isUserBlacklisted: .constant(true),
            onSearch: { },
            onRecharge: { }
        )
    }
    .padding()
}
