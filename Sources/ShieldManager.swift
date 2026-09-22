import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class ShieldManager: ObservableObject {
    @Published var isAuthorized = false
    @Published var isLocked: Bool {
        didSet { UserDefaults.standard.set(isLocked, forKey: "brickclone.isLocked") }
    }
    @Published var selection = FamilyActivitySelection()

    private let store = ManagedSettingsStore()
    private let selectionKey = "brickclone.selection"

    init() {
        isLocked = UserDefaults.standard.bool(forKey: "brickclone.isLocked")
        loadSelection()
        if isLocked { applyShield() }
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            print("FamilyControls authorization failed: \(error)")
            isAuthorized = false
        }
    }

    func saveSelection(_ newSelection: FamilyActivitySelection) {
        selection = newSelection
        if let data = try? JSONEncoder().encode(newSelection) {
            UserDefaults.standard.set(data, forKey: selectionKey)
        }
        if isLocked { applyShield() } // keep an active lock in sync if the picker changes
    }

    private func loadSelection() {
        guard let data = UserDefaults.standard.data(forKey: selectionKey),
              let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        selection = decoded
    }

    func lock() {
        applyShield()
        isLocked = true
    }

    func unlock() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isLocked = false
    }

    func toggle() {
        isLocked ? unlock() : lock()
    }

    private func applyShield() {
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
    }
}
