import Foundation

struct Volume: Hashable {
    let name: String
    let path: String
}

enum ProcessSafety {
    case safe
    case unsafe
    case unknown
}

struct ProcessDescriptor {
    let names: [String]
    let category: String
    let safety: ProcessSafety
    let notes: String

    var primaryName: String {
        return names.first ?? ""
    }
}

struct ProcessInfo {
    let name: String
    let pid: Int
}
