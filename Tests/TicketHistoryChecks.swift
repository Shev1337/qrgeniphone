import Foundation

@main
struct TicketHistoryChecks {
    static func main() throws {
        let noon = Date(timeIntervalSince1970: 1_800_000_000)
        let later = noon.addingTimeInterval(3600)

        let draft = SavedItem(link: "https://example.com/qr#fragment", caption: "721BG04", title: "Тест")
        let original = draft.repeated(at: noon) { $0 }
        let repeatTicket = original.repeated(at: later) { $0 }
        let history = repeatTicket.addedToHistory(original.addedToHistory([]))
        precondition(history.count == 2)
        precondition(original.date == noon && repeatTicket.date == later)
        precondition(original.id != repeatTicket.id && original.payload != repeatTicket.payload)
        precondition(original.payload.hasSuffix("#fragment") && repeatTicket.payload.hasSuffix("#fragment"))
        precondition(history.inHistoryOrder().map(\.id) == [repeatTicket.id, original.id])

        var pinned = original
        pinned.togglePin(at: later)
        let pinnedHistory = pinned.addedToHistory(history).inHistoryOrder()
        precondition(pinnedHistory.map(\.id) == [original.id, repeatTicket.id])
        precondition(pinned.date == noon && pinned.payload == original.payload)
        precondition(pinned.repeated(at: later) { $0 }.pinnedAt == nil)
        let decodedHistory = try JSONDecoder().decode([SavedItem].self, from: JSONEncoder().encode(pinnedHistory))
        precondition(decodedHistory == pinnedHistory)
        pinned.togglePin(at: later)
        precondition(pinned.addedToHistory(history).inHistoryOrder().first?.id == repeatTicket.id)

        let raw = "https://example.com/scan?q=a%2Fb#exact"
        let scanned = SavedItem(link: raw, caption: "721BG04", title: "", date: noon, qrPayload: raw, fromScan: true)
        let rescanned = scanned.repeated(at: later) { _ in "unexpected rewrite" }
        precondition(rescanned.payload == raw && rescanned.id != scanned.id && rescanned.date == later)

        let legacy = try JSONDecoder().decode(
            SavedItem.self,
            from: Data(#"{"link":"https://example.com","caption":"721BG04"}"#.utf8)
        )
        precondition(legacy.date == nil && legacy.pinnedAt == nil && legacy.payload == legacy.link)
        print("Ticket history checks passed")
    }
}
