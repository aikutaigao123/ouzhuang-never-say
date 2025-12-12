import SwiftUI

struct CompassBackgroundView: View {
    let isTop3RankingUser: Bool // 🎯 新增：是否显示高手标识
    
    var body: some View {
        ZStack {
            if isTop3RankingUser {
                // 🎯 高手匹配卡片出现时，显示app图标背景
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 250, height: 250)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.purple.opacity(0.6), lineWidth: 3)
                            .frame(width: 250, height: 250)
                    )
            } else {
                // 默认：外圈
                Circle()
                    .stroke(Color.gray, lineWidth: 3)
                    .frame(width: 250, height: 250)
                
                // 内圈
                Circle()
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                    .frame(width: 200, height: 200)
            }
        }
    }
}
