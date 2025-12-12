import Foundation
import CoreLocation

struct BearingUtils {
    // 计算从当前位置到目标位置的方向角度（以正北方向为0度）
    static func calculateBearing(from currentLocation: CLLocation, to targetLatitude: Double, targetLongitude: Double) -> Double {
        let lat1 = currentLocation.coordinate.latitude * .pi / 180
        let lat2 = targetLatitude * .pi / 180
        let deltaLon = (targetLongitude - currentLocation.coordinate.longitude) * .pi / 180
        
        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearingRadians = atan2(x, y)
        let bearingDegrees = bearingRadians * 180 / .pi
        
        return bearingDegrees >= 0 ? bearingDegrees : bearingDegrees + 360
    }
    
    // 根据角度返回方向文字描述
    static func getDirectionText(_ bearing: Double) -> String {
        switch bearing {
        case 0..<22.5, 337.5...360:
            return "正北"
        case 22.5..<67.5:
            return "东北"
        case 67.5..<112.5:
            return "正东"
        case 112.5..<157.5:
            return "东南"
        case 157.5..<202.5:
            return "正南"
        case 202.5..<247.5:
            return "西南"
        case 247.5..<292.5:
            return "正西"
        case 292.5..<337.5:
            return "西北"
        default:
            return "未知"
        }
    }
}
