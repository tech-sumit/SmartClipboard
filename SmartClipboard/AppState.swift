import Foundation
import AppKit
import SwiftUI
import Combine

/// App-wide observable state. Backs the picker, menu, settings UI.
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var recentItems: [ClipItem] = []
    @Published var searchQuery: String = ""
    @Published var searchResults: [ClipItem] = []
    @Published var hotkeyDescription: String = ""

    private var cancellables = Set<AnyCancellable>()

    init() {
        refresh()
        updateHotkeyDescription()

        $searchQuery
            .debounce(for: .milliseconds(80), scheduler: DispatchQueue.main)
            .sink { [weak self] q in
                self?.runSearch(q)
            }
            .store(in: &cancellables)
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items = (try? ClipRepository.shared.recent(limit: 500)) ?? []
            DispatchQueue.main.async {
                self?.recentItems = items
                if self?.searchQuery.isEmpty == true {
                    self?.searchResults = items
                }
            }
        }
    }

    func runSearch(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let items: [ClipItem]
            if trimmed.isEmpty {
                items = (try? ClipRepository.shared.recent(limit: 500)) ?? []
            } else {
                items = (try? ClipRepository.shared.search(trimmed, limit: 200)) ?? []
            }
            DispatchQueue.main.async {
                self?.searchResults = items
            }
        }
    }

    func toggleStar(item: ClipItem) {
        guard let id = item.id else { return }
        try? ClipRepository.shared.toggleStar(id: id)
        refresh()
    }

    func delete(item: ClipItem) {
        guard let id = item.id else { return }
        try? ClipRepository.shared.delete(id: id)
        refresh()
    }

    func updateHotkeyDescription() {
        hotkeyDescription = HotkeyUtil.description(
            keyCode: Preferences.hotkeyKeyCode,
            modifiers: Preferences.hotkeyModifiers
        )
    }
}
