import SwiftUI

// 统一的 UI 样式管理器
struct UIStyleManager {
    
    // MARK: - 间距常量
    struct Spacing {
        static let small: CGFloat = 5
        static let medium: CGFloat = 10
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 40
        
        static let horizontalSmall = EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        static let horizontalMedium = EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        static let horizontalLarge = EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        static let horizontalExtraLarge = EdgeInsets(top: 0, leading: 40, bottom: 0, trailing: 40)
        
        static let verticalSmall = EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        static let verticalMedium = EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        static let verticalLarge = EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0)
        static let verticalExtraLarge = EdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        
        static let standard = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        static let compact = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
    }
    
    // MARK: - 圆角常量
    struct CornerRadius {
        static let small: CGFloat = 2
        static let medium: CGFloat = 6
        static let large: CGFloat = 8
        static let extraLarge: CGFloat = 10
        static let huge: CGFloat = 15
        static let massive: CGFloat = 16
    }
    
    // MARK: - 颜色常量
    struct Colors {
        // 主色调
        static let primary = Color.blue
        static let secondary = Color.purple
        static let accent = Color.orange
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        
        // 灰度
        static let lightGray = Color.gray.opacity(0.1)
        static let mediumGray = Color.gray.opacity(0.2)
        static let darkGray = Color.gray.opacity(0.6)
        static let veryDarkGray = Color.gray.opacity(0.8)
        
        // 背景色
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color.gray.opacity(0.05)
        static let cardBackground = Color.white
        
        // 用户类型背景色
        static let appleBackground = Color.black.opacity(0.1)
        static let internalBackground = Color.purple.opacity(0.1)
        static let guestBackground = Color.blue.opacity(0.1)
        static let defaultBackground = Color.gray.opacity(0.1)
        
        // 状态背景色
        static let pendingBackground = Color.orange.opacity(0.2)
        static let processedBackground = Color.green.opacity(0.2)
        static let favoriteBackground = Color.red.opacity(0.1)
        static let reportBackground = Color.orange.opacity(0.1)
    }
    
    // MARK: - 字体常量
    struct Fonts {
        static let largeTitle = Font.largeTitle
        static let title = Font.title
        static let title2 = Font.title2
        static let title3 = Font.title3
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        static let body = Font.body
        static let callout = Font.callout
        static let caption = Font.caption
        static let caption2 = Font.caption2
        static let footnote = Font.footnote
        
        // 自定义字体
        static func custom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight)
        }
        
        static func customRounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
            return .system(size: size, weight: weight, design: .rounded)
        }
    }
    
    // MARK: - 阴影常量
    struct Shadows {
        static let small = Shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
        static let medium = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let large = Shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        static let extraLarge = Shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        static let purple = Shadow(color: .purple.opacity(0.3), radius: 2, x: 0, y: 2)
        static let orange = Shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - 动画常量
    struct Animations {
        static let quick = Animation.easeInOut(duration: 0.1)
        static let standard = Animation.easeInOut(duration: 0.2)
        static let smooth = Animation.easeInOut(duration: 0.3)
        static let slow = Animation.easeInOut(duration: 0.5)
        static let linear = Animation.linear(duration: 0.3)
        static let repeating = Animation.linear(duration: 1).repeatForever(autoreverses: false)
        static let pulsing = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    }
    
    // MARK: - 尺寸常量
    struct Sizes {
        static let avatarSmall: CGFloat = 40
        static let avatarMedium: CGFloat = 50
        static let avatarLarge: CGFloat = 60
        static let avatarExtraLarge: CGFloat = 80
        static let avatarHuge: CGFloat = 100
        
        static let buttonHeight: CGFloat = 50
        static let cardHeight: CGFloat = 120
        static let compassSize: CGFloat = 250
        static let compassInnerSize: CGFloat = 200
    }
    
    // MARK: - 缩放常量
    struct Scale {
        static let small: CGFloat = 0.6
        static let medium: CGFloat = 0.8
        static let large: CGFloat = 1.0
        static let extraLarge: CGFloat = 1.05
        static let huge: CGFloat = 1.2
        static let massive: CGFloat = 1.26
    }
}

// MARK: - 辅助结构体
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View 扩展
extension View {
    // 标准样式
    func standardStyle() -> some View {
        self
            .padding(UIStyleManager.Spacing.standard)
            .background(UIStyleManager.Colors.cardBackground)
            .cornerRadius(UIStyleManager.CornerRadius.large)
            .shadow(radius: UIStyleManager.Shadows.medium.radius)
    }
    
    // 卡片样式
    func cardStyle() -> some View {
        self
            .padding(UIStyleManager.Spacing.large)
            .background(UIStyleManager.Colors.cardBackground)
            .cornerRadius(UIStyleManager.CornerRadius.extraLarge)
            .shadow(radius: UIStyleManager.Shadows.large.radius)
    }
    
    // 按钮样式
    func buttonStyle(color: Color = UIStyleManager.Colors.primary) -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(height: UIStyleManager.Sizes.buttonHeight)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(UIStyleManager.CornerRadius.extraLarge)
            .font(UIStyleManager.Fonts.headline)
    }
    
    // 输入框样式
    func inputFieldStyle() -> some View {
        self
            .padding(UIStyleManager.Spacing.medium)
            .background(UIStyleManager.Colors.lightGray)
            .cornerRadius(UIStyleManager.CornerRadius.extraLarge)
    }
    
    // 标签样式
    func labelStyle(color: Color = UIStyleManager.Colors.secondary) -> some View {
        self
            .padding(UIStyleManager.Spacing.small)
            .background(color.opacity(0.1))
            .cornerRadius(UIStyleManager.CornerRadius.medium)
            .font(UIStyleManager.Fonts.caption)
    }
    
    // 头像样式
    func avatarStyle(size: CGFloat = UIStyleManager.Sizes.avatarLarge) -> some View {
        self
            .frame(width: size, height: size)
            .background(Circle().fill(UIStyleManager.Colors.lightGray))
            .clipShape(Circle())
    }
    
    // 标准动画
    func standardAnimation() -> some View {
        self.animation(UIStyleManager.Animations.smooth, value: true)
    }
    
    // 悬停效果
    func hoverEffect() -> some View {
        self
            .scaleEffect(1.0)
            .animation(UIStyleManager.Animations.standard, value: true)
    }
}
