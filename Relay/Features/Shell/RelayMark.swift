import SwiftUI

struct RelayMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.cyan, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 1) {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 11, weight: .bold))
                Text(">_").font(.system(size: 17, weight: .bold, design: .monospaced))
            }.foregroundStyle(.white)
        }
        .frame(width: 40, height: 40).accessibilityHidden(true)
    }
}
