import SwiftUI

// 充值选项组件 - 网格卡片设计
struct RechargeOption: View {
    let title: String
    let description: String
    let price: String
    let diamonds: Int
    let isPopular: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // 热门标签
                if isPopular {
                    HStack {
                        Spacer()
                        Text("🔥 热门")
                            .font(UIStyleManager.Fonts.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(UIStyleManager.CornerRadius.extraLarge)
                    }
                }
                
                // 钻石数量 - 主要显示
                VStack(spacing: 4) {
                    Text("💎")
                        .font(UIStyleManager.Fonts.title)
                    
                    Text("\(diamonds)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isDisabled ? .gray : .purple)
                }
                
                // 价格
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .foregroundColor(.blue)
                } else {
                    Text(price)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isDisabled ? .gray : .blue)
                }
                
                // 标题和描述
                VStack(spacing: 4) {
                    Text(title)
                        .font(UIStyleManager.Fonts.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDisabled ? Color.gray.opacity(0.1) : (isLoading ? Color.gray.opacity(0.1) : Color.white))
                    .shadow(color: isDisabled ? .clear : (isPopular ? .orange.opacity(0.3) : .black.opacity(0.1)), radius: 8, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isDisabled ? Color.gray.opacity(0.3) : (isPopular ? Color.orange.opacity(0.5) : Color.clear),
                                lineWidth: 2
                            )
                    )
            )
            .opacity(isDisabled ? 0.5 : (isLoading ? 0.6 : 1.0))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading || isDisabled)
    }
}
