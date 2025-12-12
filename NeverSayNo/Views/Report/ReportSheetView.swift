import SwiftUI

// 举报弹窗视图
struct ReportSheetView: View {
    let userId: String
    let userName: String
    let loginType: String?
    let userEmail: String?
    let onReport: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = "不当内容"
    @State private var customReason = ""
    @State private var showCustomReason = false
    @State private var userNameFromServer: String? = nil // 从 UserNameRecord 表读取的用户名
    @State private var showReportLimitAlert = false // 🎯 新增：举报按钮限制提示
    @State private var reportLimitMessage = "" // 🎯 新增：举报按钮限制提示信息
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    
    // 优先使用 UserNameRecord 表中的用户名，否则使用传入的用户名
    private var displayedUserName: String {
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        return userName
    }
    
    // 举报原因字数限制
    private let maxCustomReasonLength = 50
    
    private let reportReasons = [
        "不当内容",
        "垃圾信息",
        "骚扰行为",
        "虚假信息",
        "其他"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 标题
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(UIStyleManager.Fonts.custom(size: 40))
                        .foregroundColor(.red)
                    
                    Text("举报用户")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        Text("您要举报的用户：")
                            .font(.body)
                            .foregroundColor(.gray)
                        ColorfulUserNameText(
                            userName: displayedUserName,
                            userId: userId,
                            loginType: loginType,
                            font: .body,
                            fontWeight: .regular,
                            lineLimit: 1,
                            truncationMode: .tail
                        )
                        .foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)
                .onAppear {
                    // 与用户头像界面一致：在onAppear时实时查询服务器用户名
                    loadUserNameFromServer()
                }
                .task {
                    // 🎯 新增：检查查询是否失败，如果失败则重试
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                    // 检查是否查询失败（userNameFromServer 为 nil）且未达到最大重试次数
                    let shouldRetry = userNameFromServer == nil && userNameRetryCount < 2
                    if shouldRetry {
                        retryLoadUserNameFromServer()
                    }
                }
                
                // 举报原因选择
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择举报原因")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(reportReasons, id: \.self) { reason in
                            Button(action: {
                                selectedReason = reason
                                showCustomReason = (reason == "其他")
                            }) {
                                HStack {
                                    Image(systemName: selectedReason == reason ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedReason == reason ? .blue : .gray)
                                        .font(.system(size: 16))
                                    
                                    Text(reason)
                                        .foregroundColor(.primary)
                                        .font(.body)
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selectedReason == reason ? Color.blue.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // 自定义原因输入
                if showCustomReason {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("请描述具体原因")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("\(customReason.count)/\(maxCustomReasonLength)")
                                .font(.caption)
                                .foregroundColor(customReason.count > maxCustomReasonLength ? .red : .gray)
                        }
                        
                        TextField("请输入举报原因...", text: Binding(
                            get: { customReason },
                            set: { newValue in
                                let limitedByBytes = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                                // 同时限制字符数（如果字符数限制更严格）
                                if limitedByBytes.count > maxCustomReasonLength {
                                    customReason = String(limitedByBytes.prefix(maxCustomReasonLength))
                                } else {
                                    customReason = limitedByBytes
                                }
                            }
                        ), axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                }
                
                Spacer()
                
                // 按钮区域
                VStack(spacing: 12) {
                    Button(action: {
                        // 🎯 新增：检查举报按钮点击次数限制
                        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
                            // 如果没有用户ID，直接执行举报
                            let finalReason = showCustomReason && !customReason.isEmpty ? customReason : selectedReason
                            onReport(finalReason)
                            return
                        }
                        
                        let (canClick, message) = UserDefaultsManager.canClickReportButton(userId: currentUserId)
                        if canClick {
                            // 记录点击
                            UserDefaultsManager.recordReportButtonClick(userId: currentUserId)
                            // 执行举报
                            let finalReason = showCustomReason && !customReason.isEmpty ? customReason : selectedReason
                            onReport(finalReason)
                        } else {
                            // 显示限制提示
                            reportLimitMessage = message
                            showReportLimitAlert = true
                        }
                    }) {
                        Text("确认举报")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .disabled(showCustomReason && (customReason.isEmpty || customReason.count > maxCustomReasonLength))
                    .alert("举报访问限制", isPresented: $showReportLimitAlert) {
                        Button("确定", role: .cancel) { }
                    } message: {
                        Text(reportLimitMessage)
                    }
                    
                    Button(action: {
                        dismiss()
                    }) {
                        Text("取消")
                            .font(.body)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .navigationTitle("举报用户")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取
    private func loadUserNameFromServer() {
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    self.userNameFromServer = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: userId)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: userId, userName: name)
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询用户名（最多重试2次）
    private func retryLoadUserNameFromServer() {
        guard userNameRetryCount < 2 else {
            return
        }
        userNameRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = userNameRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.userNameFromServer == nil {
                self.loadUserNameFromServer()
            }
        }
    }
}
