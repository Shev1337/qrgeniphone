import Foundation

struct SavedItem: Codable, Identifiable, Equatable {
    var id: UUID
    var link: String
    var caption: String
    var title: String
    var date: Date
    var qrPayload: String?
    var fromScan: Bool

    private enum CodingKeys: String, CodingKey {
        case id, link, caption, title, date, qrPayload, fromScan
    }

    init(
        id: UUID = UUID(),
        link: String,
        caption: String,
        title: String,
        date: Date = Date(),
        qrPayload: String? = nil,
        fromScan: Bool = false
    ) {
        self.id = id
        self.link = link
        self.caption = caption
        self.title = title
        self.date = date
        self.qrPayload = qrPayload
        self.fromScan = fromScan
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        link = (try? container.decode(String.self, forKey: .link)) ?? ""
        caption = (try? container.decode(String.self, forKey: .caption)) ?? ""
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        date = (try? container.decode(Date.self, forKey: .date)) ?? Date()
        qrPayload = try? container.decode(String.self, forKey: .qrPayload)
        fromScan = (try? container.decode(Bool.self, forKey: .fromScan)) ?? false
    }

    var payload: String { qrPayload ?? link }

    func addedToHistory(_ items: [SavedItem]) -> [SavedItem] {
        [self] + items.filter { item in
            item.id != id && !(item.link == link && item.title == title
                && item.caption.caseInsensitiveCompare(caption) == .orderedSame)
        }
    }
}

private let busNumberPattern = try! NSRegularExpression(
    pattern: #"(?<![\p{L}\p{N}])([0-9]{3})[\p{Zs}\p{Pd}\t]*([A-Za-z]{2,3})[\p{Zs}\p{Pd}\t]*([0-9]{2})(?![\p{L}\p{N}])"#
)

private func busNumber(in text: String, match: NSTextCheckingResult) -> String {
    let source = text as NSString
    let digits = source.substring(with: match.range(at: 1))
    let letters = source.substring(with: match.range(at: 2))
    let region = source.substring(with: match.range(at: 3))
    return digits + letters.uppercased() + region
}

func findBusNumber(in text: String) -> String? {
    let matches = busNumberPattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
    let numbers = Set(matches.map { busNumber(in: text, match: $0) })
    return numbers.count == 1 ? numbers.first : nil
}

func normalizeBusNumber(_ text: String) -> String? {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let range = NSRange(trimmed.startIndex..., in: trimmed)
    guard let match = busNumberPattern.firstMatch(in: trimmed, range: range), match.range == range else {
        return nil
    }
    return busNumber(in: trimmed, match: match)
}

func makeTicketPayload(_ input: String, id: UUID) -> String {
    guard let url = URLComponents(string: input), let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https", url.host != nil else {
        return input
    }
    let fragmentStart = input.firstIndex(of: "#") ?? input.endIndex
    let address = input[..<fragmentStart]
    let separator = address.last == "?" || address.last == "&" ? "" : (address.contains("?") ? "&" : "?")
    return "\(address)\(separator)ticket_id=\(id.uuidString)\(input[fragmentStart...])"
}

struct ScanNumberConsensus {
    private var lastPayload: String?
    private var lastNumber: String?
    private var lastTime: TimeInterval = 0
    private var matches = 0

    mutating func isStable(payload: String, number: String, now: TimeInterval) -> Bool {
        if lastPayload == payload, lastNumber == number, now - lastTime <= 1.5 {
            // Avoid counting several callbacks for the same frame.
            guard now - lastTime >= 0.1 else { return false }
            matches += 1
        } else {
            matches = 1
        }
        lastPayload = payload
        lastNumber = number
        lastTime = now
        return matches >= 3
    }
}

struct ScanReading {
    let payload: String
    let number: String?
    var candidates: [String] = []
}
