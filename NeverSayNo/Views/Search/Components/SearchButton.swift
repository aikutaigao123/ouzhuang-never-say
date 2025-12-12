import SwiftUI

struct SearchButton: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var diamondManager: DiamondManager
    @Binding var isLoading: Bool
    @Binding var isUserBlacklisted: Bool
    let onSearch: () -> Void
    let onRecharge: () -> Void
    
    var body: some View {
        Button(action: handleButtonAction) {
            SearchButtonContent(
                isLoading: isLoading,
                isUserBlacklisted: isUserBlacklisted
            )
        }
        .disabled(isButtonCurrentlyDisabled)
        .background(buttonBackgroundColor)
        .cornerRadius(10)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    private var isButtonCurrentlyDisabled: Bool {
        isLoading || locationManager.location == nil || isUserBlacklisted
    }
    
    private var buttonBackgroundColor: Color {
        if isUserBlacklisted { return .gray }
        return (locationManager.location != nil && diamondManager.hasEnoughDiamonds(2)) ? .blue : .gray
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
    
    private func handleButtonAction() {
        for _ in Thread.callStackSymbols.prefix(8) {
        }
        
        // 🎯 修改：先检查本地余额，如果不足则从服务器重新验证
        let localHasEnough = diamondManager.checkDiamondsWithDebug(2)
        
        if localHasEnough {
            onSearch()
        } else {
            
            // 🎯 新增：从服务器重新验证钻石余额
            diamondManager.checkDiamondsWithServerConfirmation(2) { hasEnough in
                
                if hasEnough {
                    onSearch()
                } else {
                    onRecharge()
                }
            }
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
}
