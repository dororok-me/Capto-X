import SwiftUI
import UniformTypeIdentifiers

struct GlossaryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var glossaryStore: GlossaryStore
    
    @State private var showFilePicker = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationView {
            List {
                // 1. 새 단어 입력 영역 (NewEntryRow 에러 해결)
                Section(header: Text("새 단어 추가")) {
                    NewEntryRow(glossaryStore: glossaryStore)
                }
                
                // 2. 단어 목록 영역
                Section(header: Text("등록된 단어 (총 \(glossaryStore.entries.count)개)")) {
                    if glossaryStore.entries.isEmpty {
                        Text("등록된 단어가 없습니다.").foregroundColor(.gray)
                    } else {
                        ForEach(glossaryStore.entries) { entry in
                            HStack {
                                Text(entry.source).fontWeight(.bold)
                                Spacer()
                                Text(entry.target).foregroundColor(.red)
                            }
                        }
                        .onDelete(perform: glossaryStore.delete)
                    }
                }
            }
            .navigationTitle("용어집 관리")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // 가져오기 버튼
                        Button(action: { showFilePicker = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        // 내보내기 버튼
                        Button(action: { runExport() }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            // CSV 파일 선택기
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false,
                onCompletion: handleImport // ✅ 중복 선언 해결됨
            )
            // 공유 시트 (GlossaryShareSheet 에러 해결)
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    GlossaryShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - 핵심 로직 (중복 선언 방지 및 에러 해결)

    private func handleImport(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                do {
                    let data = try Data(contentsOf: url)
                    if let csvContent = String(data: data, encoding: .utf8) {
                        // GlossaryModel에 정의된 contents 인자 사용
                        glossaryStore.importFromCSV(contents: csvContent, overwrite: true)
                    }
                } catch {
                    print("파일 읽기 오류: \(error)")
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

// MARK: - 보조 뷰 (에러 해결용 부품)

// 1. 단어 입력용 행 (NewEntryRow)
struct NewEntryRow: View {
    @ObservedObject var glossaryStore: GlossaryStore
    @State private var source = ""
    @State private var target = ""
    
    var body: some View {
        HStack {
            TextField("원문 (예: AI)", text: $source)
            TextField("뜻 (예: 인공지능)", text: $target)
            Button("추가") {
                if !source.isEmpty && !target.isEmpty {
                    glossaryStore.addEntry(word: source, definition: target)
                    source = ""; target = ""
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// 2. 공유 시트 (GlossaryShareSheet)
struct GlossaryShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
