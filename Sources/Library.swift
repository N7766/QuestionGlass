import Foundation
import Combine

struct QuestionBank: Codable, Identifiable {
    var id = UUID()
    var name: String
    var total: Int
    var removed: Set<Int> = []
    var updated = Date()
    var remaining: Int { total - removed.count }
}

@MainActor final class Library: ObservableObject {
    @Published private(set) var banks: [QuestionBank] = []
    @Published var error: String?
    @Published private(set) var saveProblem = false
    @Published private(set) var lastRemoved: (UUID, Int)?
    let file: URL
    private var canWrite = true

    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuestionGlass/library.json")
        guard FileManager.default.fileExists(atPath: self.file.path) else { return }
        do {
            let loaded = try JSONDecoder().decode([QuestionBank].self, from: Data(contentsOf: self.file))
            guard Set(loaded.map(\.id)).count == loaded.count,
                  loaded.allSatisfy({ bank in (1...10000).contains(bank.total) && bank.removed.allSatisfy { (1...bank.total).contains($0) } }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            banks = loaded
        } catch {
            canWrite = false
            saveProblem = true
            self.error = "无法读取已保存的题库。原文件已保留，请检查：\(self.file.path)\n\(error.localizedDescription)"
        }
    }

    @discardableResult private func commit(_ next: [QuestionBank]) -> Bool {
        guard canWrite else { error = "原存档无法读取，为保护数据，已暂停写入。"; return false }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(next).write(to: file, options: .atomic)
            banks = next
            saveProblem = false
            return true
        } catch {
            saveProblem = true
            self.error = "保存失败，本次操作尚未生效：\(error.localizedDescription)"
            return false
        }
    }

    func create(name: String, total: Int) -> UUID? {
        guard (1...10000).contains(total) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let bank = QuestionBank(name: trimmed.isEmpty ? "我的题库 \(banks.count + 1)" : trimmed, total: total)
        guard commit(banks + [bank]) else { return nil }
        return bank.id
    }
    func remove(_ number: Int, from id: UUID) {
        guard let i = banks.firstIndex(where: { $0.id == id }), (1...banks[i].total).contains(number), !banks[i].removed.contains(number) else { return }
        var next = banks
        next[i].removed.insert(number)
        next[i].updated = Date()
        if commit(next) { lastRemoved = (id, number) }
    }
    func undo() {
        guard let (id, number) = lastRemoved, let i = banks.firstIndex(where: { $0.id == id }) else { return }
        var next = banks
        next[i].removed.remove(number)
        next[i].updated = Date()
        if commit(next) { lastRemoved = nil }
    }
    func delete(_ id: UUID) {
        if commit(banks.filter { $0.id != id }), lastRemoved?.0 == id { lastRemoved = nil }
    }
}
