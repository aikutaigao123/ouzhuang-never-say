import SwiftUI

struct CompassView: View {
    let bearing: Double
    @State private var animatedBearing: Double = 0
    @State private var compassScale: CGFloat = 0.8
    @State private var pulseOpacity: Double = 0.8
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = size / 2
            
            ZStack {
                // 脉冲圆圈效果（缩小一点，避免被裁剪）
                Circle()
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    .scaleEffect(1.05)
                    .opacity(pulseOpacity)
                
                // 外圆背景
                Circle()
                    .stroke(Color.purple.opacity(0.4), lineWidth: 3)
                    .background(Circle().fill(Color.purple.opacity(0.05)))
                    .scaleEffect(compassScale)
                
                // 内圆刻度线
                ForEach(0..<36) { index in
                    let angle = Double(index) * 10
                    let isMainDirection = index % 9 == 0 // 每90度主方向
                    let isMidDirection = index % 3 == 0 // 每30度中等方向
                    
                    Rectangle()
                        .fill(Color.purple.opacity(isMainDirection ? 0.8 : (isMidDirection ? 0.6 : 0.3)))
                        .frame(
                            width: isMainDirection ? 2 : (isMidDirection ? 1.5 : 1),
                            height: isMainDirection ? size * 0.15 : (isMidDirection ? size * 0.1 : size * 0.06)
                        )
                        .offset(y: -(radius - (isMainDirection ? size * 0.075 : (isMidDirection ? size * 0.05 : size * 0.03))))
                        .rotationEffect(.degrees(angle))
                        .scaleEffect(compassScale)
                }
                
                // 中心点
                Circle()
                    .fill(Color.purple)
                    .frame(width: size * 0.08, height: size * 0.08)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .scaleEffect(compassScale)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            // 出现动画
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                compassScale = 1.0
            }
            
            // 脉冲动画
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.2
            }
            
            // 初始化角度
            animatedBearing = bearing
        }
        .onChange(of: bearing) { _, newBearing in
            // 平滑旋转动画
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8, blendDuration: 0)) {
                animatedBearing = newBearing
            }
        }
    }
}
