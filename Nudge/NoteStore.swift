import Foundation
import Combine

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var created = Date()
    var edited = Date()
    var pinned = false
}

final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []

    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Nudge", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("notes.json")
        load()
    }

    var sorted: [Note] {
        notes.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.created > b.created
        }
    }

    @discardableResult
    func add(_ text: String) -> Note? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let note = Note(text: text)
        notes.append(note)
        persist()
        return note
    }

    func update(_ id: UUID, text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].text = text
        notes[i].edited = Date()
        persist()
    }

    func togglePin(_ id: UUID) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].pinned.toggle()
        persist()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        notes = (try? decoder.decode([Note].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(notes) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
