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

            ProfileView(user: user, session: session)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(Zine.red)
    }
}
