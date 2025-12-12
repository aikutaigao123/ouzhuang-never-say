import SwiftUI

// 举报记录卡片视图
struct ReportRecordCard: View {
    let record: ReportRecordUI
    let onAction: (ReportAction) -> Void
    @State private var showActionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    // 被举报人信息
                    HStack(spacing: 12) {
                        // 被举报人头像（优先真实头像，其次类型回退）
                        ZStack {
                            // 使用浅色背景，风格与其他界面保持一致
                            Circle()
                                .fill(UserTypeUtils.getUserTypeBackground(record.reportedUserLoginType))
                                .frame(width: 40, height: 40)

                            if let avatar = record.reportedUserAvatar, !avatar.isEmpty {
                                // 与用户头像界面一致：支持SF Symbol和emoji/文本
                                if avatar == "applelogo" || avatar == "apple_logo" {
                                    Image(systemName: "applelogo")
                                        .foregroundColor(.black)
                                        .font(.system(size: 18, weight: .medium))
                                } else if UserAvatarUtils.isSFSymbol(avatar) {
                                    // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                                    Image(systemName: avatar)
                                        .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                                        .font(.system(size: 18, weight: .medium))
                                } else {
                                    Text(avatar)
                                        .font(.system(size: 18))
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            } else if let loginType = record.reportedUserLoginType {
                                // 与用户头像界面一致：统一默认头像显示逻辑 - Apple账号与内部账号使用相同的默认头像
                                switch loginType {
                                case "apple":
                                    Image(systemName: "applelogo")
                                        .foregroundColor(.black)
                                        .font(.system(size: 18, weight: .medium))
                                case "guest":
                                    // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18, weight: .medium))
                                default:
                                    // 默认使用游客头像
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18, weight: .medium))
                                }
                            } else {
                                // 默认使用游客头像
                                Image(systemName: "person.circle")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18, weight: .medium))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("被举报人：\(record.reportedName)")
                                .font(.headline)
                                .foregroundColor(.red)
                            
                            if let loginType = record.reportedUserLoginType {
                                Text(UserTypeUtils.getUserTypeText(loginType))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(UserTypeUtils.getUserTypeBackground(loginType))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                Spacer()
                StatusBadge(status: record.status)
            }
            
            // 举报原因
            VStack(alignment: .leading, spacing: 4) {
                Text("举报原因：\(record.reason)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(record.description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // 操作按钮
            if record.status == "待处理" {
                Button("处理举报") {
                    showActionSheet = true
                }
                .font(.caption)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("处理举报"),
                message: Text("选择处理方式"),
                buttons: [
                    .default(Text("驳回举报")) { onAction(.reject) },
                    .default(Text("警告用户")) { onAction(.warn) },
                    .destructive(Text("封禁用户")) { onAction(.ban) },
                    .cancel()
                ]
            )
        }
    }
    
    // 日期格式化已移至 TimestampUtils.swift
    
    // 用户类型显示文本获取已移至 UserTypeUtils.swift
    
    // 获取用户类型背景颜色
    private func getUserTypeBackground(_ loginType: String?) -> Color {
        switch loginType {
        case "apple":
            return Color.purple.opacity(0.1)
        case "guest":
            return Color.blue.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }
    
    // 获取用户类型头像颜色
    private func getUserTypeColor(_ loginType: String?) -> Color {
        switch loginType {
        case "apple":
            return Color.purple
        case "guest":
            return Color.blue
        default:
            return Color.gray
        }
    }
    
    // 用户类型背景颜色获取已移至 UserTypeUtils.swift
    // 用户类型头像颜色获取已移至 UserTypeUtils.swift
}
