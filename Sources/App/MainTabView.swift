import SwiftUI

@MainActor
struct MainTabView: View {
    let user: User
    @ObservedObject var session: AppSession

    var body: some View {
        TabView {
            NavigationStack {
                DiningHallsView(catalog: session.catalog)
            }
            .tabItem { Label("食堂", systemImage: "fork.knife") }

            NavigationStack {
                CommunityFeedView(service: session.community)
            }
            .tabItem { Label("社区", systemImage: "bubble.left.and.bubble.right") }

            if session.canUseAdminArea {
                NavigationStack {
                    AdminHomeView(service: session.admin)
                }
                .tabItem { Label("管理", systemImage: "shield.lefthalf.filled") }
            }

            ProfileView(user: user, session: session)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(Zine.red)
    }
}
