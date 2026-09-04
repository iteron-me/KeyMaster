import SwiftUI

struct CalendarTodoView: View {
    @ObservedObject var store: CalendarTodoStore
    @ObservedObject var state: CalendarTodoViewState

    @State private var isViewPickerPresented = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if let errorMessage = store.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.08))
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 720, minHeight: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text(CalendarTodoLayout.periodTitle(mode: state.viewMode, day: state.selectedDay))
                .font(.system(size: 21, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                isViewPickerPresented.toggle()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: state.viewMode.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                    Text(state.viewMode.title)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 90)
            }
            .buttonStyle(CalendarTodoToolbarControlStyle())
            .help("Calendar View")
            .popover(isPresented: $isViewPickerPresented, arrowEdge: .top) {
                CalendarTodoViewPicker(selection: state.viewMode) { mode in
                    state.viewMode = mode
                    isViewPickerPresented = false
                }
            }

            HStack(spacing: 0) {
                toolbarButton("chevron.left", help: "Previous") {
                    state.move(-1)
                }

                Divider().frame(height: 20)

                Button {
                    state.goToToday()
                } label: {
                    Text("Today")
                        .frame(width: 52, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().frame(height: 20)

                toolbarButton("chevron.right", help: "Next") {
                    state.move(1)
                }
            }
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))

        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .fixedSize(horizontal: false, vertical: true)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        switch state.viewMode {
        case .day:
            CalendarTodoDayView(
                day: state.selectedDay,
                focusRequest: state.focusRequest,
                store: store
            )
        case .week:
            CalendarTodoWeekView(
                day: state.selectedDay,
                store: store,
                openDay: state.openDay
            )
        case .month:
            CalendarTodoMonthView(
                day: state.selectedDay,
                store: store
            )
        case .year:
            CalendarTodoYearView(
                day: state.selectedDay,
                store: store,
                openDay: state.openDay,
                openMonth: state.openMonth
            )
        }
    }

    private func toolbarButton(
        _ systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
    }
}

private struct CalendarTodoViewPicker: View {
    let selection: CalendarTodoViewMode
    let select: (CalendarTodoViewMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VIEW")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 3)

            ForEach(CalendarTodoViewMode.allCases) { mode in
                Button {
                    select(mode)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 18)

                        Text(mode.title)
                            .font(.system(size: 13, weight: .medium))

                        Spacer(minLength: 20)

                        if mode == selection {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(CalendarTodoSelectionRowStyle(isSelected: mode == selection))
            }
        }
        .padding(8)
        .frame(width: 180)
    }
}

private struct CalendarTodoDayView: View {
    let day: CalendarTodoDay
    let focusRequest: UUID
    @ObservedObject var store: CalendarTodoStore

    @State private var newTitle = ""
    @FocusState private var isNewTitleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("New Todo", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(CalendarTodoFormStyle.fieldBackground)
                    .overlay(CalendarTodoFormStyle.fieldBorder)
                    .focused($isNewTitleFocused)
                    .onSubmit(addTodo)

                Button(action: addTodo) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(CalendarTodoFormButtonStyle(isPrimary: true))
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Add Todo")
            }
            .padding(16)

            Divider()

            if !todos.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(todos) { todo in
                            CalendarTodoRow(
                                todo: todo,
                                store: store,
                                toggle: { store.toggleCompletion(todo) }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
        .onAppear {
            isNewTitleFocused = true
        }
        .onChange(of: focusRequest) { _, _ in
            isNewTitleFocused = true
        }
        .onChange(of: day) { _, _ in
            newTitle = ""
            isNewTitleFocused = true
        }
    }

    private var todos: [CalendarTodo] {
        store.todos(on: day)
    }

    private func addTodo() {
        guard store.add(title: newTitle, on: day) else {
            return
        }
        newTitle = ""
        isNewTitleFocused = true
    }
}

private struct CalendarTodoRow: View {
    let todo: CalendarTodo
    @ObservedObject var store: CalendarTodoStore
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(todo.isCompleted ? "Reopen Todo" : "Complete Todo")

