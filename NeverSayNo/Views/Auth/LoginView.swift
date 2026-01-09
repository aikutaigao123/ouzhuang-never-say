import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @ObservedObject var userManager: UserManager
    @ObservedObject var locationManager: LocationManager
    var onLoginSuccess: () -> Void = {}
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var currentIcon = "🦋"
    @State private var timer: Timer?
    @State private var showLocationIcon = true
    @State private var animationPhase = 0
    @State private var currentEmojiIndex = 0
    
    var body: some View {
        VStack(spacing: 30) {
            if showLocationIcon {
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
            } else {
                Text(EmojiList.allEmojis[currentEmojiIndex])
                    .font(.system(size: 160))
            }
            Text("Never say No")
                .font(.system(size: 55))
            
            VStack(spacing: 15) {
                Button(action: {
                    // 🔧 清除登录导航标志，确保显示信息确认界面
                    let hadIsFromProfileTabLogout = UserDefaults.standard.bool(forKey: "isFromProfileTabLogout")
                    let hadIsFromProfileViewLogout = UserDefaults.standard.bool(forKey: "isFromProfileViewLogout")
                    if hadIsFromProfileTabLogout || hadIsFromProfileViewLogout {
                        UserDefaults.standard.set(false, forKey: "isFromProfileTabLogout")
                        UserDefaults.standard.set(false, forKey: "isFromProfileViewLogout")
                    }
                    
                    let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                    let shortDeviceID = String(deviceID.prefix(8))
                    let guestDisplayName = "游客\(shortDeviceID)"
                    
                    
                    // 异步登录完成后才调用onLoginSuccess
                    userManager.loginAsGuestWithInfo(displayName: guestDisplayName, email: "") {
                        // 登录成功回调
                        onLoginSuccess()
                    }
                }) {
                    HStack {
                        Image(systemName: "person.circle")
                        Text("游客登录")
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(UIStyleManager.Colors.primary)
                    .cornerRadius(UIStyleManager.CornerRadius.extraLarge)
                }
                
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleAppleSignInResult(result)
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(10)
                
                Text("💡 登录后可以自定义昵称")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 5)
            }
            .padding(UIStyleManager.Spacing.horizontalExtraLarge)
        }
        .padding()
        .alert("登录提示", isPresented: $showAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            startIconTimer()
        }
        .onDisappear {
            stopIconTimer()
        }
    }
    
    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        // 🔧 清除登录导航标志，确保显示信息确认界面
        let hadIsFromProfileTabLogout = UserDefaults.standard.bool(forKey: "isFromProfileTabLogout")
        let hadIsFromProfileViewLogout = UserDefaults.standard.bool(forKey: "isFromProfileViewLogout")
        if hadIsFromProfileTabLogout || hadIsFromProfileViewLogout {
            UserDefaults.standard.set(false, forKey: "isFromProfileTabLogout")
            UserDefaults.standard.set(false, forKey: "isFromProfileViewLogout")
        }
        
        switch result {
        case .success(let authorization):
            
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                // 等待Apple登录完成后再调用onLoginSuccess
                userManager.loginWithApple(credential: appleIDCredential) {
                    // 不显示alert，直接导航到信息确认界面
                    onLoginSuccess()
                }
            } else {
            }
        case .failure(let error):
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    return
                case .failed:
                    alertMessage = "登录失败，请重试"
                case .invalidResponse:
                    alertMessage = "登录响应无效"
                case .notHandled:
                    alertMessage = "登录未处理"
                case .unknown:
                    alertMessage = "未知错误"
                case .notInteractive:
                    alertMessage = "登录未交互"
                default:
                    alertMessage = "未知错误"
                }
            } else {
                alertMessage = "登录失败，请重试"
            }
            showAlert = true
        }
    }
    
    private func startIconTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showLocationIcon = false
            animationPhase = 1
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.33125, repeats: true) { _ in
                currentEmojiIndex = Int.random(in: 0..<EmojiList.allEmojis.count)
            }
        }
    }
    
    private func stopIconTimer() {
        timer?.invalidate()
        timer = nil
        showLocationIcon = true
        animationPhase = 0
        currentEmojiIndex = 0
    }
}
