import Foundation
import Combine

/// Handles `duetrack://` URLs from widgets (and future notification taps).
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    static let scheme = "duetrack"

    /// Bill ID waiting to be opened in the UI.
    @Published var pendingBillID: UUID?

    private init() {}

    static func billURL(for billId: UUID) -> URL? {
        URL(string: "\(scheme)://bill/\(billId.uuidString)")
    }

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == Self.scheme else { return false }

        // Supports: duetrack://bill/<uuid>
        if url.host?.lowercased() == "bill" {
            let idString = url.pathComponents
                .filter { $0 != "/" }
                .first
                ?? url.lastPathComponent

            if let id = UUID(uuidString: idString) {
                DispatchQueue.main.async {
                    self.pendingBillID = id
                }
                return true
            }
        }

        return false
    }
}
