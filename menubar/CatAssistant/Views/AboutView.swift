import SwiftUI

struct AboutView: View {
    private var version: String { Bundle.main.appVersion }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                Text("CatAssistant")
                    .font(.system(size: 18, weight: .bold))
                Text("Monitor your AI coding sessions")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                Text("Version \(version)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider().padding(.horizontal, 14)

            VStack(spacing: 4) {
                Text("\u{00A9} 2025 Jakob Serlier")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.textSecondary)
                Text("MIT License")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.vertical, 10)

            Divider().padding(.horizontal, 14)

            VStack(spacing: 2) {
                HoverLinkButton(
                    label: "Built on cctop by Stan Lo",
                    url: "https://github.com/st0012/cctop",
                    font: .system(size: 9),
                    color: Color.textMuted
                )
                Text("No analytics \u{00B7} No telemetry")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.textMuted)
            }
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HoverLinkButton: View {
    let label: String
    let url: String
    var font: Font = .system(size: 11)
    var color: Color = .amber
    var showArrow: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button {
            if let linkURL = URL(string: url) {
                NSWorkspace.shared.open(linkURL)
            }
        } label: {
            HStack(spacing: 4) {
                Text(label)
                    .font(font)
                    .underline(isHovered)
                if showArrow {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .semibold))
                }
            }
            .foregroundStyle(isHovered ? .primary : color)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

#Preview {
    AboutView()
        .frame(width: 320)
        .background(Color.settingsBackground)
        .padding()
}
