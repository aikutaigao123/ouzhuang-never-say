import SwiftUI

// 🎯 新增：拍一拍按钮组件，支持1分钟内3次限制和自动恢复
struct PatButtonView: View {
    let friendId: String
    @Binding var patButtonPressed: [String: Bool]
    let isPatMessagesExpanded: Bool
    let setPatMessagesExpanded: (Bool) -> Void
    let onPat: () -> Void
    
    @State private var isButtonDisabled: Bool = false
    @State private var cooldownTimer: Timer?
    
    var body: some View {
        Button(action: {
            // 🎯 先更新按钮状态（检查是否在1分钟内超过3次）
            checkButtonState()
            
            // 🎯 如果按钮已被禁用，不执行任何操作
            if isButtonDisabled {
                return
            }
            
            // 检查是否已经在处理中
            if patButtonPressed[friendId] == true {
                return
            }
            
            // 设置按钮状态，防止重复点击
            patButtonPressed[friendId] = true
            
            // 延迟恢复按钮状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                patButtonPressed[friendId] = false
            }
            
            // 自动展开拍一拍消息界面（如果未展开则展开，已展开则保持）
            if !isPatMessagesExpanded {
                withAnimation(.easeInOut(duration: 0.3)) {
                    setPatMessagesExpanded(true)
                }
            }
            
            // 调用 onPat() 回调
            onPat()
            
            // 🎯 执行拍一拍后，再次检查按钮状态（因为记录是在 onPat() 回调中完成的）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let wasDisabled = isButtonDisabled
                checkButtonState()
                
                // 如果状态从启用变为禁用，启动定时器
                if !wasDisabled && isButtonDisabled {
                    startCooldownTimer()
                }
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "hand.tap")
                    .font(.caption)
                Text("拍一拍")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isButtonDisabled ? .gray : .white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isButtonDisabled ? Color.gray.opacity(0.5) :
                        (patButtonPressed[friendId] == true ? Color.blue.opacity(0.7) : Color.blue)
                    )
            )
            .onChange(of: isButtonDisabled) { oldValue, newValue in
            }
            .scaleEffect(patButtonPressed[friendId] == true ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: patButtonPressed[friendId])
            .animation(.easeInOut(duration: 0.15), value: isButtonDisabled)
        }
        .disabled(isButtonDisabled)
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // 🎯 检查初始状态
            checkButtonState()
            // 🎯 如果按钮已被禁用，启动定时器检查按钮恢复状态
            // 注意：checkButtonState() 中已经会启动定时器（如果状态变为禁用）
            if isButtonDisabled {
                startCooldownTimer()
            }
        }
        .onDisappear {
            // 🎯 清理定时器
            stopCooldownTimer()
        }
    }
    
    // 🎯 检查按钮状态
    private func checkButtonState() {
        let wasDisabled = isButtonDisabled
        isButtonDisabled = UserDefaultsManager.isPatButtonDisabled(targetUserId: friendId, maxCount: 3)
        
        // 🎯 如果状态从启用变为禁用，启动定时器
        if !wasDisabled && isButtonDisabled {
            startCooldownTimer()
        }
    }
    
    // 🎯 启动定时器检查按钮恢复状态
    private func startCooldownTimer() {
        // 先停止现有定时器
        stopCooldownTimer()
        
        // 如果按钮未被禁用，不需要启动定时器
        if !isButtonDisabled {
            return
        }
        
        // 创建定时器，每1秒检查一次（在主线程上运行）
        // 注意：在 SwiftUI 中，View 是 struct，不能使用 weak，但 Timer 会在 onDisappear 时被清理
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // 使用 DispatchQueue.main.async 确保在主线程更新状态
            DispatchQueue.main.async {
                let wasDisabled = isButtonDisabled
                checkButtonState()
                
                // 如果状态从禁用变为启用，停止定时器
                if wasDisabled && !isButtonDisabled {
                    stopCooldownTimer()
                }
            }
        }
        
        // 确保定时器在主线程的 RunLoop 上运行
        if let timer = cooldownTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // 🎯 停止定时器
    private func stopCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }
}

