import SwiftUI
import Foundation

struct MathHelpers {
    // 计算两点之间的距离
    static func distance(x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        let dx = x2 - x1
        let dy = y2 - y1
        return sqrt(dx * dx + dy * dy)
    }
    
    // 计算角度（弧度）
    static func angle(x1: Double, y1: Double, x2: Double, y2: Double) -> Double {
        return atan2(y2 - y1, x2 - x1)
    }
    
    // 将角度转换为弧度
    static func degreesToRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180
    }
    
    // 将弧度转换为角度
    static func radiansToDegrees(_ radians: Double) -> Double {
        return radians * 180 / .pi
    }
    
    // 计算平均值
    static func average(_ numbers: [Double]) -> Double {
        guard !numbers.isEmpty else { return 0 }
        return numbers.reduce(0, +) / Double(numbers.count)
    }
    
    // 计算中位数
    static func median(_ numbers: [Double]) -> Double {
        let sorted = numbers.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
        } else {
            return sorted[count / 2]
        }
    }
    
    // 计算标准差
    static func standardDeviation(_ numbers: [Double]) -> Double {
        guard numbers.count > 1 else { return 0 }
        
        let mean = average(numbers)
        let variance = numbers.map { pow($0 - mean, 2) }.reduce(0, +) / Double(numbers.count - 1)
        return sqrt(variance)
    }
    
    // 计算百分比
    static func percentage(_ value: Double, of total: Double) -> Double {
        guard total != 0 else { return 0 }
        return (value / total) * 100
    }
    
    // 计算增长率
    static func growthRate(from oldValue: Double, to newValue: Double) -> Double {
        guard oldValue != 0 else { return 0 }
        return ((newValue - oldValue) / oldValue) * 100
    }
    
    // 线性插值
    static func lerp(from start: Double, to end: Double, by factor: Double) -> Double {
        return start + (end - start) * factor
    }
    
    // 限制数值在指定范围内
    static func clamp(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.max(min, Swift.min(max, value))
    }
    
    // 将数值映射到新范围
    static func map(_ value: Double, fromMin: Double, fromMax: Double, toMin: Double, toMax: Double) -> Double {
        let fromRange = fromMax - fromMin
        let toRange = toMax - toMin
        return toMin + (value - fromMin) * toRange / fromRange
    }
    
    // 计算阶乘
    static func factorial(_ n: Int) -> Int {
        guard n >= 0 else { return 0 }
        if n <= 1 { return 1 }
        return n * factorial(n - 1)
    }
    
    // 计算组合数
    static func combination(n: Int, k: Int) -> Int {
        guard k <= n && k >= 0 else { return 0 }
        return factorial(n) / (factorial(k) * factorial(n - k))
    }
    
    // 计算排列数
    static func permutation(n: Int, k: Int) -> Int {
        guard k <= n && k >= 0 else { return 0 }
        return factorial(n) / factorial(n - k)
    }
    
    // 判断是否为质数
    static func isPrime(_ n: Int) -> Bool {
        guard n > 1 else { return false }
        guard n != 2 else { return true }
        guard n % 2 != 0 else { return false }
        
        for i in stride(from: 3, through: Int(sqrt(Double(n))), by: 2) {
            if n % i == 0 {
                return false
            }
        }
        return true
    }
    
    // 计算最大公约数
    static func gcd(_ a: Int, _ b: Int) -> Int {
        let remainder = a % b
        if remainder == 0 {
            return b
        } else {
            return gcd(b, remainder)
        }
    }
    
    // 计算最小公倍数
    static func lcm(_ a: Int, _ b: Int) -> Int {
        return abs(a * b) / gcd(a, b)
    }
    
    // 生成随机数
    static func random(min: Double = 0, max: Double = 1) -> Double {
        return Double.random(in: min...max)
    }
    
    // 生成随机整数
    static func randomInt(min: Int = 0, max: Int = 100) -> Int {
        return Int.random(in: min...max)
    }
    
    // 计算圆面积
    static func circleArea(radius: Double) -> Double {
        return .pi * radius * radius
    }
    
    // 计算圆周长
    static func circleCircumference(radius: Double) -> Double {
        return 2 * .pi * radius
    }
    
    // 计算矩形面积
    static func rectangleArea(width: Double, height: Double) -> Double {
        return width * height
    }
    
    // 计算矩形周长
    static func rectanglePerimeter(width: Double, height: Double) -> Double {
        return 2 * (width + height)
    }
}
