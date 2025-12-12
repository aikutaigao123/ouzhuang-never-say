import SwiftUI

struct WarningToast: View {
    let isVisible: Bool
    let message: String
    
    var body: some View {
        if isVisible {
            VStack {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                    Text(message)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .zIndex(1000)
        }
    }
}
