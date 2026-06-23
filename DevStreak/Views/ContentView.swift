import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentViewInner(modelContext: modelContext)
    }
}

/// Separate inner view so we can create the ViewModel after the
/// environment is available.
private struct ContentViewInner: View {
    @State private var vm: StreakViewModel

    init(modelContext: ModelContext) {
        _vm = State(initialValue: StreakViewModel(modelContext: modelContext))
    }

    var body: some View {
        TabView {
            DashboardView(vm: vm)
                .tabItem { Label("Today", systemImage: "flame.fill") }

            HeatMapView(vm: vm)
                .tabItem { Label("History", systemImage: "calendar.badge.clock") }

            SettingsView(vm: vm)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .overlay(alignment: .top) {
            if let msg = vm.notification {
                NotificationBanner(message: msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(duration: 0.35), value: vm.notification)
                    .padding(.top, 8)
            }
        }
    }
}

struct NotificationBanner: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.orange, in: Capsule())
            .shadow(radius: 6)
    }
}
