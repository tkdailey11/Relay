import SwiftUI

struct RelayMark: View {
    var body: some View {
        Image(.relayMark)
            .resizable()
            .scaledToFit()
            .frame(width: 48, height: 48)
            .accessibilityHidden(true)
    }
}