            CalendarTodoTaskButton(todo: todo, store: store) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(todo.title)
                        .strikethrough(todo.isCompleted)
                    if !todo.notes.isEmpty {
                        Text(todo.notes)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Color.accentColor.opacity(todo.isCompleted ? 0.04 : 0.08))
    }
}

private struct CalendarTodoWeekView: View {
    let day: CalendarTodoDay
    @ObservedObject var store: CalendarTodoStore
    let openDay: (CalendarTodoDay) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarTodoLayout.week(containing: day), id: \.self) { weekDay in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        openDay(weekDay)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weekdayName(weekDay))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(weekDay.day)")
                                .font(.title3.weight(CalendarTodoLayout.isToday(weekDay) ? .bold : .medium))
                                .foregroundStyle(CalendarTodoLayout.isToday(weekDay) ? Color.accentColor : .primary)
                        }
                    }
                    .buttonStyle(.plain)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(store.todos(on: weekDay)) { todo in
                                CalendarTodoTaskButton(todo: todo, store: store) {
                                    Text(todo.title)
                                        .font(.callout)
                                        .strikethrough(todo.isCompleted)
                                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(6)
                                }
                                .background(
                                    Color.accentColor.opacity(todo.isCompleted ? 0.06 : 0.12),
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                                .help(todo.notes.isEmpty ? todo.title : "\(todo.title)\n\(todo.notes)")
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if weekDay != CalendarTodoLayout.week(containing: day).last {
                    Divider()
                }
            }
        }
    }

    private func weekdayName(_ day: CalendarTodoDay) -> String {
        guard let date = day.date() else {
            return ""
        }
        return date.formatted(.dateTime.weekday(.wide))
    }
}

private struct CalendarTodoMonthView: View {
    let day: CalendarTodoDay
    @ObservedObject var store: CalendarTodoStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        GeometryReader { proxy in
            let days = CalendarTodoLayout.month(containing: day)
            let rowCount = max(1, days.count / 7)
            let weekdayHeight: CGFloat = 40
            let rowHeight = max(72, (proxy.size.height - weekdayHeight) / CGFloat(rowCount))

            VStack(spacing: 0) {
                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(CalendarTodoLayout.weekdaySymbols(), id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: weekdayHeight)

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element) { index, cellDay in
                        CalendarTodoMonthCell(
                            day: cellDay,
                            isInMonth: cellDay.year == day.year && cellDay.month == day.month,
                            weekNumber: index.isMultiple(of: 7)
                                ? CalendarTodoLayout.weekNumber(containing: cellDay)
                                : nil,
                            todos: store.todos(on: cellDay),
                            store: store,
                            add: { store.add(title: $0, notes: $1, on: cellDay) }
                        )
                        .frame(height: rowHeight)
                    }
                }
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                }
            }
        }
    }
}

private struct CalendarTodoMonthCell: View {
    let day: CalendarTodoDay
    let isInMonth: Bool
    let weekNumber: Int?
    let todos: [CalendarTodo]
    @ObservedObject var store: CalendarTodoStore
    let add: (String, String) -> Bool

    @State private var isAdding = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button {
                isAdding = true
            } label: {
                HStack {
                    Text(CalendarTodoLayout.dayTitle(day))
                        .font(.system(size: 13, weight: CalendarTodoLayout.isToday(day) ? .semibold : .regular))
                        .foregroundStyle(CalendarTodoLayout.isToday(day) ? Color.white : Color.primary)
                        .padding(.horizontal, CalendarTodoLayout.isToday(day) ? 6 : 0)
                        .frame(height: 24)
                        .background {
                            if CalendarTodoLayout.isToday(day) {
                                Capsule().fill(Color.accentColor)
                            }
                        }
                    Spacer(minLength: 0)

                    if let weekNumber {
                        Text("\(weekNumber)")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ForEach(Array(todos.prefix(3))) { todo in
                CalendarTodoTaskButton(todo: todo, store: store) {
                    Text(todo.title)
                        .font(.system(size: 11))
                        .strikethrough(todo.isCompleted)
                        .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                }
                .background(
                    Color.accentColor.opacity(todo.isCompleted ? 0.07 : 0.14),
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor.opacity(todo.isCompleted ? 0.35 : 0.75))
                        .frame(width: 3)
                }
                .help(todo.notes.isEmpty ? todo.title : "\(todo.title)\n\(todo.notes)")
            }

            if todos.count > 3 {
                Text("+\(todos.count - 3)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Button {
                isAdding = true
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1)
        }
        .opacity(isInMonth ? 1 : 0.42)
        .popover(
            isPresented: $isAdding,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .trailing
        ) {
            CalendarTodoQuickAddView(day: day, add: add) {
                isAdding = false
            }
        }
    }
}

private struct CalendarTodoQuickAddView: View {
    let day: CalendarTodoDay
    let add: (String, String) -> Bool
    let dismiss: () -> Void

