import SwiftUI

struct MatchResultCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
    }
}