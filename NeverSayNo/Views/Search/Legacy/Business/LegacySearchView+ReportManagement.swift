//
//  LegacySearchView+ReportManagement.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation

// MARK: - Report Management Extension
extension LegacySearchView {
    
    /// 保存举报记录到本地
    func saveReportRecords() {
        if let data = try? JSONEncoder().encode(reportRecords) {
            UserDefaults.standard.set(data, forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser))
        }
    }
    
    /// 从本地加载举报记录
    func loadReportRecords() {
        reportRecords.removeAll()
        if let data = UserDefaults.standard.data(forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser)),
           let records = try? JSONDecoder().decode([ReportRecord].self, from: data) {
            reportRecords = records
        }
    }
    
    /// 添加举报记录
    func addReportRecord(reportedUserId: String, reportedUserName: String?, reportedUserEmail: String?, reportReason: String, reportedDeviceId: String? = nil, reportedUserLoginType: String? = nil) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let newReport = ReportRecord(
            reportedUserId: reportedUserId,
            reportedUserName: reportedUserName,
            reportedUserEmail: reportedUserEmail,
            reportReason: reportReason,
            reporterUserId: currentUser.userId,
            reporterUserName: currentUser.fullName
        )
        
        // 保存到本地
        reportRecords.append(newReport)
        saveReportRecords()
        
        // 获取举报者头像信息 - 基于用户类型设置默认头像
        // 统一使用随机或已分配的自定义emoji头像
        let reporterAvatar: String = {
            if let saved = UserDefaultsManager.getCustomAvatar(userId: currentUser.userId) {
                return saved
            }
            let rand = EmojiList.allEmojis.randomElement() ?? "🙂"
            UserDefaultsManager.setCustomAvatar(userId: currentUser.userId, emoji: rand)
            return rand
        }()
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        let tryFetchReportedAvatar = !reportedUserId.isEmpty
        if tryFetchReportedAvatar {
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: reportedUserId) { fetchedAvatar, _ in
                let loginType = reportedUserLoginType ?? "guest"
                let finalReportedAvatar = (fetchedAvatar?.isEmpty == false) ? fetchedAvatar! : UserAvatarUtils.defaultAvatar(for: loginType)

                let reportData: [String: Any] = [
                    "reported_user_id": reportedUserId, // 🎯 修改：使用 reportedUserId 而不是 reportedDeviceId
                    "reported_user_name": reportedUserName ?? "",
                    "reported_user_email": reportedUserEmail ?? "",
                    "reported_user_login_type": reportedUserLoginType ?? "unknown",
                    "reported_user_avatar": finalReportedAvatar,
                    "report_reason": reportReason,
                    "report_time": ISO8601DateFormatter().string(from: Date()),
                    "reporter_user_id": currentUser.userId,
                    "reporter_user_name": currentUser.fullName,
                    "reporter_user_avatar": reporterAvatar
                ]

                LeanCloudService.shared.uploadReportRecord(reportData: reportData) { success, message in
                    DispatchQueue.main.async {
                        if success {
                            // 举报记录上传成功
                        } else {
                            // 举报记录上传失败
                        }
                    }
                }
            }
        } else {
            // 无法查询真实头像时，使用通用头像占位
            let reportData: [String: Any] = [
                "reported_user_id": reportedUserId, // 🎯 修改：使用 reportedUserId 而不是 reportedDeviceId
                "reported_user_name": reportedUserName ?? "",
                "reported_user_email": reportedUserEmail ?? "",
                "reported_user_login_type": reportedUserLoginType ?? "unknown",
                "reported_user_avatar": UserAvatarUtils.defaultAvatar(for: reportedUserLoginType ?? "guest"),
                "report_reason": reportReason,
                "report_time": ISO8601DateFormatter().string(from: Date()),
                "reporter_user_id": currentUser.userId,
                "reporter_user_name": currentUser.fullName,
                "reporter_user_avatar": reporterAvatar
            ]

            LeanCloudService.shared.uploadReportRecord(reportData: reportData) { success, message in
                DispatchQueue.main.async {
                    if success {
                        // 举报记录上传成功
                    } else {
                        // 举报记录上传失败
                    }
                }
            }
        }
    }
    
    /// 检查是否已举报过该用户
    func hasReportedUser(_ userId: String) -> Bool {
        return ReportHelpers.hasReportedUser(userId, reportRecords: reportRecords)
    }
}

