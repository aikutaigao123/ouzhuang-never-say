//
//  IAPManager+PromoCode.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import UIKit
import StoreKit

// MARK: - 优惠代码兑换功能
extension IAPManager {
    
    // 显示 App Store 优惠代码兑换界面（iOS 14+）
    @available(iOS 14.0, *)
    @MainActor
    func presentPromoCodeRedeemSheet() async throws {
        // 获取主窗口场景（必须在主线程上调用）
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ??
            scenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        
        guard let windowScene = windowScene else {
            throw NSError(domain: "IAPManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取窗口场景"])
        }
        
        // 显示 App Store 优惠代码兑换界面
        try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
        // 注意：用户兑换成功后，交易会通过 SKPaymentTransactionObserver 的 updatedTransactions 方法处理
        // 与正常购买流程相同，会触发 .purchased 状态
    }
}

