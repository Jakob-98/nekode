import SwiftUI

/// Subtle nag banner shown to unlicensed users at the bottom of the popup.
/// Follows the Sublime Text model: non-intrusive, non-blocking, disappears when licensed.
struct LicenseBanner: View {
    @ObservedObject var licenseManager: LicenseManager
    @State private var purchaseHovered = false

    var body: some View {
        if !licenseManager.status.isLicensed {
            HStack(spacing: 4) {
                Text("Support CatAssistant development \u{2014}")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.textMuted)
                Spacer()
                Button {
                    licenseManager.openPurchasePage()
                } label: {
                    Text("Purchase a license")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.amber)
                        .opacity(purchaseHovered ? 1.0 : 0.8)
                        .underline(purchaseHovered)
                }
                .buttonStyle(.plain)
                .onHover { purchaseHovered = $0 }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color.amber.opacity(0.05))
        }
    }
}
