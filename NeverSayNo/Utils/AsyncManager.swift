import Foundation
import SwiftUI

// 统一的异步操作管理器
class AsyncManager {
    
    // MARK: - 主线程操作
    static func performOnMain(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            action()
        }
    }
    
    static func performOnMainAfter(_ delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }
    
    // MARK: - 后台线程操作
    static func performOnBackground(_ action: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async {
            action()
        }
    }
    
    static func performOnUserInitiated(_ action: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            action()
        }
    }
    
    // MARK: - 组合操作
    static func performOnBackgroundThenMain(
        backgroundAction: @escaping () -> Void,
        mainAction: @escaping () -> Void
    ) {
        DispatchQueue.global(qos: .background).async {
            backgroundAction()
            DispatchQueue.main.async {
                mainAction()
            }
        }
    }
    
    // MARK: - 延迟操作
    static func performWithDelay(_ delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }
    
    // MARK: - 重复操作
    static func performRepeating(
        interval: TimeInterval,
        action: @escaping () -> Void
    ) -> Timer {
        return Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            action()
        }
    }
    
    // MARK: - 一次性延迟操作
    static func performOnceAfter(_ delay: TimeInterval, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }
    
    // MARK: - 网络请求包装
    static func performNetworkRequest<T>(
        request: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        Task {
            do {
                let result = try await request()
                await MainActor.run {
                    onSuccess(result)
                }
            } catch {
                await MainActor.run {
                    onError(error)
                }
            }
        }
    }
    
    // MARK: - 状态更新操作
    static func updateStateOnMain<T>(_ state: Binding<T>, value: T) {
        DispatchQueue.main.async {
            state.wrappedValue = value
        }
    }
    
    static func updateLoadingState(_ isLoading: Binding<Bool>, value: Bool) {
        DispatchQueue.main.async {
            isLoading.wrappedValue = value
        }
    }
    
    static func updateAlertState(
        message: Binding<String>,
        showAlert: Binding<Bool>,
        alertMessage: String
    ) {
        DispatchQueue.main.async {
            message.wrappedValue = alertMessage
            showAlert.wrappedValue = true
        }
    }
    
    // MARK: - 动画相关操作
    static func performWithAnimation(
        animation: Animation = .easeInOut(duration: 0.3),
        action: @escaping () -> Void
    ) {
        withAnimation(animation) {
            action()
        }
    }
    
    static func performWithAnimationAndDelay(
        delay: TimeInterval,
        animation: Animation = .easeInOut(duration: 0.3),
        action: @escaping () -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(animation) {
                action()
            }
        }
    }
    
    // MARK: - 焦点管理
    static func focusField(_ field: Binding<Bool>) {
        DispatchQueue.main.async {
            field.wrappedValue = true
        }
    }
    
    static func unfocusField(_ field: Binding<Bool>) {
        DispatchQueue.main.async {
            field.wrappedValue = false
        }
    }
    
    // MARK: - 成功消息显示
    static func showSuccessMessage(
        _ message: Binding<String>,
        _ showMessage: Binding<Bool>,
        duration: TimeInterval = 2.0
    ) {
        DispatchQueue.main.async {
            message.wrappedValue = "操作成功"
            showMessage.wrappedValue = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                showMessage.wrappedValue = false
            }
        }
    }
    
    static func showCopySuccessMessage(_ showCopySuccess: Binding<Bool>) {
        DispatchQueue.main.async {
            showCopySuccess.wrappedValue = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showCopySuccess.wrappedValue = false
            }
        }
    }
    
    // MARK: - 错误处理
    static func handleError(
        error: Error,
        alertMessage: Binding<String>,
        showAlert: Binding<Bool>
    ) {
        DispatchQueue.main.async {
            alertMessage.wrappedValue = error.localizedDescription
            showAlert.wrappedValue = true
        }
    }
    
    static func handleNetworkError(
        error: Error,
        alertMessage: Binding<String>,
        showAlert: Binding<Bool>
    ) {
        DispatchQueue.main.async {
            let message: String
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    message = "网络连接失败，请检查网络设置"
                case .timedOut:
                    message = "请求超时，请重试"
                case .cannotFindHost:
                    message = "无法找到服务器，请检查网络连接"
                default:
                    message = "网络错误：\(error.localizedDescription)"
                }
            } else {
                message = "网络错误：\(error.localizedDescription)"
            }
            
            alertMessage.wrappedValue = message
            showAlert.wrappedValue = true
        }
    }
    
    // MARK: - 数据加载操作
    static func loadDataWithLoading<T>(
        loadingState: Binding<Bool>,
        dataState: Binding<T?>,
        loadAction: @escaping () async throws -> T
    ) {
        DispatchQueue.main.async {
            loadingState.wrappedValue = true
        }
        
        Task {
            do {
                let result = try await loadAction()
                await MainActor.run {
                    dataState.wrappedValue = result
                    loadingState.wrappedValue = false
                }
            } catch {
                await MainActor.run {
                    loadingState.wrappedValue = false
                }
            }
        }
    }
    
    // MARK: - 表单验证
    static func validateForm(
        username: String,
        password: String,
        agreedToTerms: Bool,
        onValid: @escaping () -> Void,
        onInvalid: @escaping (String) -> Void
    ) {
        DispatchQueue.main.async {
            if username.isEmpty {
                onInvalid("请输入用户名")
                return
            }
            
            if password.isEmpty {
                onInvalid("请输入密码")
                return
            }
            
            if !agreedToTerms {
                onInvalid("请同意用户协议")
                return
            }
            
            onValid()
        }
    }
    
    // MARK: - 用户反馈
    static func provideUserFeedback(
        message: String,
        alertMessage: Binding<String>,
        showAlert: Binding<Bool>,
        duration: TimeInterval = 3.0
    ) {
        DispatchQueue.main.async {
            alertMessage.wrappedValue = message
            showAlert.wrappedValue = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                showAlert.wrappedValue = false
            }
        }
    }
}
