import SwiftUI
import AuthenticationServices

// ASAuthorizationControllerDelegate和ASAuthorizationControllerPresentationContextProviding
extension UserManager {
    // MARK: - ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // 注意：这个delegate方法中的登录完成回调被废弃，现在由LoginView中的SignInWithAppleButton直接处理
            loginWithApple(credential: appleIDCredential) {
                // 这里的completion为空，因为实际的导航由LoginView的onLoginSuccess处理
            }
        } else {
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                break
            case .failed:
                break
            case .invalidResponse:
                break
            case .notHandled:
                break
            case .unknown:
                break
            case .notInteractive:
                break
            case .matchedExcludedCredential:
                break
            case .credentialImport:
                break
            case .credentialExport:
                break
            default:
                break
            }
        } else {
            // 非 ASAuthorizationError 的错误，也视作处理完成
        }
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // 获取当前窗口
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        // 如果无法获取窗口，创建一个新的窗口作为后备方案
        // 这不应该发生，但如果发生，至少不会崩溃应用
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
    }
}
