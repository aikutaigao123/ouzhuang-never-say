import SwiftUI

struct SearchPointerImage: View {
    var body: some View {
        Image(systemName: "location.north.fill")
            .imageScale(.large)
            .foregroundStyle(.blue) // 🎯 指针永远是蓝色
            .font(.system(size: 50))
            .shadow(radius: 2)
    }
}
