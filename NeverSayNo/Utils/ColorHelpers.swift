import SwiftUI
import Foundation

struct ColorHelpers {
    // 从十六进制字符串创建颜色
    static func colorFromHex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        return Color(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // 获取颜色的十六进制表示
    static func hexFromColor(_ color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb: Int = (Int)(red * 255) << 16 | (Int)(green * 255) << 8 | (Int)(blue * 255) << 0
        
        return String(format: "#%06x", rgb)
    }
    
    // 创建渐变色
    static func createGradient(from startColor: Color, to endColor: Color) -> LinearGradient {
        return LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // 创建径向渐变色
    static func createRadialGradient(from startColor: Color, to endColor: Color) -> RadialGradient {
        return RadialGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            center: .center,
            startRadius: 0,
            endRadius: 100
        )
    }
    
    // 调整颜色亮度
    static func adjustBrightness(_ color: Color, by factor: Double) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newBrightness = max(0, min(1, brightness + factor))
        
        return Color(
            hue: Double(hue),
            saturation: Double(saturation),
            brightness: Double(newBrightness)
        )
    }
    
    // 调整颜色饱和度
    static func adjustSaturation(_ color: Color, by factor: Double) -> Color {
        let uiColor = UIColor(color)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newSaturation = max(0, min(1, saturation + factor))
        
        return Color(
            hue: Double(hue),
            saturation: Double(newSaturation),
            brightness: Double(brightness)
        )
    }
    
    // 获取对比色
    static func getContrastColor(for color: Color) -> Color {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // 计算亮度
        let brightness = (red * 299 + green * 587 + blue * 114) / 1000
        
        // 根据亮度返回黑色或白色
        return brightness > 0.5 ? Color.black : Color.white
    }
    
    // 创建随机颜色
    static func randomColor() -> Color {
        let red = Double.random(in: 0...1)
        let green = Double.random(in: 0...1)
        let blue = Double.random(in: 0...1)
        
        return Color(red: red, green: green, blue: blue)
    }
    
    // 创建主题色
    static func createThemeColor() -> Color {
        return Color.blue
    }
    
    // 创建成功色
    static func createSuccessColor() -> Color {
        return Color.green
    }
    
    // 创建警告色
    static func createWarningColor() -> Color {
        return Color.orange
    }
    
    // 创建错误色
    static func createErrorColor() -> Color {
        return Color.red
    }
    
    // 创建信息色
    static func createInfoColor() -> Color {
        return Color.blue
    }
}
