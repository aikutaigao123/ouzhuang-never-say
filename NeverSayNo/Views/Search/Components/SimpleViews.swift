import SwiftUI

struct SimpleViews {
    // 好友匹配状态标题
    static func FriendsMatchStatusTitle() -> some View {
        Text("🎉 所有好友匹配状态")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primary)
            .padding(.top)
    }
    
    // 空状态占位符
    static func EmptyStatePlaceholder() -> some View {
        VStack(spacing: 8) {
            Text("--")
                .font(.body)
                .foregroundColor(.gray)
                .fontWeight(.medium)
        }
        .padding(.top, 16)
    }
    
    // 加载状态指示器
    static func LoadingStateIndicator() -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: true)
            }

            VStack(spacing: 8) {
                Text("🎯 寻找随机记录中...")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)

                Text("正在为您匹配附近的用户")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
    
    // 成功消息提示
    static func SuccessMessageView(message: String) -> some View {
        Group {
            if !message.isEmpty {
                Text(message)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                    .foregroundColor(.green)
            }
        }
    }
}
