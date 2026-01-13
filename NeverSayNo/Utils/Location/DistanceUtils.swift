import Foundation
import CoreLocation

struct DistanceUtils {
    // 计算两个地理坐标之间的直线距离（使用Haversine公式）
    static func calculateDistance(from currentLocation: CLLocation, to targetLatitude: Double, targetLongitude: Double) -> Double {
        let targetLocation = CLLocation(latitude: targetLatitude, longitude: targetLongitude)
        let distance = currentLocation.distance(from: targetLocation)
        return distance
    }
    
    // 格式化距离显示 - 精确到厘米
    static func formatDistance(_ distanceInMeters: Double) -> String {
        // 检查距离是否为有效值
        guard distanceInMeters.isFinite && distanceInMeters >= 0 else {
            return "距离未知"
        }
        
        let distanceInCentimeters = distanceInMeters * 100
        
        if distanceInMeters < 1 {
            return String(format: "%.0fcm", distanceInCentimeters)
        } else if distanceInMeters < 1000 {
            let meters = Int(distanceInMeters)
            let centimeters = Int(distanceInCentimeters.truncatingRemainder(dividingBy: 100))
            return "\(meters)m\(centimeters)cm"
        } else {
            let kilometers = Int(distanceInMeters / 1000)
            let remainingMeters = distanceInMeters.truncatingRemainder(dividingBy: 1000)
            let meters = Int(remainingMeters)
            let centimeters = Int(distanceInCentimeters.truncatingRemainder(dividingBy: 100))
            return "\(kilometers)km\(meters)m\(centimeters)cm"
        }
    }
}
