import Foundation

// 举报记录结构体
struct ReportRecord: Codable, Identifiable {
    let id: UUID
    let reportedUserId: String
    let reportedUserName: String?
    let reportedUserEmail: String?
    let reportReason: String
    let reportTime: Date
    let reporterUserId: String
    let reporterUserName: String?
    let status: String?
    
    init(reportedUserId: String, reportedUserName: String?, reportedUserEmail: String?, reportReason: String, reporterUserId: String, reporterUserName: String?, status: String? = nil) {
        self.id = UUID()
        self.reportedUserId = reportedUserId
        self.reportedUserName = reportedUserName
        self.reportedUserEmail = reportedUserEmail
        self.reportReason = reportReason
        self.reportTime = Date()
        self.reporterUserId = reporterUserId
        self.reporterUserName = reporterUserName
        self.status = status
    }
}
