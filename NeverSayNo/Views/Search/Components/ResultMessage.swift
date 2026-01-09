import SwiftUI

struct ResultMessage: View {
    let message: String
    let backgroundColor: Color
    let textColor: Color
    let cornerRadius: CGFloat
    let padding: CGFloat
    
    init(
        message: String,
        backgroundColor: Color = Color.green.opacity(0.1),
        textColor: Color = .green,
        cornerRadius: CGFloat = 10,
        padding: CGFloat = 16
    ) {
        self.message = message
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    var body: some View {
        if !message.isEmpty {
            Text(message)
                .padding()
                .background(backgroundColor)
                .cornerRadius(cornerRadius)
                .foregroundColor(textColor)
        }
    }
}
