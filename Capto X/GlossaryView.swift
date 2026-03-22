import SwiftUI
import UniformTypeIdentifiers

struct GlossaryView: View {
    // 💡 핵심: @ObservedObject로 선언되어야 함수 호출이 가능합니다.
    @ObservedObject var glossaryStore: GlossaryStore
    
    @State private var showImportFilePicker = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("새 단어 추가")) {
                    NewEntryRow(glossaryStore: glossaryStore)
                }

                Section(header: Text("내 단어장 (\(glossaryStore.entries.count))")) {
                    if glossaryStore.entries.isEmpty {
                        Text("등록된 단어가 없습니다.").foregroundColor(.secondary)
                    } else {
                        ForEach(glossaryStore.entries) { entry in
                            HStack {
                                Text(entry.source).fontWeight(.bold)
                                Spacer()
                                Text(entry.target).foregroundColor(.secondary)
                            }
                        }
                        .onDelete(perform: glossaryStore.delete)
                    }
                }
            }
            .navigationTitle("글로서리 관리")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // 1. 가져오기 버튼
                        Button(action: { self.showImportFilePicker = true }) {
                            Label("가져오기", systemImage: "square.and.arrow.down")
                        }
                        
                        // 2. 내보내기 버튼 (별도 함수 호출)
                        Button(action: { self.runExport() }) {
                            Label("내보내기", systemImage: "square.and.arrow.up")
                        }
                        EditButton()
                    }
                }
            }
            .fileImporter(
                isPresented: $showImportFilePicker,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                self.handleImport(result: result)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    GlossaryShareSheet(activityItems: [url])
                }
            }
        }
    }

    // MARK: - 에러 해결 핵심 로직 (Binding 에러 원천 차단)

    private func handleImport(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    // ✅ $ 없이 self.glossaryStore로 직접 접근 (72번 에러 해결)
                    self.glossaryStore.importFromCSV(content: content, overwrite: false)
                }
            }
        }
    }

    private func runExport() {
        // ✅ $ 없이 self.glossaryStore로 직접 접근 (80번 에러 해결)
        let csvString = self.glossaryStore.exportToCSV()
        
        // ✅ String.Encoding.utf8 명시로 인식 에러 해결 (82번 에러 해결)
        if let data = csvString.data(using: String.Encoding.utf8) {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Glossary_Backup.csv")
            try? data.write(to: tempURL)
            self.exportURL = tempURL
            self.showShareSheet = true
        }
    }
}

// MARK: - 부속 컴포넌트 (이름 충돌 방지)

struct NewEntryRow: View {
    @ObservedObject var glossaryStore: GlossaryStore
    @State private var source = ""
    @State private var target = ""

    var body: some View {
        HStack {
            TextField("원문", text: $source)
            TextField("번역", text: $target)
            Button(action: {
                if !source.isEmpty && !target.isEmpty {
                    // ✅ $ 없이 호출
                    self.glossaryStore.add(source: source, target: target)
                    self.source = ""
                    self.target = ""
                }
            }) {
                Image(systemName: "plus.circle.fill").foregroundColor(.blue)
            }
            .disabled(source.isEmpty || target.isEmpty)
        }
    }
}

struct GlossaryShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
