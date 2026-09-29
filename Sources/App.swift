import SwiftUI
import AppKit

private func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
    Color(nsColor: NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light })
}
private let ink = Color.primary
private let teal = adaptive(NSColor(red: 0.10, green: 0.43, blue: 0.40, alpha: 1), NSColor(red: 0.40, green: 0.88, blue: 0.76, alpha: 1))
private let panel = adaptive(.white.withAlphaComponent(0.23), .white.withAlphaComponent(0.035))
private let edge = adaptive(.white.withAlphaComponent(0.65), .white.withAlphaComponent(0.09))
private let tileFill = adaptive(.white.withAlphaComponent(0.58), .white.withAlphaComponent(0.055))

@main struct QuestionGlassApp: App {
    @StateObject private var library = Library()
    init() {
        if let url = Bundle.main.url(forResource: "QuestionGlassIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) {
            NSApplication.shared.applicationIconImage = icon
        }
    }
    var body: some Scene {
        Window("拾题", id: "main") {
            ContentView().environmentObject(library)
                .frame(minWidth: 760, minHeight: 600)

        }
        .defaultSize(width: 1080, height: 790)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {
                Button("撤销移除") { library.undo() }
                    .keyboardShortcut("z").disabled(library.lastRemoved == nil)
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var library: Library
    @AppStorage("nightMode") private var nightMode = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var window: NSWindow?
    @State private var selected: UUID?
    @State private var creating = false
    @State private var deleting: QuestionBank?
    @State private var search = ""
    var bank: QuestionBank? { library.banks.first { $0.id == selected } }

    var body: some View {
        ZStack {
            LinearGradient(colors: nightMode ? [Color(red: 0.035, green: 0.07, blue: 0.085), Color(red: 0.055, green: 0.09, blue: 0.105), Color(red: 0.06, green: 0.075, blue: 0.12)] : [Color(red: 0.89, green: 0.95, blue: 0.94), Color(red: 0.96, green: 0.96, blue: 0.92), Color(red: 0.90, green: 0.94, blue: 0.97)], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Circle().fill(Color.mint.opacity(nightMode ? 0.065 : 0.25)).frame(width: 490).blur(radius: 75).offset(x: -170, y: 120)
                Circle().fill((nightMode ? Color.indigo : Color.orange).opacity(nightMode ? 0.12 : 0.16)).frame(width: 400).blur(radius: 85).offset(x: geo.size.width - 370, y: -190)
            }.allowsHitTesting(false)
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    WindowControl(symbol: "xmark", color: .red, label: "关闭") { window?.performClose(nil) }
                    WindowControl(symbol: "minus", color: .yellow, label: "最小化") { window?.miniaturize(nil) }
                    WindowControl(symbol: "arrow.up.left.and.arrow.down.right", color: .green, label: "全屏") { window?.toggleFullScreen(nil) }
                    Spacer()
                    Button { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { nightMode.toggle() } } label: {
                        Image(systemName: nightMode ? "sun.max" : "moon").font(.system(size: 15)).contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 28)
                    }.buttonStyle(.plain).foregroundStyle(teal).accessibilityLabel(nightMode ? "切换日间模式" : "切换夜间模式")
                }.padding(.horizontal, 25).frame(height: 54)
                ZStack {
                    if let bank { detail(bank).id(bank.id).transition(.opacity.combined(with: .offset(x: reduceMotion ? 0 : 18))) }
                    else { collection.transition(.opacity.combined(with: .offset(x: reduceMotion ? 0 : -18))) }
                }.padding(.horizontal, 32).padding(.top, 12).padding(.bottom, 28)
            }
        }
        .ignoresSafeArea()
        .background(WindowBridge { window = $0 })
        .preferredColorScheme(nightMode ? .dark : .light)
        .foregroundStyle(ink)
        .tint(teal)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88), value: selected)
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86), value: library.banks.map { $0.remaining })
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: search)
        .sheet(isPresented: $creating) {
            CreateBankView { name, total in
                if let id = library.create(name: name, total: total) {
                    selected = id; search = ""; creating = false
                }
            }
        }
        .alert("删除这个题库？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除题库", role: .destructive) {
                if let deleting { library.delete(deleting.id) }
                deleting = nil
            }
        } message: { Text("“\(deleting?.name ?? "")”及其刷题进度将被永久删除。此操作无法撤销。") }
        .alert("存档提示", isPresented: Binding(get: { library.error != nil }, set: { if !$0 { library.error = nil } })) {
            Button("知道了") { library.error = nil }
        } message: { Text(library.error ?? "") }
    }

    private var collection: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("题库").font(.system(size: 34, weight: .semibold))
                }
                Spacer()
                Button { creating = true } label: { Label("新建题库", systemImage: "plus").padding(.horizontal, 9).padding(.vertical, 6) }
                    .buttonStyle(.glassProminent)
            }
            if library.banks.isEmpty {
                VStack(spacing: 17) {
                    Image(systemName: "square.grid.3x3").font(.system(size: 46, weight: .ultraLight)).foregroundStyle(teal)
                        .frame(width: 94, height: 94).glassEffect(.regular, in: .rect(cornerRadius: 28))
                    Button("新建题库") { creating = true }.buttonStyle(.glassProminent).controlSize(.large).padding(.top, 6)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(panel, in: RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(edge))
            } else {
                ScrollView {
                    LazyVStack(spacing: 13) {
                        ForEach(library.banks) { bank in
                            HStack(spacing: 18) {
                                Button { selected = bank.id; search = "" } label: {
                                    HStack(spacing: 18) {
                                        Image(systemName: "square.stack.3d.up").font(.system(size: 22)).foregroundStyle(teal)
                                            .frame(width: 52, height: 52).background(teal.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                                        VStack(alignment: .leading, spacing: 7) {
                                            Text(bank.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                                            Text("共 \(bank.total) 道 · 已移除 \(bank.removed.count) 道").font(.system(size: 12)).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 7) {
                                            Text("剩余 \(bank.remaining)").font(.system(size: 14, weight: .medium)).foregroundStyle(teal)
                                            ProgressView(value: Double(bank.removed.count), total: Double(bank.total)).frame(width: 110)
                                        }
                                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.tertiary)
                                    }.padding(.vertical, 22).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityLabel("打开\(bank.name)，剩余\(bank.remaining)道")
                                Divider().frame(height: 30)
                                Button(role: .destructive) { deleting = bank } label: { Image(systemName: "trash").frame(width: 30, height: 34) }
                                    .buttonStyle(.borderless).help("删除题库").accessibilityLabel("删除\(bank.name)")
                            }.padding(.horizontal, 22).glassEffect(.regular, in: .rect(cornerRadius: 23))
                        }
                    }.padding(.horizontal, 3).padding(.vertical, 10)
                }.scrollClipDisabled()
            }
        }.frame(maxHeight: .infinity)
    }

    private func detail(_ bank: QuestionBank) -> some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack(alignment: .center, spacing: 16) {
                Button { selected = nil; search = "" } label: { Image(systemName: "arrow.left").frame(width: 30, height: 30) }
                    .buttonStyle(.glass).help("返回题库列表").accessibilityLabel("返回题库列表")
                VStack(alignment: .leading, spacing: 6) {
                    Text(bank.name).font(.system(size: 30, weight: .semibold)).lineLimit(1)
                }
                Spacer()
                Text("\(Int(Double(bank.removed.count) / Double(bank.total) * 100))%")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(teal)
                    .padding(.horizontal, 15).padding(.vertical, 10).glassEffect(.regular, in: .capsule)
            }
            HStack(spacing: 0) {
                metric("剩余题目", value: bank.remaining, accent: true)
                Divider().frame(height: 47)
                metric("已移除", value: bank.removed.count)
                Divider().frame(height: 47)
                metric("题目总数", value: bank.total)
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: Double(bank.removed.count), total: Double(bank.total))
                }.frame(width: 220).padding(.horizontal, 28)
            }.padding(.vertical, 22).glassEffect(.regular, in: .rect(cornerRadius: 24))
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(teal)
                    TextField("题号", text: $search).textFieldStyle(.plain)
                        .accessibilityLabel("搜索题号")
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain).accessibilityLabel("清空搜索")
                    }
                }.padding(14).glassEffect(.regular, in: .rect(cornerRadius: 15))
                Button { library.undo() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 30, height: 30) }
                    .buttonStyle(.glass).accessibilityLabel("撤销移除").disabled(library.lastRemoved?.0 != bank.id)
            }
            HStack {
                Text(search.isEmpty ? "待完成题目" : "查找结果").font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            ScrollView {
                if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if bank.remaining == 0 { message("已完成", subtitle: "", symbol: "checkmark.seal") }
                    else { grid(bank, numbers: (1...bank.total).filter { !bank.removed.contains($0) }) }
                } else if let number = Int(search.trimmingCharacters(in: .whitespacesAndNewlines)), (1...bank.total).contains(number) {
                    if bank.removed.contains(number) { message("第 \(number) 题已移除", subtitle: "", symbol: "checkmark.circle") }
                    else {
                        VStack(alignment: .leading, spacing: 15) {
                            Label("第 \(number) 题", systemImage: "checkmark.circle.fill").font(.system(size: 13)).foregroundStyle(teal)
                            grid(bank, numbers: [number])
                        }
                    }
                } else { message("没有这个题号", subtitle: "1–\(bank.total)", symbol: "magnifyingglass") }
            }.padding(18).background(panel, in: RoundedRectangle(cornerRadius: 23))
                .overlay(RoundedRectangle(cornerRadius: 23).stroke(edge))
        }.frame(maxHeight: .infinity)
    }

    private func metric(_ title: String, value: Int, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
            Text("\(value)").font(.system(size: 33, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(accent ? teal : ink).contentTransition(.numericText())
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 28)
    }
    private func grid(_ bank: QuestionBank, numbers: [Int]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 11)], spacing: 11) {
            ForEach(numbers, id: \.self) { number in
                NumberTile(number: number) { library.remove(number, from: bank.id) }
                    .transition(.scale(scale: reduceMotion ? 1 : 0.65).combined(with: .opacity))
            }
        }.padding(3)
    }
    private func message(_ title: String, subtitle: String, symbol: String) -> some View {
        VStack(spacing: 13) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(teal)
            Text(title).font(.system(size: 19, weight: .medium))
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity).padding(.vertical, 55)
    }
}

