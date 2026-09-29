import Foundation

@main struct LibraryTests {
    @MainActor static func main() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("library.json")
        let store = Library(file: file)
        precondition(store.create(name: "bad", total: 0) == nil)
        precondition(store.create(name: "bad", total: 10001) == nil)
        let id = store.create(name: "算法 112 题", total: 112)!
        store.remove(42, from: id)
        store.remove(42, from: id)
        store.remove(113, from: id)
        precondition(store.banks[0].remaining == 111)
        let reload = Library(file: file)
        precondition(reload.banks[0].removed == [42])
        store.undo()
        precondition(Library(file: file).banks[0].remaining == 112)
        let second = store.create(name: "第二份", total: 1)!
        store.remove(1, from: second)
        precondition(store.banks[1].remaining == 0)
        store.delete(id)
        precondition(Library(file: file).banks.map(\.id) == [second])
        try Data("corrupt".utf8).write(to: file)
        let corrupted = Library(file: file)
        precondition(corrupted.error != nil)
        precondition(corrupted.create(name: "不能覆盖", total: 10) == nil)
        let preserved = try String(contentsOf: file, encoding: .utf8)
        precondition(preserved == "corrupt")
        print("PASS: range validation, remove, duplicate removal, persistence, undo, multiple banks, delete, corrupt-file protection")
    }
}
