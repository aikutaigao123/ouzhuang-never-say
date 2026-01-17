import Foundation

// MARK: - 版本比较工具
struct VersionHelpers {
    /// 获取当前 App 版本号
    /// - Returns: 版本号字符串，如 "1.92"
    static func getCurrentAppVersion() -> String? {
        guard let infoDict = Bundle.main.infoDictionary,
              let version = infoDict["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
    }
    
    /// 比较两个版本号
    /// - Parameters:
    ///   - version1: 第一个版本号，如 "1.92"
    ///   - version2: 第二个版本号，如 "2.0.0"
    /// - Returns: 比较结果：-1 表示 version1 < version2, 0 表示相等, 1 表示 version1 > version2
    static func compareVersions(_ version1: String, _ version2: String) -> Int {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxLength {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0
            
            if v1Value < v2Value {
                return -1
            } else if v1Value > v2Value {
                return 1
            }
        }
        
        return 0
    }
    
    /// 检查当前版本是否小于指定版本
    /// - Parameter targetVersion: 目标版本号
    /// - Returns: 如果当前版本小于目标版本返回 true
    static func isCurrentVersionLessThan(_ targetVersion: String) -> Bool {
        guard let currentVersion = getCurrentAppVersion() else {
            return false
        }
        return compareVersions(currentVersion, targetVersion) < 0
    }
    
    /// 检查当前版本是否等于指定版本
    /// - Parameter targetVersion: 目标版本号
    /// - Returns: 如果当前版本等于目标版本返回 true
    static func isCurrentVersionEqual(_ targetVersion: String) -> Bool {
        guard let currentVersion = getCurrentAppVersion() else {
            return false
        }
        return compareVersions(currentVersion, targetVersion) == 0
    }
    
    /// 检查当前版本是否大于指定版本
    /// - Parameter targetVersion: 目标版本号
    /// - Returns: 如果当前版本大于目标版本返回 true
    static func isCurrentVersionGreaterThan(_ targetVersion: String) -> Bool {
        guard let currentVersion = getCurrentAppVersion() else {
            return false
        }
        return compareVersions(currentVersion, targetVersion) > 0
    }
}
