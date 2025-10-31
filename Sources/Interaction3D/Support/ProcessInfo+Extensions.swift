import Foundation

internal extension ProcessInfo {
    var debugUI: Bool {
        guard let value = environment["DEBUG_UI"] else {
            return false
        }
        let lowercased = value.lowercased()
        return lowercased == "1" || lowercased == "true" || lowercased == "yes" || lowercased == "y"
    }
}
