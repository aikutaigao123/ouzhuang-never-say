// MARK: - 工具函数汇总文件
// 此文件用于统一导入所有工具函数，方便在其他文件中使用

// 注意：由于 Swift 模块系统的限制，无法使用 @_exported import 导入本地子模块
// 请直接导入需要使用的具体工具文件

// MARK: - 使用示例
/*
 在其他文件中使用时，请直接导入需要的工具文件：
 
 // 地理位置相关
 import Foundation
 import CoreLocation
 // 然后复制 DistanceUtils、BearingUtils、TimezoneUtils 中的函数到你的文件中
 
 // 时间相关
 import Foundation
 // 然后复制 TimestampUtils、TimeAgoUtils 中的函数到你的文件中
 
 // 用户相关
 import Foundation
 import SwiftUI
 // 然后复制 UserTypeUtils、UserAvatarUtils 中的函数到你的文件中
 
 // 验证相关
 import Foundation
 // 然后复制 ValidationUtils 中的函数到你的文件中
 
 // 存储相关
 import Foundation
 // 然后复制 StorageKeyUtils 中的函数到你的文件中
 
 // 内购相关
 import Foundation
 import StoreKit
 // 然后复制 IAPUtils 中的函数到你的文件中
 
 // 安全相关
 import Foundation
 import Security
 // 然后复制 KeychainUtils 中的函数到你的文件中
 */

// MARK: - 工具函数列表
/*
 可用的工具函数：
 
 Location/
 ├── DistanceUtils.calculateDistance(from:to:targetLongitude:)
 ├── DistanceUtils.formatDistance(_:)
 ├── BearingUtils.calculateBearing(from:to:targetLongitude:)
 ├── BearingUtils.getDirectionText(_:)
 ├── TimezoneUtils.calculateTimezoneFromLongitude(_:)
 ├── TimezoneUtils.isInChinaRange(_:_:)
 ├── TimezoneUtils.shouldShowTimezone(_:)
 └── TimezoneUtils.getTimezoneName(_:)
 
 Time/
 ├── TimestampUtils.formatTimestamp(_:tzID:)
 ├── TimestampUtils.formatDate(_:tzID:)
 ├── TimestampUtils.formatMatchTime(_:)
 ├── TimeAgoUtils.formatTimeAgo(from:)
 └── TimeAgoUtils.formatTimestamp(_:)
 
 User/
 ├── UserTypeUtils.getUserTypeText(_:)
 ├── UserTypeUtils.getLoginTypeFromUserId(_:)
 ├── UserTypeUtils.getUserTypeBackground(_:)
 ├── UserTypeUtils.getUserTypeColor(_:)
 ├── UserAvatarUtils.defaultAvatar(for:)
 ├── UserAvatarUtils.isSFSymbol(_:)
 └── UserAvatarUtils.getAvatarDisplayText(_:loginType:)
 
 Validation/
 ├── ValidationUtils.isValidEmail(_:)
 ├── ValidationUtils.isFormValid(username:password:confirmPassword:)
 ├── ValidationUtils.isValidUsername(_:)
 └── ValidationUtils.isValidPassword(_:)
 
 Storage/
 ├── StorageKeyUtils.getHistoryKey(for:)
 ├── StorageKeyUtils.getReportRecordsKey(for:)
 ├── StorageKeyUtils.getFavoriteRecordsKey(for:)
 └── StorageKeyUtils.getProcessedRecordsKey(for:)
 
 IAP/
 ├── IAPUtils.formatPrice(_:locale:)
 ├── IAPUtils.getDiamondsForProduct(_:)
 ├── IAPUtils.isValidProductId(_:)
 └── IAPUtils.getProductDescription(_:)
 
 Security/
 ├── KeychainUtils.savePasswordToKeychain(username:password:)
 ├── KeychainUtils.deletePasswordFromKeychain(username:)
 ├── KeychainUtils.getPasswordFromKeychain(username:)
 └── KeychainUtils.getErrorMessage(_:)
 */
