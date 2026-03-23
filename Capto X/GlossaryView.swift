import SwiftUI
import UniformTypeIdentifiers

struct GlossaryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var glossaryStore: GlossaryStore
    
    @State private var showFilePicker = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var showResetAlert = false
    @State private var editingID: UUID?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Add new terms")) {
                    NewEntryRow(glossaryStore: glossaryStore)
                }
                
                Section(header: Text("List")) {
                    if glossaryStore.entries.isEmpty {
                        Text("No terms registered.").foregroundColor(.gray)
                    } else {
                        ForEach(glossaryStore.entries) { entry in
                            // 💡 하위 뷰에 ID와 데이터를 안전하게 전달
                            GlossaryRow(
                                entry: entry,
                                editingID: $editingID,
                                glossaryStore: glossaryStore
                            )
                        }
                        .onDelete(perform: glossaryStore.delete)
                    }
                }
            }
            .navigationTitle("Glossary")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 18) {
                        Button(role: .destructive) { showResetAlert = true } label: {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                        Button(action: { showFilePicker = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Button(action: { runExport() }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .alert("용어집 초기화", isPresented: $showResetAlert) {
                Button("전체 삭제", role: .destructive) { glossaryStore.resetAll() }
                Button("취소", role: .cancel) {}
            } message: {
                Text("등록된 모든 단어가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                onCompletion: { result in
                    handleImport(result: result)
                }
            )
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL { GlossaryShareSheet(activityItems: [url]) }
            }
        }
    }

    private func handleImport(result: Result<URL, Error>) {
        if case .success(let url) = result {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url),
                   let csv = String(data: data, encoding: .utf8) {
                    glossaryStore.importFromCSV(contents: csv, overwrite: true)
                }
            }
        }
    }

    private func runExport() {
        let csvString = glossaryStore.exportToCSV()
        if let data = csvString.data(using: .utf8) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Glossary_Backup.csv")
            try? data.write(to: tempURL)
            self.exportURL = tempURL
            self.showShareSheet = true
        }
    }
}

// MARK: - ✨ 에러 발생 지점 수정 (GlossaryRow)
// MARK: - ✨ [디자인 강화] 리스트의 각 행을 담당하는 뷰
struct GlossaryRow: View {
    let entry: GlossaryEntry
    @Binding var editingID: UUID?
    let glossaryStore: GlossaryStore
    
    @State private var editSource: String = ""
    @State private var editTarget: String = ""
    
    var body: some View {
        if editingID == entry.id {
            // 🟦 [수정 모드] 배경색을 넣어 편집 중임을 강조합니다.
            VStack(spacing: 12) {
                HStack {
                    TextField("Eng", text: $editSource)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .background(Color.white) // 입력창은 하얗게 유지
                    
                    TextField("Kor", text: $editTarget)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .background(Color.white)
                }
                
                HStack(spacing: 50) {
                    // ✖️ 취소 버튼 (동그라미 안의 X)
                    Button(action: { editingID = nil }) {
                        VStack(spacing: 5) {
                            Image(systemName: "xmark.circle.fill") // SF Symbol 아이콘
                                .font(.system(size: 24))
                            Text("Cancel")
                                .font(.caption2)
                        }
                        .foregroundColor(.gray.opacity(0.6)) // 연한 회색
                    }
                    
                    // ✔️ 확정 버튼 (동그라미 안의 체크)
                    Button(action: {
                        glossaryStore.update(id: entry.id, source: editSource, target: editTarget)
                        editingID = nil
                    }) {
                        VStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill") // SF Symbol 아이콘
                                .font(.system(size: 24))
                            Text("Confirm")
                                .font(.caption2)
                                .bold()
                        }
                        .foregroundColor(.gray) // 조금 더 짙은 회색
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1)) // 💡 연한 파란색 박스로 강조
            .cornerRadius(10)
            .onAppear {
                editSource = entry.source
                editTarget = entry.target
            }
        } else {
            // ⬜ [일반 모드]
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.source)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(entry.target)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                Spacer()
                // 편집 가능함을 알리는 아이콘
                Image(systemName: "pencil.line")
                    .foregroundColor(.gray.opacity(0.5))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .onTapGesture {
                // 클릭 시 수정 모드 진입
                editingID = entry.id
            }
        }
    }
}
// NewEntryRow 및 GlossaryShareSheet는 이전과 동일하게 유지...
struct NewEntryRow: View {
    @ObservedObject var glossaryStore: GlossaryStore
    @State private var source = ""
    @State private var target = ""
    var body: some View {
        HStack {
            TextField("Eng", text: $source)
            TextField("Kor", text: $target)
            Button("Add") {
                if !source.isEmpty && !target.isEmpty {
                    glossaryStore.addEntry(word: source, definition: target)
                    source = ""; target = ""
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct GlossaryShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
