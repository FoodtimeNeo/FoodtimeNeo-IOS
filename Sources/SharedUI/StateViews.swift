import SwiftUI

struct LaunchStateView: View {
    @State private var slow = false

    var body: some View {
        ZStack {
            PaperBackdrop()
            VStack(spacing: 18) {
                Text("北交干饭吧")
                    .font(.system(size: 34, weight: .black, design: .serif))
                    .foregroundStyle(Zine.ink)
                ProgressView()
                    .tint(Zine.red)
                Text("正在恢复登录状态…")
                    .font(Zine.bodyFont)
                    .foregroundStyle(Zine.muted)
                if slow {
                    Text("登录状态恢复较慢，请稍候…")
                        .font(.footnote)
                        .foregroundStyle(Zine.muted)
                }
            }
            .padding(24)
        }
        .task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            slow = true
        }
    }
}

struct LoadingStateView: View {
    var message: String

    var body: some View {
        PaperCard {
            HStack(spacing: 12) {
                ProgressView().tint(Zine.red)
                Text(message)
                    .font(Zine.bodyFont)
                    .foregroundStyle(Zine.muted)
            }
        }
    }
}

struct EmptyStateView: View {
    var title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                if let message, !message.isEmpty {
                    Text(message)
                        .font(Zine.bodyFont)
                        .foregroundStyle(Zine.muted)
                }
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(InkButtonStyle())
                        .padding(.top, 4)
                }
            }
        }
    }
}

struct ErrorStateView: View {
    var message: String
    var retry: () -> Void

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("加载失败")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(message)
                    .font(Zine.bodyFont)
                    .foregroundStyle(Zine.red)
                Button("重试", action: retry)
                    .buttonStyle(InkButtonStyle(primary: true))
                    .padding(.top, 4)
            }
        }
    }
}

struct ComingSoonView: View {
    var title: String
    var detail: String

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 16) {
                    SectionHeading(index: nil, title: title, subtitle: detail)
                    PaperCard {
                        Text("该模块尚未接入。当前开发底座仅完成登录与食堂只读浏览；功能按实施波次推进，不把占位页当作已完成。")
                            .font(Zine.bodyFont)
                            .foregroundStyle(Zine.muted)
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
    }
}
