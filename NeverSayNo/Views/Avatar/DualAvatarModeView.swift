import SwiftUI

struct DualAvatarModeView: View {
    @ObservedObject var avatarManager: AvatarManager
    var onConfirmDualAvatar: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            // 双头像模式标题和切换按钮
            HStack {
                Text("双头像模式")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { avatarManager.switchToSingleAvatarMode() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 14))
                        Text("切换模式")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
                }
            }
            
            // 双头像选择区域
            HStack(spacing: 20) {
                DualAvatarSelector(
                    title: "第一个头像",
                    selectedAvatar: $avatarManager.selectedFirstAvatar,
                    color: .blue
                )
                
                DualAvatarSelector(
                    title: "第二个头像",
                    selectedAvatar: $avatarManager.selectedSecondAvatar,
                    color: .purple
                )
            }
            
            // 确认按钮
            if avatarManager.canConfirmDualAvatar {
                DualAvatarConfirmButton(avatarManager: avatarManager, onConfirm: onConfirmDualAvatar)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

struct DualAvatarSelector: View {
    let title: String
    @Binding var selectedAvatar: String?
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            if let avatar = selectedAvatar {
                Text(avatar)
                    .font(.system(size: 60))
                    .fixedSize(horizontal: true, vertical: false)
                    .background(
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 100, height: 100)
                    )
            } else {
                Text("请选择")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(width: 100, height: 100)
                    .background(
                        Circle()
                            .stroke(Color.gray, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    )
            }
        }
    }
}

struct DualAvatarConfirmButton: View {
    @ObservedObject var avatarManager: AvatarManager
    @Environment(\.dismiss) private var dismiss
    var onConfirm: (() -> Void)?
    
    var body: some View {
        Button("确认双头像") {
            onConfirm?()
        }
        .font(.headline)
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.blue)
        .cornerRadius(10)
    }
}
