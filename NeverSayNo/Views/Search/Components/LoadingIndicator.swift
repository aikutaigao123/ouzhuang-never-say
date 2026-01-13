import SwiftUI

struct LoadingIndicator: View {
    let isLoading: Bool
    let title: String
    let subtitle: String
    
    init(isLoading: Bool, title: String = "🎯 寻找随机记录中...", subtitle: String = "正在为您匹配附近的用户") {
        self.isLoading = isLoading
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        if isLoading {
            VStack(spacing: 20) {
                // 加载动画
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
                }
                
                VStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 20)
        }
    }
}
