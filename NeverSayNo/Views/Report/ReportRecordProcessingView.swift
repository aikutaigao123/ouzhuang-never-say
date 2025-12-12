import SwiftUI

struct ReportRecordProcessingView: View {
    @ObservedObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var reportRecords: [ReportRecordUI] = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 标题
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("举报记录处理")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("查看和处理用户举报记录")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.top, 20)
                
                if isLoading {
                    Spacer()
                    ProgressView("加载中...")
                        .scaleEffect(1.2)
                    Spacer()
                } else if reportRecords.isEmpty {
                    Spacer()
                    VStack(spacing: 15) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("暂无举报记录")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("当前没有待处理的举报记录")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    // 举报记录列表
                    ScrollView {
                        LazyVStack(spacing: 15) {
                            ForEach(reportRecords, id: \.id) { record in
                                ReportRecordCard(record: record) { action in
                                    handleReportAction(record: record, action: action)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 底部按钮
                HStack(spacing: 15) {
                    Button("刷新") {
                        loadReportRecords()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                    .disabled(isLoading)
                    
                    Button("关闭") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("举报记录处理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("处理结果", isPresented: $showAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                loadReportRecords()
            }
        }
    }
    
    // 加载举报记录
    private func loadReportRecords() {
        isLoading = true
        
        // 清理本地已处理记录
        cleanupProcessedRecords()
        
        // 调用LeanCloud服务获取真实举报记录
        LeanCloudService.shared.fetchReportRecords { reportRecords, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.alertMessage = "获取举报记录失败: \(error)"
                    self.showAlert = true
                    return
                }
                
                if let reportRecords = reportRecords {
                    // 获取当前用户的已处理记录ID列表
                    let currentUserKey = StorageKeyUtils.getProcessedRecordsKey(for: userManager.currentUser)
                    let processedRecordIds = UserDefaultsManager.getStringArray(forKey: currentUserKey) ?? []
                    
                    // 过滤掉已处理的记录
                    let filteredRecords = reportRecords.filter { record in
                        !processedRecordIds.contains(record.id)
                    }
                    
                    // 转换为UI数据模型（带真实头像）
                    self.reportRecords = filteredRecords.map { record in
                        ReportRecordUI(
                            id: record.id,
                            reporterName: record.reporterUserName,
                            reportedName: record.reportedUserName,
                            reportedUserId: record.reportedUserId, // 🎯 新增：保存被举报用户ID
                            reportedUserLoginType: record.reportedUserLoginType,
                            reportedUserAvatar: record.reportedUserAvatar,
                            reason: record.reportReason,
                            description: "举报时间: \(TimestampUtils.formatMatchTime(record.reportTime))",
                            status: "待处理",
                            createdAt: record.reportTime
                        )
                    }
                } else {
                    self.reportRecords = []
                }
            }
        }
    }
    
    // 清理本地已处理记录（保留最近1000条）
    private func cleanupProcessedRecords() {
        let currentUserKey = StorageKeyUtils.getProcessedRecordsKey(for: userManager.currentUser)
        let processedRecordIds = UserDefaultsManager.getStringArray(forKey: currentUserKey) ?? []
        if processedRecordIds.count > 1000 {
            let recentRecords = Array(processedRecordIds.suffix(1000))
            UserDefaultsManager.setStringArray(recentRecords, forKey: currentUserKey)
        }
    }
    
    // 处理举报操作
    private func handleReportAction(record: ReportRecordUI, action: ReportAction) {
        let actionString: String
        switch action {
        case .reject:
            actionString = "rejected"
            alertMessage = "已驳回举报：\(record.reportedName)"
        case .warn:
            actionString = "warned"
            alertMessage = "已警告用户：\(record.reportedName)"
        case .ban:
            actionString = "banned"
            alertMessage = "已封禁用户：\(record.reportedName)"
        }
        
        // 调用LeanCloud服务处理举报记录
        LeanCloudService.shared.processReportRecord(recordId: record.id, action: actionString) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 🎯 新增：如果是封禁操作，将用户ID加入黑名单
                    if action == .ban {
                        LeanCloudService.shared.addUserToBlacklist(
                            userId: record.reportedUserId,
                            userName: record.reportedName,
                            loginType: record.reportedUserLoginType ?? "unknown"
                        ) { blacklistSuccess, blacklistError in
                            DispatchQueue.main.async {
                                if !blacklistSuccess {
                                    // 即使添加黑名单失败，也继续处理举报记录
                                } else {
                                }
                            }
                        }
                    }
                    
                    // 保存已处理的记录ID到当前用户的本地存储
                    let currentUserKey = StorageKeyUtils.getProcessedRecordsKey(for: userManager.currentUser)
                    var processedRecordIds = UserDefaultsManager.getStringArray(forKey: currentUserKey) ?? []
                    processedRecordIds.append(record.id)
                    UserDefaultsManager.setStringArray(processedRecordIds, forKey: currentUserKey)
                    
                    // 从当前列表中移除已处理的记录
                    self.reportRecords.removeAll { $0.id == record.id }
                    
                } else {
                    self.alertMessage = "处理失败: \(error ?? "未知错误")"
                }
                self.showAlert = true
            }
        }
    }
}
