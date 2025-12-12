import SwiftUI

struct CompassDirectionMarker: View {
    let direction: String
    let index: Int
    let headingValue: Double
    
    var body: some View {
        let angle = Double(index) * 45.0
        let color: Color = index == 0 ? .red : .black
        
        VStack {
            Text(direction)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            Spacer()
        }
        .frame(width: 250, height: 250)
        .rotationEffect(.degrees(angle - headingValue))
        .animation(.easeInOut(duration: 0.3), value: headingValue)
    }
}
