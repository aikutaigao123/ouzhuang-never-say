import SwiftUI

struct PatMessageAlert: View {
    let isVisible: Bool
    let senderName: String
    let receiverName: String
    let onAppear: () -> Void
    let onDisappear: () -> Void
    
    var body: some View {
        if isVisible {
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("拍一拍提醒")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        // 🎯 修改：系统弹窗通知显示"谁拍了拍你"的格式
                        Text("\(senderName) 拍了拍你")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .zIndex(1001)
            .onAppear {
                onAppear()
            }
            .onDisappear {
                onDisappear()
            }
        }
    }
}
