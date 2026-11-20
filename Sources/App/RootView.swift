import SwiftUI

@MainActor
struct RootView: View {
    @StateObject private var session: AppSession

    init() {
        _session = StateObject(wrappedValue: AppSession.live())
    }

    var body: some View {
        Group {
            switch session.state {
            case .launching:
                LaunchStateView()
            case .signedOut:
                LoginView(session: session)
            case .signedIn(let user):
                MainTabView(user: user, session: session)
            case .appealOnly(let user):
                AppealOnlyView(user: user, session: session)
            case .unavailable(let message):
                UnavailableView(message: message) {
                    Task { await session.start() }
                }
            }
        }
        .environmentObject(session)
        .task {
            await session.start()
        }
    }
}

private struct UnavailableView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeading(
                        index: nil,
                        title: "暂时连不上服务",
                        subtitle: "已保留本机会话，不会把你当成已登录或已退出。"
                    )
                    ErrorStateView(message: message, retry: retry)
                }
                .padding(Zine.pagePadding)
            }
        }
    }
}
