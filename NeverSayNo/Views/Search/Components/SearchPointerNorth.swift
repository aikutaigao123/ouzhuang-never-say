import SwiftUI

struct SearchPointerNorth: View {
    let headingValue: Double
    
    var body: some View {
        SearchPointerImage()
            .rotationEffect(.degrees(-headingValue))
            .animation(.easeInOut(duration: 0.3), value: headingValue)
    }
}
