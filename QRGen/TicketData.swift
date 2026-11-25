import Foundation

let receiptAmountTenge = 80

struct SavedItem: Codable, Identifiable, Equatable {
    var id: UUID
    var link: String
    var caption: String
    var title: String
    var date: Date?
    var qrPayload: String?
    var fromScan: Bool
    var pinnedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id, link, caption, title, date, qrPayload, fromScan, pinnedAt
    }

    init(
        id: UUID = UUID(),
        link: String,
        caption: String,
        title: String,
        date: Date? = Date(),
        qrPayload: String? = nil,
        fromScan: Bool = false,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.link = link
        self.caption = caption
        self.title = title
        self.date = date
        self.qrPayload = qrPayload
        self.fromScan = fromScan
        self.pinnedAt = pinnedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        link = (try? container.decode(String.self, forKey: .link)) ?? ""
        caption = (try? container.decode(String.self, forKey: .caption)) ?? ""
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        date = try? container.decode(Date.self, forKey: .date)
        qrPayload = try? container.decode(String.self, forKey: .qrPayload)
        fromScan = (try? container.decode(Bool.self, forKey: .fromScan)) ?? false
        pinnedAt = try? container.decode(Date.self, forKey: .pinnedAt)
    }

    var payload: String { qrPayload ?? link }

    func addedToHistory(_ items: [SavedItem]) -> [SavedItem] {
        [self] + items.filter { $0.id != id }
    }

    func repeated(at now: Date = Date(), formatManualPayload: (String) -> String) -> SavedItem {
        let newID = UUID()
        return SavedItem(
            id: newID,
            link: link,
            caption: caption,
            title: title,
            date: now,
            qrPayload: fromScan ? payload : formatManualPayload(makeTicketPayload(link, id: newID)),
            fromScan: fromScan
        )
    }

    mutating func togglePin(at now: Date = Date()) {
        pinnedAt = pinnedAt == nil ? now : nil
    }
}

extension Array where Element == SavedItem {
    func inHistoryOrder() -> [SavedItem] {
        sorted { lhs, rhs in
            let leftPin = lhs.pinnedAt ?? .distantPast
            let rightPin = rhs.pinnedAt ?? .distantPast
            if leftPin != rightPin { return leftPin > rightPin }
            return (lhs.date ?? .distantPast) > (rhs.date ?? .distantPast)
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
