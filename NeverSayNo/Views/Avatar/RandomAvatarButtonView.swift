import SwiftUI

// MARK: - 随机解锁头像按钮
struct RandomAvatarButtonView: View {
    @Binding var isLongPressing: Bool
    @Binding var comboCount: Int
    @Binding var maxComboCount: Int
    let onRandomize: () -> Void
    let onLongPressStart: () -> Void
    let onLongPressEnd: () -> Void
    let userManager: UserManager
    
    // 添加单次点击防抖状态
    @State private var isProcessingClick = false
    @State private var clickDebounceTimer: Timer?
    
    var body: some View {
        Button(action: {
            // 防抖处理：如果正在处理中，直接返回
            guard !isProcessingClick else { 
                return 
            }
            
            // 设置防抖标志
            isProcessingClick = true
            
            // 重置防抖定时器
            clickDebounceTimer?.invalidate()
            clickDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                isProcessingClick = false
            }
            
            onRandomize()
        }) {
            HStack {
                Image(systemName: "dice.fill")
                Text("随机解锁头像")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isLongPressing ? Color.orange : Color.purple)
            .cornerRadius(10)
            .scaleEffect(isLongPressing ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isLongPressing)
        }
        .padding(.horizontal, 20)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.8, maximumDistance: 50)
                .onEnded { _ in
                    // 长按手势触发时，确保不在点击处理中
                    if !isProcessingClick {
                        onLongPressStart()
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    // 长按开始，取消点击防抖
                    clickDebounceTimer?.invalidate()
                    isProcessingClick = false
                }
                .onEnded { _ in
                    // 只有在连击已经开始的情况下才停止
                    if isLongPressing {
                        onLongPressEnd()
                    }
                }
        )
    }
}

