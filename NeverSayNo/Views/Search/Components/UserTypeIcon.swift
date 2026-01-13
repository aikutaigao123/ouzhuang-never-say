import SwiftUI

struct UserTypeIcon: View {
    let loginType: String?
    
    var body: some View {
        // 与用户头像界面一致：统一默认头像显示逻辑 - Apple账号与内部账号使用相同的默认头像
        if loginType == "apple" {
            Image(systemName: "applelogo")
                .foregroundColor(.black)
                .font(.system(size: 11))
        } else {
            // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
            Image(systemName: "person.circle")
                .foregroundColor(.blue)
                .font(.system(size: 11))
        }
    }
}
