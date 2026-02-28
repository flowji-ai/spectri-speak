import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case models = "Models"
    case dictionary = "Dictionary"
    case history = "History"
    case aiRefine = "AI Refine"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .models: return "waveform"
        case .dictionary: return "character.book.closed"
        case .history: return "clock.arrow.circlepath"
        case .aiRefine: return "sparkles"
        }
    }
}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    var modelManager: ModelManager?

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 750, minHeight: 500)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .general:
            GeneralSettingsView()
        case .models:
            ModelsSettingsView(modelManager: modelManager)
        case .dictionary:
            DictionarySettingsView()
                .environmentObject(AppState.shared.dictionaryState)
        case .history:
            HistorySettingsView()
                .environmentObject(AppState.shared.historyState)
        case .aiRefine:
            AIRefineSettingsView()
        }
    }
}
