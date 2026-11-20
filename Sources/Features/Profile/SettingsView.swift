import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: SettingsViewModel
    @State private var confirmClear = false

    init(
        cache: MediaCacheManaging = URLCacheMediaCache(),
        version: AppVersionInfo = .current()
    ) {
        _model = StateObject(
            wrappedValue: SettingsViewModel(cache: cache, version: version)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "05.2",
                            title: "设置与更新",
                            subtitle: "版本、图片缓存与平台分发说明。"
                        )
                        versionCard
                        cacheCard
                        updateCard
                        if let info = model.infoMessage, !info.isEmpty {
                            Text(info)
                                .font(.footnote)
                                .foregroundStyle(Zine.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let error = model.errorMessage, !error.isEmpty {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(Zine.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(Zine.pagePadding)
                }
            }
            .navigationTitle("设置与更新")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.loadCache() }
            .alert("清理图片缓存？", isPresented: $confirmClear) {
                Button("取消", role: .cancel) {}
                Button("清理", role: .destructive) {
                    Task { await model.clearCache() }
                }
            } message: {
                Text("已缓存的图片需要重新加载；不会影响账号、草稿或已提交内容。")
            }
        }
    }

    private var versionCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("版本")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(model.version.display)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Zine.ink)
                Text("测试阶段后缀只用于展示与分发渠道；不代表已获得发布授权。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cacheCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("图片缓存")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(model.cacheText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Zine.ink)
                Button {
                    confirmClear = true
                } label: {
                    if model.isClearing {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("清理图片缓存")
                    }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(model.isClearing)
                Text("清理只影响本机图片/网络缓存，不删除草稿、投稿或账号数据。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var updateCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("更新方式")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("iOS 不能像 Android APK 一样从网页下载并长期安装 IPA。TestFlight、App Store 或单位分发/MDM 尚未确认，因此本版本不提供站内更新检查与下载入口，避免把不可用流程当成已完成。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Text("分发方式确定后再接入对应渠道的版本检查；后端版本号不等同线上部署版本。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
