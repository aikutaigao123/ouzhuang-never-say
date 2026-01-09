import Foundation
import UIKit

struct StorageKeyUtils {
    // 获取历史记录键名
    static func getHistoryKey(for user: UserInfo?) -> String {
        guard let currentUser = user else {
            return "randomMatchHistory_guest"
        }
        
        switch currentUser.loginType {
        case .apple:
            // 🔧 修复：如果email为空，使用userId（与SearchButton一致）
            if let email = currentUser.email, !email.isEmpty {
                return "randomMatchHistory_apple_\(email)"
            } else {
                return "randomMatchHistory_apple_\(currentUser.id)"
            }
        // .internal case 已删除
        case .guest:
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
            let shortDeviceID = String(deviceID.prefix(8))
            return "randomMatchHistory_guest_\(shortDeviceID)"
        }
    }
    
    // 获取举报记录键名
    static func getReportRecordsKey(for user: UserInfo?) -> String {
        guard let currentUser = user else {
            return "reportRecords_guest"
        }
        
        switch currentUser.loginType {
        case .apple:
            // 🔧 修复：如果email为空，使用userId（与历史记录键一致）
            if let email = currentUser.email, !email.isEmpty {
                return "reportRecords_apple_\(email)"
            } else {
                return "reportRecords_apple_\(currentUser.id)"
            }
        // .internal case 已删除
        case .guest:
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
            let shortDeviceID = String(deviceID.prefix(8))
            return "reportRecords_guest_\(shortDeviceID)"
        }
    }
    
    // 获取喜欢记录键名
    static func getFavoriteRecordsKey(for user: UserInfo?) -> String {
        guard let currentUser = user else {
            return "favoriteRecords_guest"
        }
        
        switch currentUser.loginType {
        case .apple:
            return "favoriteRecords_apple_\(currentUser.id)"
        // .internal case 已删除
        case .guest:
            return "favoriteRecords_guest"
        }
    }
    
    // 获取已处理记录键名
    static func getProcessedRecordsKey(for user: UserInfo?) -> String {
        guard let currentUser = user else {
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
            let shortDeviceID = String(deviceID.prefix(8))
            return "processed_report_record_ids_\(shortDeviceID)"
        }
        
        switch currentUser.loginType {
        case .apple:
            // 🔧 修复：如果email为空，使用userId（与历史记录键一致）
            if let email = currentUser.email, !email.isEmpty {
                return "processed_report_record_ids_apple_\(email)"
            } else {
                return "processed_report_record_ids_apple_\(currentUser.id)"
            }
        // .internal case 已删除
        case .guest:
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
            let shortDeviceID = String(deviceID.prefix(8))
            return "processed_report_record_ids_guest_\(shortDeviceID)"
        }
    }
    
    // 获取点赞的LocationRecord记录键名
    static func getLikedLocationRecordsKey(for user: UserInfo?) -> String {
        guard let currentUser = user else {
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
            let shortDeviceID = String(deviceID.prefix(8))
            return "liked_location_records_guest_\(shortDeviceID)"
        }
        
        switch currentUser.loginType {
        case .apple:
            // 🔧 修复：如果email为空，使用userId（与历史记录键一致）
            if let email = currentUser.email, !email.isEmpty {
                return "liked_location_records_apple_\(email)"
            } else {
                return "liked_location_records_apple_\(currentUser.id)"
            }
        // .internal case 已删除
        case .guest:
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
            let shortDeviceID = String(deviceID.prefix(8))
            return "liked_location_records_guest_\(shortDeviceID)"
        }
    }
}
