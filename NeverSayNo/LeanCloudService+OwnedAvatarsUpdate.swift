//
//  LeanCloudService+OwnedAvatarsUpdate.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 头像列表更新功能
extension LeanCloudService {
    
    // 创建或更新用户拥有的头像列表
    func updateOwnedAvatars(userId: String, loginType: String, ownedAvatars: [String], completion: @escaping (Bool) -> Void) {
        
        // 参数验证
        guard !userId.isEmpty else {
            completion(false)
            return
        }
        
        guard !loginType.isEmpty else {
            completion(false)
            return
        }
        
        guard !ownedAvatars.isEmpty else {
            completion(true) // 空列表也认为是成功的
            return
        }
        
        // 确保表存在（首次上传时自动创建）
        ensureOwnedAvatarsTableExists { [weak self] tableExists in
            if tableExists {
                self?.performUpdateOwnedAvatars(userId: userId, loginType: loginType, ownedAvatars: ownedAvatars, completion: completion)
            } else {
                completion(false)
            }
        }
    }
}
