import SwiftUI

struct AvatarZoomView: View {
    @ObservedObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @State var currentAvatarEmoji: String? = nil
    @State var showAlert = false
    @State var alertMessage = ""
    @State var timer: Timer?
    @State var isHeartClicked = false
    @State var showAvatarBackpack = false
    @State var longPressTimer: Timer? = nil
    @State var isLongPressing = false
    @State var comboCount = 0
    @State var maxComboCount = 0
    let showRandomButton: Bool
    
    // 添加一个计算属性来获取当前头像
    var displayAvatar: String? {
        return currentAvatarEmoji
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                Spacer()
                
                // 放大的头像
                AvatarDisplayView(
                    displayAvatar: displayAvatar,
                    userManager: userManager,
                    onAvatarTap: {
                        showAvatarBackpack = true
                    }
                )
                
                // 用户信息
                UserInfoView(userManager: userManager)
                
                // 随机切换头像按钮 - 只在指定情况下显示
                if showRandomButton {
                    RandomAvatarButtonView(
                        isLongPressing: $isLongPressing,
                        comboCount: $comboCount,
                        maxComboCount: $maxComboCount,
                        onRandomize: randomizeAvatar,
                        onLongPressStart: startLongPressCombo,
                        onLongPressEnd: stopLongPressCombo,
                        userManager: userManager
                    )
                    
                    // 消耗钻石说明和长按连击说明
                    HStack(spacing: 15) {
                        Text("💡 消耗 5 钻石")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text("·")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        Text("长按可连续解锁多个头像")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 1)
                    
                    // 连击进度指示器
                    ComboProgressView(
                        comboCount: comboCount,
                        maxComboCount: maxComboCount,
                        isLongPressing: isLongPressing
                    )
                    
                    // 预览卡片
                    AvatarPreviewCardView(
                        displayAvatar: displayAvatar,
                        userManager: userManager,
                        isHeartClicked: $isHeartClicked
                    )
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("用户头像")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("头像背包") {
                    showAvatarBackpack = true
                },
                trailing: Button("关闭") {
                    dismiss()
                }
            )
            .alert("提示", isPresented: $showAlert) {
                Button("确定") { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                initializeAvatarDisplay()
                loadMaxComboCount()
                startStatusTimer()
                
                // 🎯 新增：检查并自动创建UserNameRecord（如果没有数据则生成随机用户名）
                if let userId = userManager.currentUser?.id,
                   let loginType = userManager.currentUser?.loginType {
                    let loginTypeString = loginType == .apple ? "apple" : "guest"
                    LeanCloudService.shared.ensureCurrentUserUserNameRecordExists(
                        objectId: userId,
                        loginType: loginTypeString,
                        userName: nil, // 传入nil会自动生成随机用户名
                        userEmail: userManager.currentUser?.email
                    ) { success, message in
                        // 静默处理，不显示错误提示
                    }
                    
                    // 🎯 新增：检查并自动创建UserAvatarRecord（如果没有数据则生成随机emoji头像）
                    LeanCloudService.shared.ensureCurrentUserAvatarRecordExists(
                        objectId: userId,
                        loginType: loginTypeString,
                        userAvatar: nil // 传入nil会自动生成随机emoji
                    ) { success, message in
                        // 静默处理，不显示错误提示
                    }
                }
                
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DiamondBalanceServerSyncCompleted"))) { notification in
                guard let userInfo = notification.userInfo,
                      let serverAmount = userInfo["serverAmount"] as? Int,
                      let reason = userInfo["reason"] as? String else {
                    return
                }
                
                // 只处理头像解锁相关的操作
                if reason == "用户操作" && AvatarZoomView.totalUnlockCount > 0 {
                    // 🔧 按照开发指南：基于服务器真实值反向计算累计消耗（利用fetchWhenSave返回值）
                    if AvatarZoomView.sessionStartServerDiamonds > 0 {
                        let actualServerSpent = AvatarZoomView.sessionStartServerDiamonds - serverAmount
                        let _ = AvatarZoomView.totalDiamondsSpent
                        let oldUnlockCount = AvatarZoomView.totalUnlockCount
                        let oldSessionStartServerDiamonds = AvatarZoomView.sessionStartServerDiamonds
                        let _ = AvatarZoomView.sessionStartDiamonds
                        let _ = AvatarZoomView.sessionStartAvatarCount
                        
                        // 🔍 检查会话开始服务器值是否合理
                        let expectedStartFromUnlocks = serverAmount + (oldUnlockCount * 5)
                        if oldSessionStartServerDiamonds != expectedStartFromUnlocks {
                            // 🔧 修复：如果检测到起始值不正确，使用反向计算修正
                            let correctedStartDiamonds = expectedStartFromUnlocks
                            AvatarZoomView.sessionStartServerDiamonds = correctedStartDiamonds
                            let correctedServerSpent = correctedStartDiamonds - serverAmount
                            
                            // 使用修正后的值
                            AvatarZoomView.totalDiamondsSpent = correctedServerSpent
                        } else {
                            // 起始值正确，正常调整
                            AvatarZoomView.totalDiamondsSpent = actualServerSpent
                        }
                    }
                }
            }
            .onDisappear {
                cleanupTimers()
            }
            .sheet(isPresented: $showAvatarBackpack) {
                AvatarBackpackView(userManager: userManager, currentAvatarEmoji: $currentAvatarEmoji)
            }
        }
    }
}