    @State private var title = ""
    @State private var notes = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("New task")
                    .font(.system(size: 16, weight: .semibold))

                Text(CalendarTodoLayout.periodTitle(mode: .day, day: day))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 14) {
                CalendarTodoFieldLabel(title: "Title", systemImage: "text.cursor")

                TextField("What needs to be done?", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(CalendarTodoFormStyle.fieldBackground)
                    .overlay(CalendarTodoFormStyle.fieldBorder)
                    .focused($isFocused)
                    .onSubmit(addTodo)

                CalendarTodoFieldLabel(title: "Content", systemImage: "text.alignleft")

                CalendarTodoNotesEditor(text: $notes, placeholder: "Add details")
                    .frame(height: 96)
            }
            .padding(18)

            HStack(spacing: 8) {
                Spacer()

                Button(action: addTodo) {
                    Label("Add task", systemImage: "plus")
                }
                .buttonStyle(CalendarTodoFormButtonStyle(isPrimary: true))
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(width: 360)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isFocused = true
        }
        .onExitCommand(perform: dismiss)
    }

    private func addTodo() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard add(title, notes) else {
            return
        }
        dismiss()
    }
}

private struct CalendarTodoYearView: View {
    let day: CalendarTodoDay
    @ObservedObject var store: CalendarTodoStore
    let openDay: (CalendarTodoDay) -> Void
    let openMonth: (CalendarTodoDay) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 24), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(CalendarTodoLayout.months(inYearContaining: day), id: \.self) { month in
                    CalendarTodoMiniMonth(
                        month: month,
                        store: store,
                        openDay: openDay,
                        openMonth: { openMonth(month) }
                    )
                }
            }
            .padding(20)
        }
    }
}

private struct CalendarTodoMiniMonth: View {
    let month: CalendarTodoDay
    @ObservedObject var store: CalendarTodoStore
    let openDay: (CalendarTodoDay) -> Void
    let openMonth: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        VStack(spacing: 5) {
            Button(action: openMonth) {
                Text(CalendarTodoLayout.monthTitle(month))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(
                    Array(CalendarTodoLayout.weekdaySymbols(compact: true).enumerated()),
                    id: \.offset
                ) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(CalendarTodoLayout.month(containing: month), id: \.self) { cellDay in
                    if cellDay.year == month.year && cellDay.month == month.month {
                        Button {
                            openDay(cellDay)
                        } label: {
                            VStack(spacing: 1) {
                                Text("\(cellDay.day)")
                                    .font(.system(size: 10, weight: CalendarTodoLayout.isToday(cellDay) ? .bold : .regular))
                                    .foregroundStyle(CalendarTodoLayout.isToday(cellDay) ? Color.accentColor : .primary)
                                Circle()
                                    .fill(store.count(on: cellDay) > 0 ? Color.accentColor : .clear)
                                    .frame(width: 3, height: 3)
                            }
                            .frame(maxWidth: .infinity, minHeight: 22)
                        }
                        .buttonStyle(.plain)
                        .help(store.count(on: cellDay) == 1 ? "1 Todo" : "\(store.count(on: cellDay)) Todos")
                    } else {
                        Color.clear.frame(minHeight: 22)
                    }
                }
            }
        }
        .padding(4)
    }
}

private struct CalendarTodoTaskButton<Label: View>: View {
    let todo: CalendarTodo
    @ObservedObject var store: CalendarTodoStore
    private let label: Label

    @State private var isEditing = false

