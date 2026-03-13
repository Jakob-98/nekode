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

/// Manages license key validation and storage for Nekode.
///
/// Uses the "Sublime Text model": fully functional unlimited trial with a
/// subtle nag banner. License key is stored in the macOS Keychain and
/// validated against the Lemon Squeezy License API periodically (cached,
/// works offline with grace period).
@MainActor
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    @Published private(set) var status: LicenseStatus = .unlicensed

    /// How long a cached validation is considered fresh (7 days).
    private let validationCacheDuration: TimeInterval = 7 * 24 * 60 * 60

    // Lemon Squeezy License API — no auth token needed, these are public endpoints.
    private let lsActivateURL = "https://api.lemonsqueezy.com/v1/licenses/activate"
    private let lsValidateURL = "https://api.lemonsqueezy.com/v1/licenses/validate"
    private let lsDeactivateURL = "https://api.lemonsqueezy.com/v1/licenses/deactivate"

    static let purchaseURL = "https://nekode.dev"

    private let keychainService = "dev.nekode.Nekode.license"
    private let keychainAccountKey = "licenseKey"
    private let keychainEmailKey = "licenseEmail"
    private let keychainInstanceKey = "licenseInstanceId"
    private let lastValidationKey = "licenseLastValidation"

    // MARK: - Init

    private init() {
        loadFromKeychain()
    }

    // MARK: - Public API

    /// Activate a license key. Calls Lemon Squeezy activate endpoint, stores
    /// the key + instance ID + email in Keychain on success.
    func activate(licenseKey: String, email: String? = nil) async -> Result<String, LicenseError> {
        status = .validating

        let result = await lsActivate(licenseKey: licenseKey)
        switch result {
        case .success(let response):
            let resolvedEmail = response.email.isEmpty ? (email ?? "") : response.email
            saveToKeychain(licenseKey: licenseKey, email: resolvedEmail, instanceId: response.instanceId)
            cacheValidationTimestamp()
            status = .licensed(email: resolvedEmail)
            return .success(resolvedEmail)
        case .failure(let error):
            // Offline grace: if network error and we already have this key stored, keep active
            if error == .networkError,
               let existing = loadKeychainValue(account: keychainAccountKey),
               existing == licenseKey.trimmingCharacters(in: .whitespacesAndNewlines) {
                let savedEmail = loadKeychainValue(account: keychainEmailKey) ?? ""
                status = .licensed(email: savedEmail)
                return .success(savedEmail)
            }
            status = .unlicensed
            return .failure(error)
        }
    }

    /// Deactivate / remove the current license. Calls LS deactivate endpoint
    /// to free up the activation slot, then wipes local state.
    func deactivate() {
        let key = loadKeychainValue(account: keychainAccountKey)
        let instanceId = loadKeychainValue(account: keychainInstanceKey)

        // Fire-and-forget deactivation — don't block the UI
        if let key, let instanceId {
            Task.detached { [lsDeactivateURL] in
                _ = try? await LicenseManager.lsPost(
                    url: lsDeactivateURL,
                    body: ["license_key": key, "instance_id": instanceId]
                )
            }
        }

        deleteFromKeychain()
        UserDefaults.standard.removeObject(forKey: lastValidationKey)
        status = .unlicensed
    }

    /// Re-validate the stored license (called on app launch or periodically).
    func revalidateIfNeeded() async {
        guard let licenseKey = loadKeychainValue(account: keychainAccountKey) else { return }
        let email = loadKeychainValue(account: keychainEmailKey) ?? ""
        let instanceId = loadKeychainValue(account: keychainInstanceKey)

        // If recently validated, skip
        if let lastValidation = UserDefaults.standard.object(forKey: lastValidationKey) as? Date,
           Date().timeIntervalSince(lastValidation) < validationCacheDuration {
            status = .licensed(email: email)
            return
        }

        // Validate in background
        let result = await lsValidate(licenseKey: licenseKey, instanceId: instanceId)
        switch result {
        case .success(let response):
            let finalEmail = response.email.isEmpty ? email : response.email
            // Update email if the API returned a newer one; instance ID stays the same
            saveToKeychain(licenseKey: licenseKey, email: finalEmail,
                           instanceId: instanceId ?? response.instanceId)
            cacheValidationTimestamp()
            status = .licensed(email: finalEmail)
        case .failure(.networkError):
            // Offline grace: keep the license active
            status = .licensed(email: email)
        case .failure:
            // License revoked, expired, or disabled
            deactivate()
        }
    }

    /// Open the purchase page in the default browser.
    func openPurchasePage() {
        if let url = URL(string: Self.purchaseURL) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Lemon Squeezy License API

    private struct LSResponse {
        let email: String
        let instanceId: String
    }

    /// POST /v1/licenses/activate
    private func lsActivate(licenseKey: String) async -> Result<LSResponse, LicenseError> {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.invalidKey) }

        let instanceName = Host.current().localizedName ?? "Mac"
        let body = ["license_key": trimmed, "instance_name": instanceName]

        do {
            let json = try await Self.lsPost(url: lsActivateURL, body: body)
            guard let activated = json["activated"] as? Bool else {
                return .failure(.invalidKey)
            }
            if !activated {
                return Self.mapLSError(json)
            }
            let email = Self.extractEmail(from: json)
            let instanceId = Self.extractInstanceId(from: json)
            return .success(LSResponse(email: email, instanceId: instanceId))
        } catch let error as LicenseError {
            return .failure(error)
        } catch {
            return .failure(.networkError)
        }
    }

    /// POST /v1/licenses/validate
    private func lsValidate(
        licenseKey: String, instanceId: String?
    ) async -> Result<LSResponse, LicenseError> {
        var body = ["license_key": licenseKey]
        if let instanceId { body["instance_id"] = instanceId }

        do {
            let json = try await Self.lsPost(url: lsValidateURL, body: body)
            guard let valid = json["valid"] as? Bool else {
                return .failure(.invalidKey)
            }
            if !valid {
                return Self.mapLSError(json)
            }
            let email = Self.extractEmail(from: json)
            let respInstanceId = Self.extractInstanceId(from: json)
            return .success(LSResponse(email: email, instanceId: respInstanceId))
        } catch let error as LicenseError {
            return .failure(error)
        } catch {
            return .failure(.networkError)
        }
    }

    // MARK: - HTTP Helper

    /// Perform a form-encoded POST to a Lemon Squeezy License API endpoint.
    /// Returns the parsed JSON dictionary. Throws `LicenseError.networkError` on failure.
    private static func lsPost(
        url urlString: String, body: [String: String]
    ) async throws -> [String: Any] {
        guard let url = URL(string: urlString) else { throw LicenseError.networkError }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let formBody = body.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")
        request.httpBody = formBody.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LicenseError.networkError
        }

        // LS returns 200 for both success and validation errors;
        // 4xx/5xx means something else went wrong.
        if http.statusCode >= 500 {
            throw LicenseError.networkError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LicenseError.networkError
        }
        return json
    }

    // MARK: - Response Parsing Helpers

    private static func extractEmail(from json: [String: Any]) -> String {
        if let meta = json["meta"] as? [String: Any],
           let email = meta["customer_email"] as? String {
            return email
        }
        return ""
    }

    private static func extractInstanceId(from json: [String: Any]) -> String {
        if let instance = json["instance"] as? [String: Any],
           let id = instance["id"] as? String {
            return id
        }
        return ""
    }

    /// Map a Lemon Squeezy error response to a `LicenseError`.
    private static func mapLSError(_ json: [String: Any]) -> Result<LSResponse, LicenseError> {
        let errorMsg = (json["error"] as? String)?.lowercased() ?? ""
        if let lk = json["license_key"] as? [String: Any],
           let lkStatus = lk["status"] as? String {
            switch lkStatus {
            case "expired": return .failure(.expired)
            case "disabled": return .failure(.revoked)
            default: break
            }
        }
        if errorMsg.contains("activation limit") {
            return .failure(.activationLimit)
        }
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

    private func saveToKeychain(licenseKey: String, email: String, instanceId: String?) {
        saveKeychainValue(licenseKey, account: keychainAccountKey)
        saveKeychainValue(email, account: keychainEmailKey)
        if let instanceId, !instanceId.isEmpty {
            saveKeychainValue(instanceId, account: keychainInstanceKey)
        }
    }

    private func deleteFromKeychain() {
        deleteKeychainValue(account: keychainAccountKey)
        deleteKeychainValue(account: keychainEmailKey)
        deleteKeychainValue(account: keychainInstanceKey)
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

enum LicenseError: LocalizedError, Equatable {
    case invalidKey
    case networkError
    case expired
    case revoked
    case activationLimit

    var errorDescription: String? {
        switch self {
        case .invalidKey: return "Invalid license key."
        case .networkError: return "Could not reach the license server. Please check your connection."
        case .expired: return "This license has expired."
        case .revoked: return "This license has been revoked."
        case .activationLimit: return "This license key has reached the activation limit."
        }
    }
}
