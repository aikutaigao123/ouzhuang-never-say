import SwiftUI

// MARK: - Actions
extension AvatarZoomView {
    // 🎯 新增：累计统计（用于验证解锁数与钻石数是否一致）
    static var totalUnlockCount: Int = 0
    static var totalDiamondsSpent: Int = 0
    static var sessionStartDiamonds: Int = 0
    static var sessionStartServerDiamonds: Int = 0  // 🔧 新增：会话开始时的服务器真实钻石数（作为基准值）
    static var sessionStartAvatarCount: Int = 0
    
    // 🔧 新增：操作锁，确保连续快速解锁时本地钻石数不会变为负数
    private static let unlockOperationQueue = DispatchQueue(label: "com.neverSayNo.avatarUnlock.operation", qos: .userInitiated)
    private static var isUnlockOperationInProgress = false
    
    // 随机切换头像
    func randomizeAvatar() {
        // 检查钻石是否足够
        guard let diamondManager = userManager.diamondManager else {
            if !isLongPressing {
                alertMessage = "钻石管理器未初始化"
                showAlert = true
            }
            return
        }
        
        // 记录初始状态
        let initialDiamonds = diamondManager.diamonds
        let initialOwnedCount = diamondManager.ownedAvatars.count
        
        let initialStoreDiamonds = diamondManager.diamondStore?.balance.amount ?? -1
        
        if initialDiamonds != initialStoreDiamonds && initialStoreDiamonds >= 0 {
        }
        
        // 🔍 调试：检查初始钻石数是否为负数
        if initialDiamonds < 0 {
        }
        
        // 🎯 新增：记录会话开始时的状态（第一次解锁时）
        if AvatarZoomView.totalUnlockCount == 0 {
            AvatarZoomView.sessionStartDiamonds = initialDiamonds
            AvatarZoomView.sessionStartAvatarCount = initialOwnedCount
            
            
            // 🔧 按照开发指南：从服务器获取真实钻石数作为基准值
            if let diamondStore = diamondManager.diamondStore {
                let beforeRefreshUnlockCount = AvatarZoomView.totalUnlockCount
                
                diamondStore.refreshBalanceFromServer { result in
                    let afterRefreshUnlockCount = AvatarZoomView.totalUnlockCount
                    let afterRefreshDiamondsSpent = AvatarZoomView.totalDiamondsSpent
                    let unlockCountDuringRefresh = afterRefreshUnlockCount - beforeRefreshUnlockCount
                    
                    
                    switch result {
                    case .success(let serverDiamonds):
                        
                        // ⚠️ 关键检查：如果刷新期间已经有解锁操作，说明服务器值已经不是真正的起始值
                        if unlockCountDuringRefresh > 0 {
                            // 🔧 修复：计算真正的起始值（服务器当前值 + 已消耗的值）
                            let trueStartDiamonds = serverDiamonds + afterRefreshDiamondsSpent
                            AvatarZoomView.sessionStartServerDiamonds = trueStartDiamonds
                        } else {
                            // 刷新期间没有解锁操作，服务器值就是真正的起始值
                            AvatarZoomView.sessionStartServerDiamonds = serverDiamonds
                        }
                        
                    case .failure(_):
                        // 如果获取服务器值失败，使用本地值作为备选
                        AvatarZoomView.sessionStartServerDiamonds = initialDiamonds
                    }
                }
            } else {
                AvatarZoomView.sessionStartServerDiamonds = initialDiamonds
            }
        }
        
        // 🔍 计算期望的当前钻石数（基于累计消耗）
        // 🔧 按照开发指南：如果已有服务器基准值，优先使用服务器值计算期望值
        let baseDiamonds = AvatarZoomView.sessionStartServerDiamonds > 0 ? AvatarZoomView.sessionStartServerDiamonds : AvatarZoomView.sessionStartDiamonds
        let expectedCurrentDiamonds = baseDiamonds - AvatarZoomView.totalDiamondsSpent
        let diamondsDifference = initialDiamonds - expectedCurrentDiamonds
        
        if AvatarZoomView.sessionStartServerDiamonds > 0 {
        } else {
        }
        
        // ⚠️ 如果实际钻石数与期望值不一致，说明可能有并发问题
        if diamondsDifference != 0 {
        }
        
        // 🔧 修复：钻石数小于5时，不允许随机解锁头像
        if initialDiamonds < 5 {
            if !isLongPressing {
                alertMessage = "钻石不足，需要5颗钻石才能随机解锁头像"
                showAlert = true
            }
            // 连击模式下停止连击
            if isLongPressing {
                forceStopLongPressCombo()
            }
            return
        }
        
        // 获取当前拥有的头像列表
        // 🔧 统一使用 objectId 作为 userId
        guard let userId = userManager.currentUser?.id else {
            return
        }
        let ownedAvatars = Set(userManager.diamondManager?.ownedAvatars ?? [])
        
        // 找出未拥有的emoji
        let unownedEmojis = Set(EmojiList.allEmojis).subtracting(ownedAvatars)
        
        // 如果所有emoji都已拥有，提示用户并返回，不扣除钻石
        if unownedEmojis.isEmpty {
            if !isLongPressing {
                alertMessage = "恭喜！您已拥有所有头像，双头像模式以及彩色用户名模式已解锁！"
                showAlert = true
                
                // 🎯 新增：更新 UserNameRecord 中的双头像解锁状态
                if let currentUser = userManager.currentUser {
                    let loginTypeString = currentUser.loginType == .apple ? "apple" : "guest"
                    LeanCloudService.shared.updateDualAvatarUnlockedStatus(
                        objectId: currentUser.id,
                        loginType: loginTypeString,
                        isUnlocked: true
                    ) { success in
                        if success {
                            // 更新成功
                        } else {
                            // 更新失败，但不影响用户体验，静默处理
                        }
                    }
                }
            }
            return
        }
        
        // 🎯 修改：检查钻石余额（与寻找按钮逻辑一致）
        // ⚠️ 关键修复：直接从 DiamondStore 读取，避免并发刷新导致的读取错误
        _ = diamondManager.diamondStore?.balance.amount ?? diamondManager.diamonds
        // 使用 DiamondStore 的值（更准确）
        let localHasEnough = diamondManager.checkDiamondsWithDebug(5)
        
        // 再次从 DiamondStore 读取
        let checkAfterDiamondsFromStore = diamondManager.diamondStore?.balance.amount ?? diamondManager.diamonds
        let checkAfterDiamondsFromManager = diamondManager.diamonds
        
        // 如果 Store 和 Manager 不一致，警告
        if checkAfterDiamondsFromStore != checkAfterDiamondsFromManager {
        }
        
        if !localHasEnough {
            // 本地余额不足，从服务器重新验证
                diamondManager.checkDiamondsWithServerConfirmation(5) { hasEnough in
                DispatchQueue.main.async {
                    if hasEnough {
                        // 服务器验证充足，继续执行解锁流程
                        self.executeAvatarUnlock(diamondManager: diamondManager, userId: userId, ownedAvatars: ownedAvatars, unownedEmojis: unownedEmojis, initialDiamonds: initialDiamonds)
                    } else {
                        // 服务器验证不足，提示用户
                        if !self.isLongPressing {
                            self.alertMessage = "钻石不足，需要5颗钻石才能随机解锁头像"
                            self.showAlert = true
                        }
                        // 连击模式下停止连击
                        if self.isLongPressing {
                            self.forceStopLongPressCombo()
                        }
                    }
                }
            }
            return
        }
        
        // 本地余额充足，直接执行解锁流程
        executeAvatarUnlock(diamondManager: diamondManager, userId: userId, ownedAvatars: ownedAvatars, unownedEmojis: unownedEmojis, initialDiamonds: initialDiamonds)
    }
    
