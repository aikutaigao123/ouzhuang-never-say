import SwiftUI

// 钻石信息显示部分
extension ProfileView {
    // 🎯 修改：钻石余额显示（优化：平滑过渡，避免闪烁）
    var diamondBalanceView: some View {
        HStack {
            // 🎯 优化：始终显示数字，使用动画过渡，避免加载状态闪烁
            Text("💎 \(diamondManager.diamonds)")
                .font(.title)
                .foregroundColor(.purple)
                .fontWeight(.bold)
                .id(diamondManager.diamonds) // 使用 id 触发平滑过渡
            
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: diamondManager.diamonds) // 平滑过渡
        .onAppear {
            // 🎯 修改：每次显示时后台刷新（不显示加载状态）
            diamondManager.diamondStore?.refreshBalanceInBackground()
        }
        .task {
            // 🔧 新增：检查钻石数是否为0，如果是则重试（类似用户名重试机制）
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查钻石数是否为0且未达到最大重试次数
            let shouldRetry = diamondManager.isShowingZeroDiamonds && diamondManager.diamondRetryCount < 2
            if shouldRetry {
                diamondManager.retryLoadDiamondsFromServer()
            }
        }
    }
    
    // 充值按钮
    var rechargeButton: some View {
        Button("充值") {
            showRechargeSheet = true
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.purple)
        .cornerRadius(10)
        .contentShape(Rectangle())
    }
    
    // 钻石信息卡片
    var diamondInfoCard: some View {
        VStack(spacing: 10) {
            HStack {
                diamondBalanceView
                rechargeButton
            }
            
            Text("成功匹配时消耗1颗钻石")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(15)
    }
}
