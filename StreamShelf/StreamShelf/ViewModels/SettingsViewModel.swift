import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    enum ConnectionStatus {
        case idle
        case testing
        case success(Int)
        case failure(String)

        var isLoading: Bool {
            if case .testing = self { return true }
            return false
        }
    }

    @Published var baseURL: String = ""
    @Published var token: String = ""
    @Published var sections: [PlexLibrarySection] = []
    @Published var selectedSectionKey: String = ""
    @Published var connectionStatus: ConnectionStatus = .idle
    @Published var didSave = false

    var errorMessage: String? {
        if case .failure(let msg) = connectionStatus { return msg }
        return nil
    }

    var canSave: Bool {
        !trimmedBaseURL.isEmpty && baseURLValidationMessage == nil && !trimmedToken.isEmpty
    }

    var baseURLValidationMessage: String? {
        guard !trimmedBaseURL.isEmpty else { return nil }
        guard
            let components = URLComponents(string: normalizedBaseURL),
            let scheme = components.scheme?.lowercased(),
            (scheme == "http" || scheme == "https"),
            components.host?.isEmpty == false
        else {
            return "Enter a full server address, including http:// or https://."
        }

        return nil
    }

    var baseURLSecurityMessage: String? {
        guard
            let components = URLComponents(string: normalizedBaseURL),
            components.scheme?.lowercased() == "http",
            let host = components.host,
            !Self.isLocalHost(host)
        else {
            return nil
        }

        return "Remote HTTP sends your token without encryption. Use HTTPS for off-network access before App Store release."
    }

    private var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private let config: PlexConfig
    private let api: PlexAPIClient

    init(config: PlexConfig = .shared, api: PlexAPIClient = .shared) {
        self.config = config
        self.api = api
        self.baseURL = config.baseURL
        self.token = config.token
        self.selectedSectionKey = config.librarySectionKey
    }

    func save() {
        config.baseURL = trimmedBaseURL
        config.token = trimmedToken
        config.librarySectionKey = selectedSectionKey
        didSave = true
    }

    func loadSections() async {
        guard canSave else {
            connectionStatus = .failure(baseURLValidationMessage ?? "Enter a base URL and token first.")
            return
        }

        connectionStatus = .testing
        do {
            let connection = PlexConnection(baseURL: normalizedBaseURL, token: trimmedToken)
            sections = try await api.fetchLibrarySections(connection: connection)
            connectionStatus = .success(sections.count)

            if selectedSectionKey.isEmpty || !sections.contains(where: { $0.key == selectedSectionKey }) {
                selectedSectionKey = sections.first(where: \.isVideoSection)?.key ?? sections.first?.key ?? ""
            }
        } catch {
            sections = []
            connectionStatus = .failure((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    private var normalizedBaseURL: String {
        trimmedBaseURL.hasSuffix("/") ? String(trimmedBaseURL.dropLast()) : trimmedBaseURL
    }

    private static func isLocalHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        if normalized == "localhost" || normalized.hasSuffix(".local") {
            return true
        }

        if normalized.hasPrefix("192.168.") || normalized.hasPrefix("10.") || normalized.hasPrefix("169.254.") {
            return true
        }

        if normalized.hasPrefix("172.") {
            let parts = normalized.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), (16...31).contains(second) {
                return true
            }
        }

        return normalized == "::1" || normalized.hasPrefix("fe80:")
    }
}
