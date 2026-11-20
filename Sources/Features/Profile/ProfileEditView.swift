import SwiftUI

@MainActor
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ProfileEditViewModel

    init(session: AppSession) {
        _model = StateObject(wrappedValue: ProfileEditViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 16) {
                        SectionHeading(
                            index: "03.0",
                            title: "编辑资料",
                            subtitle: "昵称修改后立即生效；头像上传在媒体波次接入。"
                        )
                        content
                    }
                    .padding(Zine.pagePadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                await model.loadIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.profile == nil {
            LoadingStateView(message: "正在读取资料…")
        } else if let error = model.errorMessage, model.profile == nil {
            ErrorStateView(message: error) {
                Task { await model.load() }
            }
        } else if model.didSave, let profile = model.profile {
            savedCard(profile)
        } else {
            editCard
        }
    }

    private var editCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                if let profile = model.profile {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Zine.alt)
                            Text(String(profile.displayName.prefix(1)))
                                .font(.system(size: 26, weight: .black, design: .serif))
                                .foregroundStyle(Zine.red)
                        }
                        .frame(width: 58, height: 58)
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.email)
                                .font(.footnote)
                                .foregroundStyle(Zine.muted)
                            Text("关注 \(profile.followingCount) · 粉丝 \(profile.followerCount)")
                                .font(.caption)
                                .foregroundStyle(Zine.muted)
                        }
                    }
                }

                Text("昵称")
                    .font(.footnote)
                    .foregroundStyle(Zine.muted)
                TextField("1–50 个字符", text: $model.displayName)
                    .modifier(FormInputStyle())

                if let error = model.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                }

                Button {
                    Task { await model.save() }
                } label: {
                    if model.isSaving {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("保存")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(model.isSaving)

                Text("当前只支持修改昵称；保存时会带上现有头像引用，不会清除头像。头像上传/裁剪将在媒体波次接入。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    private func savedCard(_ profile: UserProfile) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("资料已更新")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("昵称已保存为“\(profile.displayName)”。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Button("完成") { dismiss() }
                    .buttonStyle(InkButtonStyle(primary: true))
            }
        }
    }
}