    // 🎯 新增：执行头像解锁流程（提取公共逻辑）
    private func executeAvatarUnlock(
        diamondManager: DiamondManager,
        userId: String,
        ownedAvatars: Set<String>,
        unownedEmojis: Set<String>,
        initialDiamonds: Int
    ) {
        
        // 🔧 修复：再次检查钻石数，确保至少为5
        // ⚠️ 关键修复：直接从 DiamondStore 读取，避免并发刷新导致的读取错误
        let currentDiamondsFromStore = diamondManager.diamondStore?.balance.amount ?? diamondManager.diamonds
        let currentDiamondsFromManager = diamondManager.diamonds
        let currentDiamonds = currentDiamondsFromStore
        let beforeUnlockAvatarCount = ownedAvatars.count
        
        
        // 🔍 调试：检查当前钻石数是否为负数
        if currentDiamonds < 0 {
        }
        
        
        // 如果 Store 和 Manager 不一致，警告
        if currentDiamondsFromStore != currentDiamondsFromManager {
        }
        
        // 🔧 新增：操作锁 + 本地检查，确保连续快速解锁时钻石数不会变为负数
        var shouldProceed = false
        var finalDiamondsAfterCheck = currentDiamonds
        
        AvatarZoomView.unlockOperationQueue.sync {
            // 在操作锁内重新读取最新钻石数
            let lockedDiamondsFromStore = diamondManager.diamondStore?.balance.amount ?? diamondManager.diamonds
            finalDiamondsAfterCheck = lockedDiamondsFromStore
            
            // 关键检查：确保本地钻石数 >= 5
            if finalDiamondsAfterCheck < 5 {
                shouldProceed = false
                return
            }
            
            // 检查扣除后是否会导致负数
            let diamondsAfterDeduct = finalDiamondsAfterCheck - 5
            if diamondsAfterDeduct < 0 {
                shouldProceed = false
                return
            }
            
            // 通过检查，标记为进行中
            AvatarZoomView.isUnlockOperationInProgress = true
            shouldProceed = true
        }
        
        // 如果检查失败，停止操作
        guard shouldProceed else {
            if !self.isLongPressing {
                DispatchQueue.main.async {
                    self.alertMessage = "钻石不足，需要5颗钻石才能随机解锁头像"
                    self.showAlert = true
                }
            }
            // 连击模式下停止连击
            if self.isLongPressing {
                DispatchQueue.main.async {
                    self.forceStopLongPressCombo()
                }
            }
            return
        }
        
        
        // 🔧 修改：在连续解锁模式下，只更新本地，延迟服务器同步；单点模式立即同步
        if self.isLongPressing {
            // 连续解锁模式：只更新本地，延迟同步服务器
            if let diamondStore = diamondManager.diamondStore {
                let localSuccess = diamondStore.spendDiamondsLocally(5, reason: "用户操作")
                
                // 释放操作锁
                AvatarZoomView.unlockOperationQueue.async {
                    AvatarZoomView.isUnlockOperationInProgress = false
                }
                
                if localSuccess {
                    let afterSpendDiamonds = diamondStore.balance.amount
                    // 继续执行解锁逻辑（不等待服务器同步）
                    self.proceedWithUnlockAfterSpend(
                        diamondManager: diamondManager,
                        userId: userId,
                        ownedAvatars: ownedAvatars,
                        unownedEmojis: unownedEmojis,
                        currentDiamonds: afterSpendDiamonds,
                        beforeUnlockAvatarCount: beforeUnlockAvatarCount
                    )
                } else {
                    DispatchQueue.main.async {
                        self.forceStopLongPressCombo()
                    }
                }
            } else {
                // DiamondStore 不存在，回退到正常流程
                AvatarZoomView.unlockOperationQueue.async {
                    AvatarZoomView.isUnlockOperationInProgress = false
                }
                self.proceedWithNormalSpend(diamondManager: diamondManager, userId: userId, ownedAvatars: ownedAvatars, unownedEmojis: unownedEmojis, beforeUnlockAvatarCount: beforeUnlockAvatarCount, currentDiamonds: finalDiamondsAfterCheck)
            }
        } else {
            // 单点模式：正常流程，立即同步服务器
            self.proceedWithNormalSpend(diamondManager: diamondManager, userId: userId, ownedAvatars: ownedAvatars, unownedEmojis: unownedEmojis, beforeUnlockAvatarCount: beforeUnlockAvatarCount, currentDiamonds: finalDiamondsAfterCheck)
        }
    }
    
