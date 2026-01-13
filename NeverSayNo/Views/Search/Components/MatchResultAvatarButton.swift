import SwiftUI

struct MatchResultAvatarButton: View {
    let record: LocationRecord
    let latestAvatars: [String: String]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            MatchResultAvatarView(
                record: record,
                latestAvatars: latestAvatars
            )
        }
        .buttonStyle(.plain)
    }
}