    init(
        todo: CalendarTodo,
        store: CalendarTodoStore,
        @ViewBuilder label: () -> Label
    ) {
        self.todo = todo
        self.store = store
        self.label = label()
    }

    var body: some View {
        Button {
            isEditing = true
        } label: {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isEditing,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .trailing
        ) {
            CalendarTodoEditView(
                todo: todo,
                save: { title, notes, day in
                    store.update(todo, title: title, notes: notes, day: day)
                },
                delete: { store.delete(todo) }
            )
        }
    }
}

private struct CalendarTodoEditView: View {
    let todo: CalendarTodo
    let save: (String, String, CalendarTodoDay) -> Bool
    let delete: () -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var notes: String
    @State private var date: Date
    @State private var isConfirmingDelete = false
    @FocusState private var isTitleFocused: Bool

    init(
        todo: CalendarTodo,
        save: @escaping (String, String, CalendarTodoDay) -> Bool,
        delete: @escaping () -> Bool
    ) {
        self.todo = todo
        self.save = save
        self.delete = delete
        _title = State(initialValue: todo.title)
        _notes = State(initialValue: todo.notes)
        _date = State(initialValue: todo.day.date() ?? Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Edit task")
                    .font(.system(size: 17, weight: .semibold))
                Text("Update its details or move it to another day")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 14) {
                CalendarTodoFieldLabel(title: "Title", systemImage: "text.cursor")

                TextField("Task title", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(CalendarTodoFormStyle.fieldBackground)
                    .overlay(CalendarTodoFormStyle.fieldBorder)
                    .focused($isTitleFocused)

                CalendarTodoFieldLabel(title: "Content", systemImage: "text.alignleft")

                CalendarTodoNotesEditor(text: $notes, placeholder: "Add details")
                    .frame(height: 112)

                CalendarTodoFieldLabel(title: "Date", systemImage: "calendar")

                HStack {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                    Spacer()
                }
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(CalendarTodoFormStyle.fieldBackground)
                .overlay(CalendarTodoFormStyle.fieldBorder)
            }
            .padding(20)

            HStack(spacing: 8) {
                Button {
                    isConfirmingDelete = true
                } label: {
                    Label("Delete task", systemImage: "trash")
                }
                .buttonStyle(CalendarTodoFormButtonStyle(isDestructive: true))

                Spacer()

                Button {
                    if save(title, notes, CalendarTodoDay(date)) {
                        dismiss()
                    }
                } label: {
                    Label("Save changes", systemImage: "checkmark")
                }
                .buttonStyle(CalendarTodoFormButtonStyle(isPrimary: true))
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 440)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            isTitleFocused = true
        }
        .onExitCommand {
            dismiss()
        }
        .alert("Delete Todo?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) {
                if delete() {
                    dismiss()
                }
            }
            Button("Keep Task", role: .cancel) {}
        } message: {
            Text("\"\(todo.title)\" will be permanently deleted.")
        }
    }
}

private struct CalendarTodoFieldLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }
}

private struct CalendarTodoNotesEditor: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(5)
        }
        .background(CalendarTodoFormStyle.fieldBackground)
        .overlay(CalendarTodoFormStyle.fieldBorder)
    }
}

private enum CalendarTodoFormStyle {
    static var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.primary.opacity(0.045))
    }

    static var fieldBorder: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            .allowsHitTesting(false)
    }
}

private struct CalendarTodoToolbarControlStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.10 : 0.05))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
    }
}

private struct CalendarTodoSelectionRowStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.12)
                            : Color.primary.opacity(configuration.isPressed ? 0.06 : 0)
                    )
            }
    }
}

private struct CalendarTodoFormButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var isPrimary = false
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(
                isPrimary ? Color.white : (isDestructive ? Color.red : Color.primary)
            )
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        isPrimary
                            ? Color.accentColor.opacity(configuration.isPressed ? 0.78 : 1)
                            : isDestructive
                                ? Color.red.opacity(configuration.isPressed ? 0.13 : 0.07)
                                : Color.primary.opacity(configuration.isPressed ? 0.09 : 0.05)
                    )
            }
            .overlay {
                if !isPrimary {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isDestructive ? Color.red.opacity(0.16) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.88 : 1) : 0.38)
    }
}
