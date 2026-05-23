import SwiftUI

struct PickerView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedID: Int64?
    @FocusState private var searchFocused: Bool

    let onSelect: (ClipItem) -> Void
    let onCopyOnly: (ClipItem) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard…", text: $state.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($searchFocused)
                    .onSubmit { pasteSelected() }
                Text("\(state.searchResults.count)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.thinMaterial)

            Divider()

            if state.searchResults.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text(state.searchQuery.isEmpty
                         ? "Nothing copied yet"
                         : "No matches")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(selection: $selectedID) {
                        ForEach(state.searchResults) { item in
                            ItemRow(
                                item: item,
                                isSelected: item.id == selectedID
                            )
                            .tag(item.id)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { onSelect(item) }
                            .onTapGesture { selectedID = item.id }
                            .contextMenu {
                                Button("Paste") { onSelect(item) }
                                Button("Copy to clipboard") { onCopyOnly(item) }
                                Divider()
                                Button(item.isStarred ? "Unstar" : "Star") {
                                    state.toggleStar(item: item)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    state.delete(item: item)
                                }
                            }
                            .id(item.id)
                        }
                    }
                    .listStyle(.plain)
                    .onChange(of: selectedID) { newValue in
                        if let newValue { proxy.scrollTo(newValue, anchor: .center) }
                    }
                    .onChange(of: state.searchResults) { items in
                        if selectedID == nil || !items.contains(where: { $0.id == selectedID }) {
                            selectedID = items.first?.id
                        }
                    }
                    .onAppear {
                        selectedID = state.searchResults.first?.id
                    }
                }
            }

            Divider()
            HStack(spacing: 16) {
                Label("Paste", systemImage: "return")
                    .labelStyle(.titleAndIcon)
                Label("Copy only ⌥↩", systemImage: "doc.on.doc")
                Spacer()
                Label("Close ⎋", systemImage: "escape")
                Text("⌘F star  ⌘⌫ delete")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(8)
            .background(.thinMaterial)
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 320, idealHeight: 440)
        .background(KeyEventHandling(
            onUp:    { moveSelection(by: -1) },
            onDown:  { moveSelection(by:  1) },
            onEnter: { pasteSelected(option: false) },
            onAltEnter: { pasteSelected(option: true) },
            onEsc:   { onClose() },
            onStar:  { if let item = currentItem() { state.toggleStar(item: item) } },
            onDelete:{ if let item = currentItem() { state.delete(item: item) } }
        ))
        .onAppear { searchFocused = true }
    }

    private func currentItem() -> ClipItem? {
        state.searchResults.first(where: { $0.id == selectedID })
    }

    private func moveSelection(by delta: Int) {
        let items = state.searchResults
        guard !items.isEmpty else { return }
        let idx = items.firstIndex(where: { $0.id == selectedID }) ?? -1
        let next = max(0, min(items.count - 1, idx + delta))
        selectedID = items[next].id
    }

    private func pasteSelected(option: Bool = false) {
        if let item = currentItem() {
            if option { onCopyOnly(item) } else { onSelect(item) }
        }
    }
}

/// Catches arrow keys, return, escape inside the picker.
struct KeyEventHandling: NSViewRepresentable {
    let onUp: () -> Void
    let onDown: () -> Void
    let onEnter: () -> Void
    let onAltEnter: () -> Void
    let onEsc: () -> Void
    let onStar: () -> Void
    let onDelete: () -> Void

    func makeNSView(context: Context) -> NSView {
        let v = KeyView()
        v.onUp = onUp
        v.onDown = onDown
        v.onEnter = onEnter
        v.onAltEnter = onAltEnter
        v.onEsc = onEsc
        v.onStar = onStar
        v.onDelete = onDelete
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class KeyView: NSView {
        var onUp: (() -> Void)?
        var onDown: (() -> Void)?
        var onEnter: (() -> Void)?
        var onAltEnter: (() -> Void)?
        var onEsc: (() -> Void)?
        var onStar: (() -> Void)?
        var onDelete: (() -> Void)?

        private var monitor: Any?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                installMonitorIfNeeded()
            } else {
                removeMonitor()
            }
        }

        private func installMonitorIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                guard self.window?.isKeyWindow == true else { return event }
                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                switch event.keyCode {
                case 126: self.onUp?(); return nil           // ↑
                case 125: self.onDown?(); return nil         // ↓
                case 36, 76:                                  // ↩ / numeric Enter
                    if flags.contains(.option) { self.onAltEnter?() }
                    else { self.onEnter?() }
                    return nil
                case 53: self.onEsc?(); return nil           // ⎋
                case 3:                                       // F
                    if flags.contains(.command) { self.onStar?(); return nil }
                case 51:                                      // ⌫
                    if flags.contains(.command) { self.onDelete?(); return nil }
                default: break
                }
                return event
            }
        }

        private func removeMonitor() {
            if let m = monitor {
                NSEvent.removeMonitor(m)
                monitor = nil
            }
        }

        deinit { removeMonitor() }
    }
}
