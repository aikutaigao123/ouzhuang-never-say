import SwiftUI

struct DefaultAvatarView: View {
    let loginType: String?
    
    var body: some View {
        // 与用户头像界面一致：统一默认头像显示逻辑 - Apple账号与内部账号使用相同的默认头像
        if loginType == "apple" {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.purple)
        } else {
            // 游客用户：使用person.circle（蓝色），与用户头像界面一致
            Image(systemName: "person.circle")
                .foregroundColor(.blue)
        }
    }
}
