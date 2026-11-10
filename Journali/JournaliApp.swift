import SwiftUI

@main
struct JournaliApp: App {
    @StateObject private var journal = JournalViewModel()

    var body: some Scene {
        WindowGroup {
            JournaliRootView(journal: journal)
                .preferredColorScheme(.dark)
                .tint(JournalPalette.action)
        }
    }
}




private struct JournaliRootView: View {
    let journal: JournalViewModel
    @State private var showSplash = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            JournalPalette.background.ignoresSafeArea()

            if showSplash {
                splash.transition(.opacity)
            } else {
                JournalHomeView(journal: journal)
                    .transition(.opacity)
            }
        }
        .task {
            guard showSplash else { return }
            do {
                try await Task.sleep(for: .milliseconds(850))
            } catch {
                return
            }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.23)) {
                showSplash = false
            }
        }
    }

    private var splash: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(red: 0.065, green: 0.065, blue: 0.09)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 8) {
                Image("SplashNotebook")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 106, height: 106)
                    .padding(.bottom, 10)
                    .accessibilityHidden(true)

                Text("Journali")
                    .journalFont(.display)
                    .foregroundStyle(JournalPalette.primaryText)
                    .accessibilityAddTraits(.isHeader)

                Text("Your thoughts, your story")
                    .journalFont(.supporting)
                    .foregroundStyle(JournalPalette.secondaryText)
            }
            .multilineTextAlignment(.center)
            .padding(24)
        }
    }
}
