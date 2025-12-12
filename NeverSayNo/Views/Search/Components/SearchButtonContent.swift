import SwiftUI

struct SearchButtonContent: View {
    let isLoading: Bool
    let isUserBlacklisted: Bool
    
    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .foregroundColor(.white)
            } else {
                Text("💎")
            }
            Text(buttonText)
        }
        .font(.title)
        .fontWeight(.bold)
        .foregroundColor(.white)
        .padding(.horizontal, 30)
        .padding(.vertical, 10)
    }
    
    private var buttonText: String {
        if isLoading { return "寻找中..." }
        if isUserBlacklisted { return "已被禁用" }
        return "寻找"
    }
}
