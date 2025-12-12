import SwiftUI

struct FriendRowView: View {
    let friend: MatchRecord
    let currentUserId: String
    @Binding var avatarCache: [String: String]
    @Binding var userNameCache: [String: String]
    @Binding var onlineStatusCache: [String: (Bool, Date?)] // 新增：在线状态缓存绑定
    @Binding var loginTypeCache: [String: String] // 🎯 新增：用户类型缓存绑定
    @Binding var patMessages: [MessageItem] // 新增：拍一拍消息数组
    @Binding var patMessagesExpandedStates: [String: Bool] // 新增：拍一拍消息展开状态绑定
    let onTap: () -> Void
    let onPat: () -> Void // 新增：拍一拍回调
    @Binding var patButtonPressed: [String: Bool] // 新增：拍一拍按钮状态绑定
    let onViewLocation: (String) -> Void // 新增：查看位置回调
    let onUnfriend: (() -> Void)? // 🎯 新增：解除好友关系回调（可选，用于 macOS 右键菜单）
    
    // 在线状态管理
    @State var isOnline: Bool = false
    @State var lastActiveTime: Date? = nil
    @State var hasLoadedOnlineStatus: Bool = false
    @State var isLoadingOnlineStatus: Bool = false
    
    // 用户类型管理
    @State var userLoginType: String? = nil
    @State var hasLoadedLoginType: Bool = false
    
    // 实时查询的头像和用户名（优先使用）
    @State var avatarFromServer: String? = nil
    @State var userNameFromServer: String? = nil
    @State var hasLoadedFromServer: Bool = false
    @State var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    @State var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    
    // 数字变化监听
    @State var previousPatCount: Int = 0
    @State var hasInitializedPatCount: Bool = false
    
    // 拍一拍相关方法已移动到 FriendRowView+PatMessage.swift
    // 格式化最近活跃时间方法已移动到 FriendRowView+TimeFormatting.swift
    // 用户信息查询相关方法已移动到 FriendRowView+UserInfo.swift
    // displayedName 计算属性已移动到 FriendRowView+DisplayName.swift
    // body 视图已移动到 FriendRowView+Body.swift
}
