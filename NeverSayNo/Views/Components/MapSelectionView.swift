//
//  MapSelectionView.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import SwiftUI
import MapKit
import CoreLocation

struct MapSelectionView: View {
    let userId: String
    let userName: String
    let loginType: String?
    let latitude: Double
    let longitude: Double
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss
    
    // 状态管理：跟踪前一个角度
    @State private var previousPointerAngle: Double = 0.0
    @State private var userNameFromServer: String? = nil // 从 UserNameRecord 表读取的用户名
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    
    // 优先使用 UserNameRecord 表中的用户名，否则使用传入的用户名
    private var displayedUserName: String {
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        return userName
    }
    
    init(userId: String, userName: String, loginType: String?, latitude: Double, longitude: Double, locationManager: LocationManager) {
        self.userId = userId
        self.userName = userName
        self.loginType = loginType
        self.latitude = latitude
        self.longitude = longitude
        self.locationManager = locationManager
    }
    
    var body: some View {
                NavigationStack {
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Spacer()
                            
                            // 导航内容区域 - 居中显示
                            if let currentLocation = locationManager.location {
                                // 计算指向目标的方位角
                                // ⚖️ 注意：传入的 latitude 和 longitude 已经是 WGS-84 坐标（在调用方已从 GCJ-02 转换）
                                // 因此可以直接与 currentLocation（WGS-84）计算方位角，无需再次转换
                                let bearing = BearingUtils.calculateBearing(
                                    from: currentLocation,
                                    to: latitude,
                                    targetLongitude: longitude
                                )
                                let headingValue = locationManager.heading?.trueHeading ?? 0
                                
                                // 计算最短路径的角度差，避免指针旋转一圈
                                let rawAngle = calculateShortestAngle(from: headingValue, to: bearing)
                                
                                // 使用智能角度管理，避免突然的大角度跳跃
                                let displayPointerAngle = calculateSmartDisplayAngle(rawAngle: rawAngle)
                                
                                // 指针和距离的容器
                                VStack(spacing: 32) {
                                    // 指针 - 大尺寸居中，使用智能动画
                                    Image(systemName: "location.north.fill")
                                        .font(.system(size: 140, weight: .medium))
                                        .foregroundColor(.blue)
                                        .rotationEffect(.degrees(displayPointerAngle))
                                        .animation(
                                            abs(displayPointerAngle) <= 10 ? 
                                                .easeInOut(duration: 0.3) :  // 小角度快速动画
                                                .spring(response: 0.6, dampingFraction: 0.8),  // 大角度弹性动画
                                            value: displayPointerAngle
                                        )
                                        .onAppear {
                                        }
                                    
                                    // 距离显示 - 指针下方
                                    // ⚖️ 注意：传入的 latitude 和 longitude 已经是 WGS-84 坐标（在调用方已从 GCJ-02 转换）
                                    // 因此可以直接与 currentLocation（WGS-84）计算距离，无需再次转换
                                    let distance = DistanceUtils.calculateDistance(
                                        from: currentLocation,
                                        to: latitude,
                                        targetLongitude: longitude
                                    )
                                    
                                    Text(DistanceUtils.formatDistance(distance))
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .onAppear {
                                        }
                                }
                            } else {
                                // 没有位置信息时的显示
                                let headingValue = locationManager.heading?.trueHeading ?? 0
                                
                                VStack(spacing: 32) {
                                    // 默认指针
                                    Image(systemName: "location.north.fill")
                                        .font(.system(size: 140, weight: .medium))
                                        .foregroundColor(.gray.opacity(0.5))
                                        .rotationEffect(.degrees(-headingValue))
                                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: headingValue)
                                    
                                    // 状态文字
                                    Text("获取位置中...")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(Color(.systemBackground))
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("关闭") {
                                dismiss()
                            }
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.blue)
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    navigateWithSystemMap()
                                }) {
                                    Text("导航")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
        .onAppear {
            // 与用户头像界面一致：在onAppear时实时查询服务器用户名
            loadUserNameFromServer()
        }
        .task {
            // 🎯 新增：检查查询是否失败，如果失败则重试
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查是否查询失败（userNameFromServer 为 nil）且未达到最大重试次数
            let shouldRetry = userNameFromServer == nil && userNameRetryCount < 2
            if shouldRetry {
                retryLoadUserNameFromServer()
            }
        }
    }
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取
    private func loadUserNameFromServer() {
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    self.userNameFromServer = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: userId)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: userId, userName: name)
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询用户名（最多重试2次）
    private func retryLoadUserNameFromServer() {
        guard userNameRetryCount < 2 else {
            return
        }
        userNameRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = userNameRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.userNameFromServer == nil {
                self.loadUserNameFromServer()
            }
        }
    }
    
    // 计算最短路径角度差
    private func calculateShortestAngle(from: Double, to: Double) -> Double {
        var angleDifference = to - from
        
        // 标准化到 [-180, 180] 范围
        while angleDifference > 180 {
            angleDifference -= 360
        }
        while angleDifference < -180 {
            angleDifference += 360
        }
        
        return angleDifference
    }
    
    // 智能角度管理 - 避免突然的大角度跳跃
    private func calculateSmartDisplayAngle(rawAngle: Double) -> Double {
        // 计算与前一个角度的差值
        let angleChange = rawAngle - previousPointerAngle
        
        // 如果角度变化很大（超过90度），可能是由于边界跳跃导致的
        if abs(angleChange) > 90 {
            // 选择更平滑的路径
            let alternativeAngle = previousPointerAngle + (angleChange > 0 ? -360 : 360) + angleChange
            if abs(alternativeAngle - previousPointerAngle) < abs(angleChange) {
                // 更新状态
                DispatchQueue.main.async {
                    self.previousPointerAngle = alternativeAngle
                }
                return alternativeAngle
            }
        }
        
        // 更新状态
        DispatchQueue.main.async {
            self.previousPointerAngle = rawAngle
        }
        
        return rawAngle
    }
    
    // 使用系统地图导航
    private func navigateWithSystemMap() {
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        mapItem.name = "\(displayedUserName)的位置"
        
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue,
            MKLaunchOptionsShowsTrafficKey: false
        ])
        
        
        dismiss()
    }
}

#Preview {
    MapSelectionView(
        userId: "test_user",
        userName: "测试用户",
        loginType: "guest",
        latitude: 39.9042,
        longitude: 116.4074,
        locationManager: LocationManager()
    )
}