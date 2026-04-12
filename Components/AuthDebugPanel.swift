import SwiftUI

struct AuthDebugPanel: View {
    let message: String
    let isAuthenticated: Bool
    let userEmail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AUTH DEBUG")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.8)

            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)

            Text("authenticated=\(isAuthenticated ? "yes" : "no")  user=\(userEmail ?? "nil")")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.black.opacity(0.78))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.yellow)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

