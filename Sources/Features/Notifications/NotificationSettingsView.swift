import SwiftUI

@MainActor
struct NotificationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: NotificationSettingsViewModel

    init(
        service: NotificationService,
        authorizer: NotificationAuthorizing? = nil
    ) {
        let resolvedAuthorizer = authorizer ?? SystemNotificationAuthorizer()
        _model = StateObject(
            wrappedValue: NotificationSettingsViewModel(
                service: service,
                authorizer: resolvedAuthorizer
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackdrop()
                ScrollView {
                    VStack(spacing: 14) {
                        SectionHeading(
                            index: "05.1",
                            title: "提醒设置",
                            subtitle: "站内消息始终可读；这里控制系统提醒。"
                        )
                        permissionCard
                        switchesCard
                        Text("开启某类只影响之后产生的事件；站内消息和未读不受影响。")
                            .font(.footnote)
                            .foregroundStyle(Zine.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
            .navigationTitle("提醒设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .task { await model.load() }
        }
    }

    private var permissionCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("系统通知")
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text(model.permissionDescription)
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                if !model.permission.allowsDelivery {
                    HStack(spacing: 12) {
                        Button("允许系统通知") {
                            Task { _ = await model.requestPermission() }
                        }
                        .buttonStyle(InkButtonStyle(primary: true))
                        Button("系统通知设置") {
                            model.openSystemSettings()
                        }
                        .buttonStyle(LinkButtonStyle())
                    }
                }
            }
        }
    }

    private var switchesCard: some View {
        PaperCard {
            VStack(spacing: 0) {
                if model.isLoading && model.preferences.isEmpty {
                    LoadingStateView(message: "正在读取提醒设置…")
                } else if model.preferences.isEmpty {
                    Text("暂时没有可设置的提醒类别。")
                        .font(.subheadline)
                        .foregroundStyle(Zine.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(model.preferences) { item in
                        Toggle(
                            item.title,
                            isOn: Binding(
                                get: { item.enabled },
                                set: { value in
                                    Task { await model.setEnabled(item, enabled: value) }
                                }
                            )
                        )
                        .tint(Zine.red)
                        .disabled(model.savingCategory != nil)
                        .padding(.vertical, 10)
                        if item.category != model.preferences.last?.category {
                            Divider().overlay(Zine.border)
                        }
                    }
                }
            }
        }
    }
}
