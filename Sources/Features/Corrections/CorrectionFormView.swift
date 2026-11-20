import SwiftUI
import UIKit

@MainActor
struct CorrectionFormView: View {
    @StateObject private var model: CorrectionFormViewModel
    @State private var showPicker = false

    init(
        dish: DishDetail,
        corrections: CorrectionService,
        submissions: SubmissionService
    ) {
        _model = StateObject(
            wrappedValue: CorrectionFormViewModel(
                dish: dish,
                corrections: corrections,
                submissions: submissions
            )
        )
    }

    var body: some View {
        ZStack {
            PaperBackdrop()
            ScrollView {
                VStack(spacing: 14) {
                    SectionHeading(
                        index: "01.4",
                        title: "目录纠错",
                        subtitle: model.dishName
                    )
                    if model.baseRevision <= 0 {
                        Text("目录版本缺失，请返回详情刷新后重试。")
                            .font(.subheadline)
                            .foregroundStyle(Zine.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let receipt = model.receipt {
                        successCard(receipt)
                    } else {
                        formCard
                        limitsNote
                    }
                }
                .padding(Zine.pagePadding)
            }
        }
        .navigationTitle("目录纠错")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            MultiPhotoPicker(selectionLimit: max(1, model.remainingEvidenceSlots)) { images in
                Task { await model.addEvidence(images) }
            }
        }
    }

    private var formCard: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("更正名称", isOn: $model.fixName)
                    .tint(Zine.red)
                if model.fixName {
                    TextField("更正后的名称", text: $model.name)
                        .modifier(FormInputStyle())
                }

                Toggle("更正文字介绍", isOn: $model.fixDescription)
                    .tint(Zine.red)
                if model.fixDescription {
                    TextEditor(text: $model.descriptionText)
                        .frame(minHeight: 80, maxHeight: 140)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                        .overlay(
                            RoundedRectangle(cornerRadius: Zine.smallRadius)
                                .stroke(Zine.border, lineWidth: 1)
                        )
                    Text("留空表示清空介绍")
                        .font(.caption)
                        .foregroundStyle(Zine.muted)
                }

                Toggle("更正价格", isOn: $model.fixPrice)
                    .tint(Zine.red)
                if model.fixPrice {
                    TextField("以元为单位；留空表示价格未知", text: $model.priceText)
                        .keyboardType(.decimalPad)
                        .modifier(FormInputStyle())
                }

                Toggle("更正计价单位", isOn: $model.fixPriceUnit)
                    .tint(Zine.red)
                if model.fixPriceUnit {
                    Picker("计价单位", selection: $model.priceUnit) {
                        ForEach(CorrectionPriceUnits.values, id: \.self) { value in
                            Text(CorrectionPriceUnits.label(value)).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Zine.ink)
                }

                evidenceSection

                fieldLabel("更正理由（必填，最多 500 字）")
                TextEditor(text: $model.reason)
                    .frame(minHeight: 70, maxHeight: 120)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: Zine.smallRadius).fill(Zine.paper))
                    .overlay(
                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                            .stroke(Zine.border, lineWidth: 1)
                    )

                if let error = model.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(Zine.red)
                }

                Button {
                    Task { await model.submit() }
                } label: {
                    if model.isSubmitting {
                        ProgressView().tint(Zine.onRed)
                    } else {
                        Text("提交纠错")
                    }
                }
                .buttonStyle(InkButtonStyle(primary: true))
                .disabled(!model.canInteract)
            }
        }
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("证据图片（可选，最多 3 张，仅本人与审核者可见）")
            if !model.evidence.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.evidence) { item in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: item.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 76, height: 76)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: Zine.smallRadius))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Zine.smallRadius)
                                            .stroke(Zine.border, lineWidth: 1)
                                    )
                                if item.isUploading {
                                    ProgressView()
                                        .tint(Zine.onRed)
                                        .padding(6)
                                        .background(Circle().fill(Zine.ink.opacity(0.6)))
                                }
                                Button {
                                    model.removeEvidence(id: item.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Zine.red)
                                        .background(Circle().fill(Zine.paper))
                                }
                                .offset(x: 6, y: -6)
                                .accessibilityLabel("移除证据")
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Button(model.evidence.isEmpty ? "添加证据" : "继续添加证据") {
                showPicker = true
            }
            .buttonStyle(InkButtonStyle())
            .disabled(model.remainingEvidenceSlots == 0 || !model.canInteract)
        }
    }

    private var limitsNote: some View {
        Text("每个认证用户每天最多提交 5 单；每单最多 4 个字段、3 张证据。证据不会加入公开图集。")
            .font(.caption)
            .foregroundStyle(Zine.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func successCard(_ receipt: CatalogCorrection) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("纠错提案已提交")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(Zine.ink)
                Text("等待管理员核对；整单通过或拒绝后，可在「我的纠错」查看结果。")
                    .font(.subheadline)
                    .foregroundStyle(Zine.muted)
                Text("状态：\(receipt.statusLabel)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Zine.gold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Zine.muted)
    }
}
