import SwiftUI

struct EditEmailSheet: View {
    @ObservedObject var userManager: UserManager
    @Binding var isPresented: Bool
    @Binding var emailFromServer: String?
    @State private var newEmail: String
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isTextFieldFocused: Bool
    
    init(userManager: UserManager, isPresented: Binding<Bool>, emailFromServer: Binding<String?>) {
        self.userManager = userManager
        self._isPresented = isPresented
        self._emailFromServer = emailFromServer
        _newEmail = State(initialValue: emailFromServer.wrappedValue ?? "")
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                    newEmail = ""
                }
            
            // 弹窗内容
            VStack(spacing: 20) {
                Text("修改邮箱")
                    .font(.headline)
                    .padding(.top, 20)
                
                Text("请输入您的新邮箱地址")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("请输入新的邮箱地址", text: Binding(
                    get: { newEmail },
                    set: { newValue in
                        newEmail = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                    }
                ))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        saveEmail()
                    }
                    .padding(.horizontal)
                
                // 按钮
                HStack(spacing: 15) {
                    Button("取消", role: .cancel) {
                        isPresented = false
                        newEmail = ""
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                    
                    Button("确定") {
                        saveEmail()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(newEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 300)
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 20)
        }
        .alert("邮箱错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // 延迟一点时间后自动聚焦，确保键盘能正常弹出
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveEmail() {
        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            return
        }
        
        guard isValidEmail(trimmedEmail) else {
            errorMessage = "请输入有效的邮箱地址"
            showError = true
            return
        }
        
        // 检查邮箱是否与默认邮箱格式匹配
        let defaultEmailPattern = "^[a-zA-Z0-9]{32}@[a-zA-Z0-9]{32}\\.com$"
        if trimmedEmail.range(of: defaultEmailPattern, options: .regularExpression) != nil {
            errorMessage = "不能使用默认邮箱格式"
            showError = true
            return
        }
        
        userManager.updateUserEmail(trimmedEmail) { success, error in
            if success {
                emailFromServer = trimmedEmail
                
                // 清除缓存
                if let userId = userManager.currentUser?.id {
                    LeanCloudService.shared.clearCacheForUser(userId)
                }
                
                newEmail = ""
                isPresented = false
            } else {
                errorMessage = error ?? "保存失败，请重试"
                showError = true
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        // 🎯 修改：使用统一的验证工具，支持emoji
        return ValidationUtils.isValidEmail(email)
    }
}

