import AppKit
import Foundation
import Security

// MARK: - License Status

enum LicenseStatus: Equatable {
    case unlicensed
    case licensed(email: String)
    case validating

    var isLicensed: Bool {
        if case .licensed = self { return true }
        return false
    }

    var email: String? {
        if case .licensed(let email) = self { return email }
        return nil
    }
}

// MARK: - LicenseManager

/// Manages license key validation and storage for CatAssistant.
///
/// Uses the "Sublime Text model": fully functional unlimited trial with a
/// subtle nag banner. License key is stored in the macOS Keychain and
/// validated against the Paddle API periodically (cached, works offline).
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var status: LicenseStatus = .unlicensed

    /// How long a cached validation is considered fresh (7 days).
    private let validationCacheDuration: TimeInterval = 7 * 24 * 60 * 60

    // Paddle configuration — replace with real values when Paddle account is set up
    // These are placeholders that will be configured during Paddle onboarding
    static let purchaseURL = "https://catassistant.dev/buy"
    static let paddleVendorID = "PADDLE_VENDOR_ID"
    static let paddleProductID = "PADDLE_PRODUCT_ID"

    private let keychainService = "com.jakobserlier.CatAssistant.license"
    private let keychainAccountKey = "licenseKey"
    private let keychainEmailKey = "licenseEmail"
    private let lastValidationKey = "licenseLastValidation"

    // MARK: - Init

    private init() {
        loadFromKeychain()
    }

    // MARK: - Public API

    /// Activate a license key. Validates against Paddle API first, then caches in Keychain.
    func activate(licenseKey: String, email: String? = nil) async -> Result<String, LicenseError> {
        status = .validating

        // Try online validation first
        let result = await validateWithPaddle(licenseKey: licenseKey)
        switch result {
        case .success(let validatedEmail):
            let email = email ?? validatedEmail
            saveToKeychain(licenseKey: licenseKey, email: email)
            cacheValidationTimestamp()
            status = .licensed(email: email)
            return .success(email)
        case .failure(let error):
            // If network error and we have an existing key, keep the license active (offline grace)
            if error == .networkError, let existing = loadKeychainValue(account: keychainAccountKey),
               existing == licenseKey {
                let savedEmail = loadKeychainValue(account: keychainEmailKey) ?? ""
                status = .licensed(email: savedEmail)
                return .success(savedEmail)
            }
            status = .unlicensed
            return .failure(error)
        }
    }

    /// Activate offline — for manual key entry when network is unavailable.
    /// Stores the key and marks as licensed without server validation.
    /// Will validate on next app launch when network is available.
    func activateOffline(licenseKey: String, email: String) {
        saveToKeychain(licenseKey: licenseKey, email: email)
        status = .licensed(email: email)
    }

    /// Deactivate / remove the current license.
    func deactivate() {
        deleteFromKeychain()
        UserDefaults.standard.removeObject(forKey: lastValidationKey)
        status = .unlicensed
    }

    /// Re-validate the stored license (called on app launch or periodically).
    func revalidateIfNeeded() async {
        guard let licenseKey = loadKeychainValue(account: keychainAccountKey) else { return }
        let email = loadKeychainValue(account: keychainEmailKey) ?? ""

        // If recently validated, skip
        if let lastValidation = UserDefaults.standard.object(forKey: lastValidationKey) as? Date,
           Date().timeIntervalSince(lastValidation) < validationCacheDuration {
            status = .licensed(email: email)
            return
        }

        // Validate in background
        let result = await validateWithPaddle(licenseKey: licenseKey)
        switch result {
        case .success(let validatedEmail):
            let finalEmail = validatedEmail.isEmpty ? email : validatedEmail
            saveToKeychain(licenseKey: licenseKey, email: finalEmail)
            cacheValidationTimestamp()
            status = .licensed(email: finalEmail)
        case .failure(.networkError):
            // Offline grace: keep the license active
            status = .licensed(email: email)
        case .failure:
            // License revoked or invalid
            deactivate()
        }
    }

    /// Open the purchase page in the default browser.
    func openPurchasePage() {
        if let url = URL(string: Self.purchaseURL) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Paddle API Validation

    private func validateWithPaddle(licenseKey: String) async -> Result<String, LicenseError> {
        // TODO: Replace with real Paddle API call when vendor account is set up.
        // For now, accept any non-empty key that looks like a license format.
        // This allows testing the full UI flow before Paddle integration.
        //
        // Real implementation will POST to:
        //   https://v3.paddleapis.com/api/2.0/license/verify
        // with vendor_id, product_id, and license key.

        guard !licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.invalidKey)
        }

        // Simulate network validation (remove this when real API is wired up)
        // Accept keys in format: CA-XXXX-XXXX-XXXX-XXXX (for testing)
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("CA-") && trimmed.count >= 19 {
            return .success("")
        }

        // In production, any error here becomes a network error so we
        // gracefully fall back to cached validation
        return .failure(.invalidKey)
    }

    // MARK: - Keychain Storage

    private func loadFromKeychain() {
        guard let licenseKey = loadKeychainValue(account: keychainAccountKey),
              !licenseKey.isEmpty else {
            status = .unlicensed
            return
        }
        let email = loadKeychainValue(account: keychainEmailKey) ?? ""
        status = .licensed(email: email)
    }

    private func saveToKeychain(licenseKey: String, email: String) {
        saveKeychainValue(licenseKey, account: keychainAccountKey)
        saveKeychainValue(email, account: keychainEmailKey)
    }

    private func deleteFromKeychain() {
        deleteKeychainValue(account: keychainAccountKey)
        deleteKeychainValue(account: keychainEmailKey)
    }

    private func cacheValidationTimestamp() {
        UserDefaults.standard.set(Date(), forKey: lastValidationKey)
    }

    // MARK: - Keychain Helpers

    private func saveKeychainValue(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        // Delete existing
        SecItemDelete(query as CFDictionary)
        // Add new
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadKeychainValue(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychainValue(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum LicenseError: Error, Equatable {
    case invalidKey
    case networkError
    case expired
    case revoked

    var localizedDescription: String {
        switch self {
        case .invalidKey: return "Invalid license key."
        case .networkError: return "Could not reach the license server. Please check your connection."
        case .expired: return "This license has expired."
        case .revoked: return "This license has been revoked."
        }
    }
}