    // 🔧 新增：正常扣除流程（单点模式）
    private func proceedWithNormalSpend(
        diamondManager: DiamondManager,
        userId: String,
        ownedAvatars: Set<String>,
        unownedEmojis: Set<String>,
        beforeUnlockAvatarCount: Int,
        currentDiamonds: Int
    ) {
        
        diamondManager.spendDiamonds(5) { success in
            
            // 释放操作锁
            AvatarZoomView.unlockOperationQueue.async {
                AvatarZoomView.isUnlockOperationInProgress = false
            }
            
            if success {
                let afterSpendDiamonds = diamondManager.diamondStore?.balance.amount ?? diamondManager.diamonds
                self.proceedWithUnlockAfterSpend(
                    diamondManager: diamondManager,
                    userId: userId,
                    ownedAvatars: ownedAvatars,
                    unownedEmojis: unownedEmojis,
                    currentDiamonds: afterSpendDiamonds,
                    beforeUnlockAvatarCount: beforeUnlockAvatarCount
                )
            } else {
                if !self.isLongPressing {
                    DispatchQueue.main.async {
                        self.alertMessage = "钻石扣除失败，请稍后重试"
                        self.showAlert = true
                    }
                }
                if self.isLongPressing {
                    DispatchQueue.main.async {
                        self.forceStopLongPressCombo()
                    }
                }
            }
        }
    }
    
