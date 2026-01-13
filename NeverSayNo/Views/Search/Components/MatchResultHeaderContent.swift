import SwiftUI
import MapKit
import CoreLocation

struct MatchResultHeaderContent: View {
    let record: LocationRecord
    let latestAvatars: [String: String]
    let latestUserNames: [String: String]
    let isUserFavorited: (String) -> Bool
    let isUserFavoritedByMe: (String) -> Bool
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void
    let onAvatarTap: () -> Void
    let onCopyUserName: () -> Void
    let isLocationRecordLiked: (String) -> Bool // 🎯 新增：检查是否已点赞
    let onToggleLike: (String, String) -> Void // 🎯 新增：切换点赞状态
    let onDeleteRecommendation: (() -> Void)? // 🎯 新增：删除推荐榜记录回调（可选）
    
    // 🎯 新增：判断是否来自推荐榜
    private var isFromRecommendation: Bool {
        let hasPlaceName = (record.placeName?.isEmpty == false)
        let hasReason = (record.reason?.isEmpty == false)
        return hasPlaceName || hasReason
    }
    
    // 🎯 新增：判断是否是自己的推荐项
    private var isMyRecommendation: Bool {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return false
        }
        return record.userId == currentUserId
    }
    
    // 🎯 新增：打开Apple Maps导航
    private func openAppleMapsNavigation() {
        // 🎯 直接使用GCJ-02坐标，不进行转换
        let coordinate = CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        // 设置地点名称
        if let placeName = record.placeName, !placeName.isEmpty {
            mapItem.name = placeName
        } else {
            let userName = latestUserNames[record.userId] ?? record.userName ?? "未知用户"
            mapItem.name = "\(userName)的位置"
        }
        
        // 打开Apple Maps并开始导航
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
            MKLaunchOptionsMapTypeKey: MKMapType.standard.rawValue,
            MKLaunchOptionsShowsTrafficKey: true
        ])
    }
    
    var body: some View {
        HStack(spacing: 32) {
            MatchResultAvatarButton(
                record: record,
                latestAvatars: latestAvatars,
                onTap: onAvatarTap
            )
            
            MatchResultUserInfo(
                record: record,
                latestUserNames: latestUserNames,
                isUserFavorited: isUserFavorited,
                onToggleFavorite: onToggleFavorite,
                onCopyUserName: onCopyUserName,
                isLocationRecordLiked: isLocationRecordLiked, // 🎯 新增：传递点赞检查
                onToggleLike: onToggleLike // 🎯 新增：传递点赞切换
            )
        }
        .scaleEffect(1.0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            // 🎯 修改：推荐榜按钮 - 删除按钮和导航按钮，位于右上角
            VStack {
                HStack {
                    Spacer()
                    if isFromRecommendation {
                        HStack(spacing: 8) {
                            // 🎯 新增：删除按钮 - 位于导航按钮左侧，只有自己的推荐项才显示
                            if isMyRecommendation, let deleteHandler = onDeleteRecommendation {
                                Button(action: {
                                    deleteHandler()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "trash.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("删除")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // 导航按钮
                            Button(action: {
                                openAppleMapsNavigation()
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("导航")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                    }
                }
                Spacer()
            }
        )
        .onAppear {
        }
    }
}