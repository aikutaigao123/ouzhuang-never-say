import SwiftUI

struct EmptyState: View {
    let text: String
    let font: Font
    let color: Color
    let weight: Font.Weight
    let padding: CGFloat
    
    init(
        text: String = "--",
        font: Font = .body,
        color: Color = .gray,
        weight: Font.Weight = .medium,
        padding: CGFloat = 16
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.weight = weight
        self.padding = padding
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(text)
                .font(font)
                .foregroundColor(color)
                .fontWeight(weight)
        }
        .padding(.top, padding)
    }
}