    // 🔧 新增：执行解锁逻辑（提取公共部分，在扣除成功后调用）
    private func proceedWithUnlockAfterSpend(
        diamondManager: DiamondManager,
        userId: String,
        ownedAvatars: Set<String>,
        unownedEmojis: Set<String>,
        currentDiamonds: Int,
        beforeUnlockAvatarCount: Int
    ) {
        
        // 🔍 记录回调时的状态
        let callbackDiamondsFromManager = diamondManager.diamonds
        let callbackDiamondsFromStore = diamondManager.diamondStore?.balance.amount ?? -1
        
        
        // ⚠️ 关键：如果 DiamondManager 和 DiamondStore 的值不一致，说明同步延迟
        if callbackDiamondsFromManager != callbackDiamondsFromStore && callbackDiamondsFromStore != -1 {
        }
        
        // 从未拥有的emoji中随机选择一个
        let randomEmoji = unownedEmojis.randomElement() ?? "😀"
        
        // 添加到拥有的头像列表
        var newOwnedAvatars = ownedAvatars
        newOwnedAvatars.insert(randomEmoji)
        let afterUnlockAvatarCount = newOwnedAvatars.count
        let avatarIncrease = afterUnlockAvatarCount - beforeUnlockAvatarCount
        
        
        // 验证头像是否真的增加了
        if avatarIncrease != 1 {
        }
        
        // ⚠️ 关键修复：立即更新本地列表，防止重复解锁
        // 必须在发送到服务器之前更新，确保下次解锁时能读取到最新数据
        if let diamondManager = self.userManager.diamondManager {
            // 立即更新本地列表（同步操作）
            diamondManager.ownedAvatars = Array(newOwnedAvatars)
            
            // 然后异步发送到服务器
            diamondManager.updateOwnedAvatarsToServer()
        }
        
        // 更新当前使用的头像
        DispatchQueue.main.async {
            self.currentAvatarEmoji = randomEmoji
        }
        
        // 🎯 新增：更新累计统计
        let previousDiamondsSpent = AvatarZoomView.totalDiamondsSpent
        
        AvatarZoomView.totalUnlockCount += 1
        
        
        // 🔧 按照开发指南：累计消耗基于服务器真实值反向计算，不在此处累加
        // 将在收到服务器同步完成通知时，基于服务器真实值反向计算
        // 此处先使用本地累加作为临时值，后续会被服务器真实值覆盖
        let tempDiamondsSpent = previousDiamondsSpent + 5
        AvatarZoomView.totalDiamondsSpent = tempDiamondsSpent
        
        
        
        // 🔧 修复：移除此处的验证逻辑，因为验证时本地Store值可能还未同步到最新的服务器值
        // 验证逻辑已移到服务器同步完成通知中，使用服务器返回的真实值进行验证
        
        // 保存到UserDefaults
        UserDefaultsManager.setCustomAvatar(userId: userId, emoji: randomEmoji)
        
        // 🔧 修复：更新 UserAvatarRecord 表（当前使用的头像）
        if let currentUser = self.userManager.currentUser {
            let loginTypeString = currentUser.loginType == .apple ? "apple" : "guest"
            
            // 异步更新 UserAvatarRecord 表
            DispatchQueue.global(qos: .userInitiated).async {
                LeanCloudService.shared.updateUserAvatarRecord(
                    objectId: userId,
                    loginType: loginTypeString,
                    userAvatar: randomEmoji
                ) { success in
                    DispatchQueue.main.async {
                        if success {
                            
                            // 使用新的全面同步方法，确保所有表中的头像数据保持一致
                            LeanCloudService.shared.syncAvatarToAllTables(userId: userId, loginType: loginTypeString, newAvatar: randomEmoji) { syncSuccess in
                                if syncSuccess {
                                } else {
                                }
                            }
                        } else {
                        }
                    }
                }
            }
        }
        
        // 🔧 修复：发送头像更新通知，让所有显示当前用户头像的地方立即更新
        NotificationCenter.default.post(
            name: NSNotification.Name("UserAvatarUpdated"),
            object: nil,
            userInfo: ["avatar": randomEmoji, "userId": userId]
        )
    }
    
// 连击相关方法已移至 AvatarZoomView+Combo.swift
}
