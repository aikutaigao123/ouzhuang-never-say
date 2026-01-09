import SwiftUI
import Foundation

// 统一的举报记录管理服务
class SearchReportService: ObservableObject {
    @Published var reportRecords: [ReportRecord] = []
    @Published var isLoading = false
    
    private let userManager: UserManager
    
    init(userManager: UserManager) {
        self.userManager = userManager
    }
    
    // 从本地加载举报记录
    func loadLocalReportRecords() {
        reportRecords.removeAll()
        if let data = UserDefaults.standard.data(forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser)),
           let records = try? JSONDecoder().decode([ReportRecord].self, from: data) {
            reportRecords = records
        }
    }
    
    // 保存举报记录到本地
    func saveReportRecords() {
        if let data = try? JSONEncoder().encode(reportRecords) {
            UserDefaults.standard.set(data, forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser))
        }
    }
    
    // 添加举报记录
    func addReportRecord(
        reportedUserId: String, 
        reportedUserName: String?, 
        reportedUserEmail: String?, 
        reportReason: String, 
        reportedDeviceId: String? = nil, 
        reportedUserLoginType: String? = nil
    ) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let newReport = ReportRecord(
            reportedUserId: reportedUserId,
            reportedUserName: reportedUserName,
            reportedUserEmail: reportedUserEmail,
            reportReason: reportReason,
            reporterUserId: currentUser.id,
            reporterUserName: currentUser.fullName
        )
        
        // 保存到本地
        reportRecords.append(newReport)
        saveReportRecords()
        
        // 发送举报到服务器
        let reporterAvatar = "🙂"
        let reportData: [String: Any] = [
            "reported_user_id": reportedUserId, // 🎯 修改：使用 reportedUserId 而不是 reportedDeviceId
            "reported_user_name": reportedUserName ?? "",
            "reported_user_email": reportedUserEmail ?? "",
            "reported_user_login_type": reportedUserLoginType ?? "unknown",
            "reported_user_avatar": UserAvatarUtils.defaultAvatar(for: reportedUserLoginType ?? "guest"),
            "report_reason": reportReason,
            "report_time": ISO8601DateFormatter().string(from: Date()),
            "reporter_user_id": currentUser.id,
            "reporter_user_name": currentUser.fullName,
            "reporter_user_avatar": reporterAvatar
        ]
        
        LeanCloudService.shared.uploadReportRecord(reportData: reportData) { success, message in
            DispatchQueue.main.async {
                if !success {
                } else {
                }
            }
        }
    }
    
    // 检查是否已举报过该用户
    func hasReportedUser(_ userId: String) -> Bool {
        return reportRecords.contains { $0.reportedUserId == userId }
    }
}
