// SubjectListView — minimal CRUD for the W0 shell.

import SwiftUI
import SwiftData
import StudyCore

struct SubjectListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \SubjectModel.createdAt) private var subjects: [SubjectModel]
    @State private var showingForm = false
    @State private var editing: SubjectModel?

    var body: some View {
        NavigationStack {
            List {
                ForEach(subjects) { subject in
                    SubjectRow(subject: subject)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = subject }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("과목")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingForm = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingForm) {
                SubjectFormView(existing: nil)
            }
            .sheet(item: $editing) { subject in
                SubjectFormView(existing: subject)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for i in offsets {
            context.delete(subjects[i])
        }
        Persistence.save({ try context.save() }, context: "subject.delete")
    }
}

private struct SubjectRow: View {
    let subject: SubjectModel

    var body: some View {
        HStack(spacing: DT.Spacing.md) {
            Image(systemName: subject.sfSymbol)
                .frame(width: 28, height: 28)
                .foregroundStyle(SwiftUI.Color(hexString: subject.colorHex) ?? DT.Color.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name).font(DT.Typography.headline)
                Text("\(subject.category == .study ? "공부" : "운동") · 목표 \(subject.dailyTargetMinutes)분")
                    .font(DT.Typography.caption)
                    .foregroundStyle(DT.Color.textSecondary)
            }
            Spacer()
            if subject.allowPhoneUse {
                Text("강의모드")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(DT.Color.warning))
            }
        }
    }
}

private struct SubjectFormView: View {
    let existing: SubjectModel?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorIndex = 0
    @State private var allowPhoneUse = false
    @State private var category: SubjectCategory = .study
    @State private var dailyTargetMinutes: Int = 60
    @State private var iconName: String = "book"
    @State private var workoutType: WorkoutType = .running
    @State private var hydrated = false

    private static let studyIcons = [
        "book", "function", "character.book.closed", "laptopcomputer",
        "pencil.and.ruler", "globe.asia.australia", "flask.fill",
        "music.note", "paintpalette.fill", "atom",
    ]

    private static let workoutIcons = [
        "figure.run", "figure.walk", "figure.strengthtraining.traditional",
        "bicycle", "figure.yoga", "dumbbell.fill", "figure.pool.swim",
    ]

    private var iconChoices: [String] {
        category == .workout ? Self.workoutIcons : Self.studyIcons
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("예: 수학", text: $name)
                }
                Section("색상") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5)) {
                        ForEach(0..<DT.Color.subjectPalette.count, id: \.self) { i in
                            Circle()
                                .fill(DT.Color.subjectPalette[i])
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle().stroke(
                                        i == colorIndex ? DT.Color.textPrimary : .clear,
                                        lineWidth: 2
                                    )
                                )
                                .onTapGesture { colorIndex = i }
                        }
                    }
                }
                Section("카테고리") {
                    Picker("", selection: $category) {
                        Text("공부").tag(SubjectCategory.study)
                        Text("운동").tag(SubjectCategory.workout)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: category) { _, newValue in
                        // Reset icon to a sensible default for the new category.
                        iconName = newValue == .workout ? workoutType.defaultSFSymbol : "book"
                    }
                }
                if category == .workout {
                    Section("운동 종류") {
                        Picker("종류", selection: $workoutType) {
                            ForEach(WorkoutType.allCases, id: \.self) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .onChange(of: workoutType) { _, newValue in
                            iconName = newValue.defaultSFSymbol
                        }
                    }
                }
                Section("아이콘") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(iconChoices, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .frame(width: 40, height: 40)
                                .foregroundStyle(iconName == icon ? .white : DT.Color.textPrimary)
                                .background(
                                    RoundedRectangle(cornerRadius: DT.Radius.md)
                                        .fill(iconName == icon ? DT.Color.primary : DT.Color.surface)
                                )
                                .onTapGesture { iconName = icon }
                        }
                    }
                }
                Section("일일 목표") {
                    Stepper("\(dailyTargetMinutes)분", value: $dailyTargetMinutes, in: 10...600, step: 10)
                }
                Section {
                    Toggle("강의 모드 (다른 앱 사용 허용)", isOn: $allowPhoneUse)
                } footer: {
                    Text("강의 모드는 1회 최대 3시간까지 유지됩니다.")
                }
            }
            .navigationTitle(existing == nil ? "새 과목" : "과목 편집")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("저장") { save() }.disabled(name.isEmpty)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private func hydrate() {
        guard !hydrated, let s = existing else { hydrated = true; return }
        hydrated = true
        name = s.name
        allowPhoneUse = s.allowPhoneUse
        category = s.category
        dailyTargetMinutes = s.dailyTargetMinutes
        iconName = s.sfSymbol
        if let wt = s.workoutType { workoutType = wt }
        if let idx = paletteIndex(forHex: s.colorHex) {
            colorIndex = idx
        }
    }

    private func paletteIndex(forHex hex: String) -> Int? {
        let palette: [UInt32] = [
            0xFF6B6B, 0xFFA94D, 0xFFD43B, 0x69DB7C, 0x4DABF7,
            0x748FFC, 0xB197FC, 0xF783AC, 0x868E96, 0x20C997,
        ]
        var s = hex
        if s.hasPrefix("#") { s.removeFirst() }
        guard let value = UInt32(s, radix: 16) else { return nil }
        return palette.firstIndex(of: value)
    }

    private func save() {
        let hex = "#" + String(format: "%06X", colorHexValue())
        let resolvedWorkoutType: WorkoutType? = (category == .workout) ? workoutType : nil
        if let s = existing {
            s.name = name
            s.colorHex = hex
            s.sfSymbol = iconName
            s.allowPhoneUse = allowPhoneUse
            s.categoryRaw = category.rawValue
            s.dailyTargetMinutes = dailyTargetMinutes
            s.workoutTypeRaw = resolvedWorkoutType?.rawValue
        } else {
            let s = SubjectModel(
                name: name,
                colorHex: hex,
                sfSymbol: iconName,
                allowPhoneUse: allowPhoneUse,
                category: category,
                dailyTargetMinutes: dailyTargetMinutes,
                workoutType: resolvedWorkoutType
            )
            context.insert(s)
        }
        Persistence.save({ try context.save() }, context: "subject.save")
        dismiss()
    }

    private func colorHexValue() -> UInt32 {
        let palette: [UInt32] = [
            0xFF6B6B, 0xFFA94D, 0xFFD43B, 0x69DB7C, 0x4DABF7,
            0x748FFC, 0xB197FC, 0xF783AC, 0x868E96, 0x20C997,
        ]
        return palette[colorIndex]
    }
}
