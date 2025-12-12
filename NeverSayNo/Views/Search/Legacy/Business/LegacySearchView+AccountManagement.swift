//
//  LegacySearchView+AccountManagement.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import UIKit

// MARK: - Account Management Extensions
extension LegacySearchView {
    
    /// 检查待删除请求
    func checkPendingDeletionRequest() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        LeanCloudService.shared.checkPendingDeletionRequest(userId: currentUser.userId) { hasPendingDeletion, deletionDate in
            DispatchQueue.main.async {
                if hasPendingDeletion {
                    // 格式化删除日期显示
                    if let deletionDate = deletionDate {
                        let formatter = ISO8601DateFormatter()
                        if let date = formatter.date(from: deletionDate) {
                            let displayFormatter = DateFormatter()
                            displayFormatter.dateFormat = "yyyy年MM月dd日 HH:mm"
                            displayFormatter.timeZone = TimeZone.current
                            self.pendingDeletionDate = displayFormatter.string(from: date)
                        } else {
                            self.pendingDeletionDate = "7天后"
                        }
                    } else {
                        self.pendingDeletionDate = "7天后"
                    }
                    
                    // 显示取消删除确认对话框
                    self.showCancelDeletionAlert = true
                }
            }
        }
    }
    
    /// 取消账号删除请求
    func cancelAccountDeletion() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        LeanCloudService.shared.cancelAccountDeletion(userId: currentUser.userId) { success in
            DispatchQueue.main.async {
                if success {
                    // 可以显示成功提示
                } else {
                    // 可以显示错误提示
                }
            }
        }
    }
}
