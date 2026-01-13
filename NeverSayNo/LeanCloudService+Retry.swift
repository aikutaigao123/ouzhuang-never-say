//
//  LeanCloudService+Retry.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  统一的重试机制扩展
//

import Foundation

// MARK: - 重试配置
struct LeanCloudRetryConfig {
    static let maxRetries: Int = 2  // 最多重试2次（与头像查询一致）
    static let firstRetryDelay: TimeInterval = 1.0 / 17.0  // 第一次重试延迟（约0.059秒）
    static let secondRetryDelay: TimeInterval = 0.5  // 第二次重试延迟
    static let initialCheckDelay: TimeInterval = 1.0 / 7.0  // 初始检查延迟（约0.143秒）
}

// MARK: - 重试机制扩展
extension LeanCloudService {
    
    /// 通用重试包装器 - 用于包装 LeanCloud 查询操作
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（默认2次）
    ///   - firstDelay: 第一次重试延迟（默认1/17秒）
    ///   - secondDelay: 第二次重试延迟（默认0.5秒）
    ///   - operation: 要执行的操作，接受一个 completion 回调
    ///   - completion: 完成回调，返回结果或错误
    func executeWithRetry<T>(
        maxRetries: Int = LeanCloudRetryConfig.maxRetries,
        firstDelay: TimeInterval = LeanCloudRetryConfig.firstRetryDelay,
        secondDelay: TimeInterval = LeanCloudRetryConfig.secondRetryDelay,
        operation: @escaping (@escaping (Result<T, Error>) -> Void) -> Void,
        completion: @escaping (T?, Error?) -> Void
    ) {
        var retryCount = 0
        
        func attempt() {
            operation { result in
                switch result {
                case .success(let value):
                    completion(value, nil)
                case .failure(let error):
                    if retryCount < maxRetries {
                        retryCount += 1
                        let delay = retryCount == 1 ? firstDelay : secondDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt()
                        }
                    } else {
                        completion(nil, error)
                    }
                }
            }
        }
        
        attempt()
    }
    
    /// 简化版重试包装器 - 用于返回可选值的查询操作
    /// - Parameters:
    ///   - maxRetries: 最大重试次数（默认2次）
    ///   - firstDelay: 第一次重试延迟（默认1/17秒）
    ///   - secondDelay: 第二次重试延迟（默认0.5秒）
    ///   - operation: 要执行的操作，接受一个 completion 回调，返回 (T?, String?)
    ///   - completion: 完成回调，返回结果或错误信息
    func executeWithRetrySimple<T>(
        maxRetries: Int = LeanCloudRetryConfig.maxRetries,
        firstDelay: TimeInterval = LeanCloudRetryConfig.firstRetryDelay,
        secondDelay: TimeInterval = LeanCloudRetryConfig.secondRetryDelay,
        operation: @escaping (@escaping (T?, String?) -> Void) -> Void,
        completion: @escaping (T?, String?) -> Void
    ) {
        var retryCount = 0
        
        func attempt() {
            operation { result, error in
                if let error = error, !error.isEmpty {
                    // 有错误，检查是否需要重试
                    if retryCount < maxRetries {
                        retryCount += 1
                        let delay = retryCount == 1 ? firstDelay : secondDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt()
                        }
                    } else {
                        // 达到最大重试次数，返回错误
                        completion(nil, error)
                    }
                } else if result == nil {
                    // 结果为 nil，检查是否需要重试（可能是临时问题）
                    if retryCount < maxRetries {
                        retryCount += 1
                        let delay = retryCount == 1 ? firstDelay : secondDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt()
                        }
                    } else {
                        // 达到最大重试次数，返回 nil
                        completion(nil, error ?? "查询失败")
                    }
                } else {
                    // 成功，返回结果
                    completion(result, nil)
                }
            }
        }
        
        attempt()
    }
}