struct NumberTile: View {
    let number: Int
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Text("\(number)").font(.system(size: 18, weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(hovering ? teal : ink.opacity(0.85))
                .frame(maxWidth: .infinity).frame(height: 55)
                .background(hovering ? teal.opacity(0.14) : tileFill, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(hovering ? teal.opacity(0.4) : edge, lineWidth: 1))
                .shadow(color: teal.opacity(0.04), radius: 5, y: 3)
                .scaleEffect(hovering && !reduceMotion ? 1.045 : 1)
        }.buttonStyle(TilePressStyle()).onHover { hovering = $0 }.animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: hovering)
            .help("移除第 \(number) 题").accessibilityLabel("移除第\(number)题")
    }
}

struct CreateBankView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var count = "112"
    let create: (String, Int) -> Void
    var total: Int? { Int(count.trimmingCharacters(in: .whitespacesAndNewlines)) }
    var valid: Bool { total.map { (1...10000).contains($0) } ?? false }
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            Image(systemName: "square.grid.3x3.fill").font(.system(size: 27)).foregroundStyle(teal)
            VStack(alignment: .leading, spacing: 8) {
                Text("新建题库").font(.system(size: 25, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("题库名称（选填）").font(.system(size: 12, weight: .medium))
                TextField("题库名称", text: $name).textFieldStyle(.roundedBorder).controlSize(.large)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("题目总数").font(.system(size: 12, weight: .medium))
                TextField("112", text: $count).textFieldStyle(.roundedBorder).controlSize(.large).accessibilityLabel("题目总数")
                Text(valid ? "" : "1–10,000")
                    .font(.system(size: 12)).foregroundStyle(valid ? Color.secondary : .red)
            }
            HStack {
                Button("取消") { dismiss() }.buttonStyle(.glass).keyboardShortcut(.cancelAction)
                Spacer()
                Button("创建题库") { if let total, valid { create(name, total) } }
                    .buttonStyle(.glassProminent).keyboardShortcut(.defaultAction).disabled(!valid)
            }.controlSize(.large)
        }.padding(34).frame(width: 430).foregroundStyle(ink).tint(teal)
    }
}

struct TilePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.90 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct WindowControl: View {
    let symbol: String
    let color: Color
    let label: String
    let action: () -> Void
    @State private var hovered = false
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
                .foregroundStyle(hovered ? color : Color.secondary.opacity(0.8))
                .frame(width: 24, height: 24)
                .background(hovered ? color.opacity(0.16) : Color.primary.opacity(0.045), in: Circle())
        }.buttonStyle(TilePressStyle()).onHover { hovered = $0 }.accessibilityLabel(label)
    }
}

struct WindowBridge: NSViewRepresentable {
    let resolved: (NSWindow) -> Void
    func makeNSView(context: Context) -> NSView { let view = Hook(); view.resolved = resolved; return view }
    func updateNSView(_ nsView: NSView, context: Context) {}
    final class Hook: NSView {
        var resolved: ((NSWindow) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            DispatchQueue.main.async { [weak self, weak window] in
                if let window { self?.resolved?(window) }
            }
        }
    }
}
