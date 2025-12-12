import SwiftUI

struct EditUserNameSheet: View {
    @ObservedObject var userManager: UserManager
    @Binding var isPresented: Bool
    @Binding var userNameFromServer: String?
    @State private var newUserName: String
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isTextFieldFocused: Bool
    
    init(userManager: UserManager, isPresented: Binding<Bool>, userNameFromServer: Binding<String?>) {
        self.userManager = userManager
        self._isPresented = isPresented
        self._userNameFromServer = userNameFromServer
        // 🎯 修改：使用与个人信息界面显示相同的逻辑 - 优先使用 userNameFromServer，否则使用 userManager.currentUser?.fullName
        let initialValue: String = {
            if let serverName = userNameFromServer.wrappedValue, !serverName.isEmpty {
                return serverName
            } else {
                return userManager.currentUser?.fullName ?? ""
            }
        }()
        _newUserName = State(initialValue: initialValue)
    }
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                    newUserName = ""
                }
            
            // 弹窗内容
            VStack(spacing: 20) {
                Text("修改用户名")
                    .font(.headline)
                    .padding(.top, 20)
                
                Text("请输入您想要的新用户名")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("请输入新的用户名", text: Binding(
                    get: { newUserName },
                    set: { newValue in
                        newUserName = StringHelpers.limitToBytes(newValue, maxBytes: 700)
                    }
                ))
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        saveUserName()
                    }
                    .padding(.horizontal)
                
                // 按钮
                HStack(spacing: 15) {
                    Button("取消", role: .cancel) {
                        isPresented = false
                        newUserName = ""
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(8)
                    
                    Button("确定") {
                        saveUserName()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(newUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(newUserName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(maxWidth: 300)
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 20)
        }
        .alert("用户名错误", isPresented: $showError) {
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
    
    private func saveUserName() {
        let trimmedName = newUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return
        }
        
        userManager.updateUserName(trimmedName) { success, error in
            if success {
                userNameFromServer = trimmedName
                
                // 清除用户名缓存
                if let userId = userManager.currentUser?.id {
                    LeanCloudService.shared.clearCacheForUser(userId)
                }
                
                newUserName = ""
                isPresented = false
            } else {
                if let error = error {
                    errorMessage = error
                    showError = true
                }
            }
        }
    }
}

