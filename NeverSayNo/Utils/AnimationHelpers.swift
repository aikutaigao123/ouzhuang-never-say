import SwiftUI
import Foundation

struct AnimationHelpers {
    // 创建淡入动画
    static func fadeIn(duration: Double = 0.3) -> Animation {
        return Animation.easeInOut(duration: duration)
    }
    
    // 创建淡出动画
    static func fadeOut(duration: Double = 0.3) -> Animation {
        return Animation.easeInOut(duration: duration)
    }
    
    // 创建缩放动画
    static func scale(from: CGFloat = 0.8, to: CGFloat = 1.0, duration: Double = 0.3) -> Animation {
        return Animation.easeInOut(duration: duration)
    }
    
    // 创建滑动动画
    static func slide(from: Edge = .trailing, duration: Double = 0.3) -> Animation {
        return Animation.easeInOut(duration: duration)
    }
    
    // 创建弹跳动画
    static func bounce(duration: Double = 0.6) -> Animation {
        return Animation.interpolatingSpring(stiffness: 300, damping: 20)
    }
    
    // 创建弹性动画
    static func spring(stiffness: Double = 100, damping: Double = 10) -> Animation {
        return Animation.interpolatingSpring(stiffness: stiffness, damping: damping)
    }
    
    // 创建旋转动画
    static func rotate(degrees: Double, duration: Double = 0.3) -> Animation {
        return Animation.easeInOut(duration: duration)
    }
    
    // 创建移动动画
    static func move(x: CGFloat = 0, y: CGFloat = 0, duration: Double = 0.3) -> Animation {
        return Animation.easeInOut(duration: duration)
    }
    
    // 创建组合动画
    static func combined(animations: [Animation]) -> Animation {
        return Animation.easeInOut(duration: 0.3)
    }
    
    // 创建延迟动画
    static func delayed(delay: Double, animation: Animation) -> Animation {
        return animation.delay(delay)
    }
    
    // 创建重复动画
    static func repeating(animation: Animation, count: Int = 1) -> Animation {
        return animation.repeatCount(count)
    }
    
    // 创建无限重复动画
    static func infinite(animation: Animation) -> Animation {
        return animation.repeatForever()
    }
    
    // 创建心跳动画
    static func heartbeat() -> Animation {
        return Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    }
    
    // 创建脉冲动画
    static func pulse() -> Animation {
        return Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    }
    
    // 创建摇摆动画
    static func shake() -> Animation {
        return Animation.easeInOut(duration: 0.1).repeatCount(3)
    }
    
    // 创建闪烁动画
    static func blink() -> Animation {
        return Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    }
    
    // 创建波浪动画
    static func wave() -> Animation {
        return Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    }
    
    // 创建加载动画
    static func loading() -> Animation {
        return Animation.linear(duration: 1.0).repeatForever(autoreverses: false)
    }
    
    // 创建成功动画
    static func success() -> Animation {
        return Animation.spring(response: 0.6, dampingFraction: 0.8)
    }
    
    // 创建错误动画
    static func error() -> Animation {
        return Animation.easeInOut(duration: 0.2).repeatCount(2, autoreverses: true)
    }
    
    // 创建警告动画
    static func warning() -> Animation {
        return Animation.easeInOut(duration: 0.3).repeatCount(3, autoreverses: true)
    }
}
