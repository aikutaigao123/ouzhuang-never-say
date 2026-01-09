import SwiftUI
import Foundation
import CoreLocation

struct LocationHelpers {
    // 格式化距离显示
    static func formatDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return String(format: "%.0f米", distance)
        } else {
            let km = distance / 1000
            return String(format: "%.1f公里", km)
        }
    }
    
    // 计算两点之间的距离
    static func calculateDistance(from: CLLocation, to: CLLocation) -> Double {
        return from.distance(from: to)
    }
    
    // 检查位置权限
    static func checkLocationPermission(_ manager: CLLocationManager) -> Bool {
        return manager.authorizationStatus == .authorizedWhenInUse || 
               manager.authorizationStatus == .authorizedAlways
    }
    
    // 获取位置状态描述
    static func getLocationStatusDescription(_ manager: CLLocationManager) -> String {
        switch manager.authorizationStatus {
        case .notDetermined:
            return "位置权限未确定"
        case .denied:
            return "位置权限被拒绝"
        case .restricted:
            return "位置权限受限"
        case .authorizedWhenInUse:
            return "位置权限已授权（使用时）"
        case .authorizedAlways:
            return "位置权限已授权（始终）"
        @unknown default:
            return "未知位置权限状态"
        }
    }
    
    // 验证坐标是否有效
    static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        return latitude >= -90 && latitude <= 90 && 
               longitude >= -180 && longitude <= 180
    }
    
    // 获取位置精度描述
    static func getLocationAccuracyDescription(_ accuracy: CLLocationAccuracy) -> String {
        if accuracy < 0 {
            return "无效位置"
        } else if accuracy <= 5 {
            return "高精度"
        } else if accuracy <= 10 {
            return "中等精度"
        } else if accuracy <= 50 {
            return "低精度"
        } else {
            return "很低精度"
        }
    }
}
