import Foundation

struct TimezoneUtils {
    // 根据经度计算时区
    static func calculateTimezoneFromLongitude(_ longitude: Double) -> String {
        let chinaLongitudeMin = 73.55
        let chinaLongitudeMax = 135.08
        
        if longitude >= chinaLongitudeMin && longitude <= chinaLongitudeMax {
            return "UTC+8"
        }
        
        let timezoneOffset = Int(round(longitude / 15.0))
        let clampedOffset = max(-12, min(14, timezoneOffset))
        
        if clampedOffset >= 0 {
            return "UTC+\(clampedOffset)"
        } else {
            return "UTC\(clampedOffset)"
        }
    }
    
    // 判断是否在中国经纬度范围内
    static func isInChinaRange(_ longitude: Double, _ latitude: Double) -> Bool {
        let chinaLongitudeMin = 73.55
        let chinaLongitudeMax = 135.08
        let chinaLatitudeMin = 3.97
        let chinaLatitudeMax = 53.55
        
        return longitude >= chinaLongitudeMin && longitude <= chinaLongitudeMax &&
               latitude >= chinaLatitudeMin && latitude <= chinaLatitudeMax
    }
    
    // 判断是否应该显示时区信息
    static func shouldShowTimezone(_ longitude: Double) -> Bool {
        let chinaLongitudeMin = 73.55
        let chinaLongitudeMax = 135.08
        
        if longitude >= chinaLongitudeMin && longitude <= chinaLongitudeMax {
            return false
        }
        
        let timezoneOffset = Int(round(longitude / 15.0))
        let clampedOffset = max(-12, min(14, timezoneOffset))
        return clampedOffset != 8
    }
    
    // 获取时区名称
    static func getTimezoneName(_ longitude: Double) -> String {
        let chinaLongitudeMin = 73.55
        let chinaLongitudeMax = 135.08
        
        if longitude >= chinaLongitudeMin && longitude <= chinaLongitudeMax {
            return "中国北京时间"
        }
        
        let timezoneOffset = Int(round(longitude / 15.0))
        let clampedOffset = max(-12, min(14, timezoneOffset))
        
        switch clampedOffset {
        case -12...(-8):
            return "太平洋时间"
        case -7...(-5):
            return "北美中部时间"
        case -4...(-2):
            return "大西洋时间"
        case -1...1:
            return "格林威治时间"
        case 2...4:
            return "欧洲中部时间"
        case 5...7:
            return "亚洲中部时间"
        case 8:
            return "中国北京时间"
        case 9:
            return "日本标准时间"
        case 10...11:
            return "澳大利亚东部时间"
        case 12...14:
            return "新西兰标准时间"
        default:
            return "未知时区"
        }
    }
}
