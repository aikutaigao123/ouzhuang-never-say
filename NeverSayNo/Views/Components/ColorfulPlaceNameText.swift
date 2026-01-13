//
//  ColorfulPlaceNameText.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import SwiftUI

// 🎯 推荐榜地名文本组件（根据推荐者的 UserNameRecord 决定是否显示彩色）
struct ColorfulPlaceNameText: View {
    let placeName: String
    let userId: String
    let loginType: String?
    let font: Font
    let fontWeight: Font.Weight
    let lineLimit: Int?
    let truncationMode: Text.TruncationMode
    
    @State private var isColorfulModeEnabled: Bool = false
    @State private var hasLoadedColorfulMode: Bool = false
    
    init(
        placeName: String,
        userId: String,
        loginType: String? = nil,
        font: Font = .title3,
        fontWeight: Font.Weight = .bold,
        lineLimit: Int? = 1,
        truncationMode: Text.TruncationMode = .tail
    ) {
        self.placeName = placeName
        self.userId = userId
        self.loginType = loginType
        self.font = font
        self.fontWeight = fontWeight
        self.lineLimit = lineLimit
        self.truncationMode = truncationMode
    }
    
    var body: some View {
        Group {
            if isColorfulModeEnabled {
                // 彩色模式：显示彩色渐变
                Text(placeName)
                    .font(font)
                    .fontWeight(fontWeight)
                    .lineLimit(lineLimit)
                    .truncationMode(truncationMode)
                    .animatedGradientText()
            } else {
                // 非彩色模式：显示绿色
                Text(placeName)
                    .font(font)
                    .fontWeight(fontWeight)
                    .foregroundColor(.green)
                    .lineLimit(lineLimit)
                    .truncationMode(truncationMode)
            }
        }
        .id("placeName-\(userId)-\(placeName)") // 🎯 添加稳定的标识符
        .onAppear {
            if !hasLoadedColorfulMode {
                loadColorfulModeFromServer()
            }
        }
    }
    
    // 🎯 从服务器加载彩色模式状态（与用户名查询机制一致：直接查询服务器，不检查缓存）
    private func loadColorfulModeFromServer() {
        // 🎯 修复：如果 userId 为空，直接返回，不进行查询
        guard !userId.isEmpty else {
            DispatchQueue.main.async {
                self.isColorfulModeEnabled = false
                self.hasLoadedColorfulMode = true
            }
            return
        }
        
        // 🎯 修改：与用户名查询机制一致，直接查询服务器，不检查 UserDefaults 缓存
        // 如果没有 loginType，尝试通过 userId 查询
        let finalLoginType: String
        if let loginType = loginType, !loginType.isEmpty {
            finalLoginType = loginType
        } else {
            // 尝试从 UserNameRecord 获取 loginType
            LeanCloudService.shared.fetchUserLoginType(objectId: userId) { fetchedLoginType in
                DispatchQueue.main.async {
                    if let fetchedLoginType = fetchedLoginType {
                        self.queryColorfulMode(userId: userId, loginType: fetchedLoginType)
                    } else {
                        // 如果无法获取 loginType，默认为 guest
                        self.queryColorfulMode(userId: userId, loginType: "guest")
                    }
                }
            }
            return
        }
        
        queryColorfulMode(userId: userId, loginType: finalLoginType)
    }
    
    private func queryColorfulMode(userId: String, loginType: String) {
        // 🎯 修改：与用户名查询机制一致，直接查询服务器
        LeanCloudService.shared.fetchColorfulModeEnabled(
            objectId: userId,
            loginType: loginType
        ) { isEnabled in
            DispatchQueue.main.async {
                if let isEnabled = isEnabled {
                    self.isColorfulModeEnabled = isEnabled
                    // 更新 UserDefaults 缓存（用于其他用途，但不用于阻止查询）
                    UserDefaultsManager.setColorfulModeEnabled(userId: userId, enabled: isEnabled)
                } else {
                    // 如果查询失败或字段不存在，默认为 false
                    self.isColorfulModeEnabled = false
                    UserDefaultsManager.setColorfulModeEnabled(userId: userId, enabled: false)
                }
                self.hasLoadedColorfulMode = true
            }
        }
    }
}

