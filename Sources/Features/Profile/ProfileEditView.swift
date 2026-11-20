import SwiftUI
import UIKit

@MainActor
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ProfileEditViewModel
    @State private var showPicker = false
    @State private var cropImage: CropImage?
    private let avatar: AvatarService
    private let mediaBaseURL: URL

    init(session: AppSession) {
        _model = StateObject(wrappedValue: ProfileEditViewModel(session: session))
        avatar = session.avatar
        mediaBaseURL = session.catalog.mediaBaseURL
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
                            subtitle: "头像先裁剪再上传；保存资料后才会更新。"
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
            .sheet(isPresented: $showPicker) {
                PhotoPicker { image in
                    cropImage = CropImage(image: image)
                }
            }
            .fullScreenCover(item: $cropImage) { item in
                NavigationStack {
                    AvatarCropView(image: item.image, avatar: avatar) { url in
                        model.setAvatarUrl(url)
                    }
                }
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
                        avatarView(profile)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.email)
                                .font(.footnote)
                                .foregroundStyle(Zine.muted)
                            Text("关注 \(profile.followingCount) · 粉丝 \(profile.followerCount)")
                                .font(.caption)
                                .foregroundStyle(Zine.muted)
                        }
                        Spacer(minLength: 8)
                        Button("更换头像") { showPicker = true }
                            .buttonStyle(LinkButtonStyle())
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

                Text("头像裁剪后先上传为本人私有暂存引用，保存资料才会更新；只改昵称时保留现有头像。")
                    .font(.caption)
                    .foregroundStyle(Zine.muted)
            }
        }
    }

    @ViewBuilder
    private func avatarView(_ profile: UserProfile) -> some View {
        ZStack {
            Circle().fill(Zine.alt)
            if let raw = model.avatarUrl,
               let url = MediaURL.resolve(raw, baseURL: mediaBaseURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialAvatar(profile)
                    }
                }
            } else {
                initialAvatar(profile)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(Circle())
        .accessibilityLabel("当前头像")
    }

    private func initialAvatar(_ profile: UserProfile) -> some View {
        Text(String(profile.displayName.prefix(1)))
            .font(.system(size: 26, weight: .black, design: .serif))
            .foregroundStyle(Zine.red)
            .accessibilityHidden(true)
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


private struct CropImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
