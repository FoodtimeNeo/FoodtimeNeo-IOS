import SwiftUI

@MainActor
struct AppealOnlyView: View {
    let user: User
    @ObservedObject var session: AppSession
    @State private var confirmLogout = false

    var body: some View {
        RestrictedAppealsView(
            user: user,
            service: session.reports,
            submissions: session.submissions,
            drafts: session.appealDrafts
        ) {
            confirmLogout = true
        }
        .alert("退出登录？", isPresented: $confirmLogout) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) {
                Task { await session.logout() }
            }
        }
    }
}
