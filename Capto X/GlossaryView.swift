import SwiftUI
import UniformTypeIdentifiers

struct GlossaryView: View {
    @ObservedObject var store: GlossaryStore
    @Environment(\.dismiss) var dismiss
    
    // 상태 변수: 검색 및 수정
    @State private var searchQuery = ""
    @State private var showEditForm = false
    @State private var selectedEntry: GlossaryEntry?
    @State private var sourceText = ""
    @State private var targetText = ""
    
    // 상태 변수: 임포트/엑스포트
    @State private var showFileImporter = false
    @State private var showImportStrategyAlert = false
    @State private var showResetConfirm = false
    @State private var importedContent = ""
    
    let primaryBlue = Color(red: 50/255, green: 110/255, blue: 240/255)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - 상단 관리 도구
                HStack(spacing: 20) {
                    Button(action: { shareCSV() }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    Spacer()
                    Button(action: { showFileImporter = true }) {
                        Label("Import", systemImage: "tray.and.arrow.down")
                    }
                    Spacer()
                    Button(action: { showResetConfirm = true }) {
                        Label("Reset", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .font(.subheadline)
                .background(Color(UIColor.secondarySystemBackground))
                
                // MARK: - 검색바
                TextField("Search terms...", text: $searchQuery)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding()
                
                // MARK: - 단어 리스트
                List {
                    let filteredEntries = store.entries.filter {
                        searchQuery.isEmpty ||
                        $0.source.localizedCaseInsensitiveContains(searchQuery) ||
                        $0.target.localizedCaseInsensitiveContains(searchQuery)
                    }
                    
                    ForEach(filteredEntries) { entry in
                        Button(action: {
                            selectedEntry = entry
                            sourceText = entry.source
                            targetText = entry.target
                            showEditForm = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.source)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(entry.target)
                                        .font(.subheadline)
                                        .foregroundColor(primaryBlue)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: store.delete)
                }
                .listStyle(PlainListStyle())
                
                // MARK: - 새 단어 추가 버튼
                Button(action: {
                    selectedEntry = nil
                    sourceText = ""
                    targetText = ""
                    showEditForm = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add New Glossary")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(primaryBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding()
                }
            }
            // ✨ 상단 중앙 제목을 Glossary로 설정
            .navigationTitle("Glossary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            
            // MARK: - 팝업: Glossary 추가/수정 시트
            .sheet(isPresented: $showEditForm) {
                NavigationView {
                    Form {
                        Section(header: Text("Term Details")) {
                            // ✨ 요청하신 구체적인 예시 적용
                            TextField("Eng (e.g., environment / Environment)", text: $sourceText)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            
                            TextField("Kor (환경)", text: $targetText)
                                .autocorrectionDisabled()
                        }
                    }
                    // ✨ 제목을 Glossary로 통일
                    .navigationTitle(selectedEntry == nil ? "New Glossary" : "Edit Glossary")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showEditForm = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                if let entry = selectedEntry {
                                    store.update(id: entry.id, source: sourceText, target: targetText)
                                } else {
                                    store.add(source: sourceText, target: targetText)
                                }
                                showEditForm = false
                            }
                        }
                    }
                }
            }
            
            // MARK: - 파일 임포터 및 알림창 로직 (기존과 동일)
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.plainText, .commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    if url.startAccessingSecurityScopedResource() {
                        if let content = try? String(contentsOf: url) {
                            self.importedContent = content
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.showImportStrategyAlert = true
                            }
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                case .failure(let error):
                    print("Error: \(error.localizedDescription)")
                }
            }
            .alert("가져오기 방식 선택", isPresented: $showImportStrategyAlert) {
                Button("기존 목록 끝에 추가") { store.importFromCSV(content: importedContent, overwrite: false) }
                Button("새로 덮어쓰기", role: .destructive) { store.importFromCSV(content: importedContent, overwrite: true) }
                Button("취소", role: .cancel) { }
            } message: {
                Text("파일을 성공적으로 읽었습니다.\n어떤 방식으로 가져올까요?")
            }
            .confirmationDialog("Reset all terms?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) { store.resetAll() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
    
    private func shareCSV() {
        let csvString = store.exportToCSV()
        
        // 날짜_시간 포맷 (예: 20240321_1355)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let dateString = formatter.string(from: Date())
        
        let fileName = "CaptoX_Glossary_\(dateString).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // 공유 아이템으로 파일 URL 전달
            let av = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // 🚩 아이패드 전용 핵심 수정 코드
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                
                // 현재 가장 위에 떠 있는 뷰 컨트롤러를 찾음 (GlossaryView 시트 포함)
                var topController = rootVC
                while let presentedViewController = topController.presentedViewController {
                    topController = presentedViewController
                }
                
                // 아이패드에서 팝오버 위치 지정
                if let popover = av.popoverPresentationController {
                    // 화면 정중앙에 띄우도록 설정
                    popover.sourceView = topController.view
                    popover.sourceRect = CGRect(x: topController.view.bounds.midX,
                                                y: topController.view.bounds.midY,
                                                width: 0, height: 0)
                    popover.permittedArrowDirections = [] // 화살표 없이 중앙에 띄움
                }
                
                topController.present(av, animated: true, completion: nil)
            }
        } catch {
            print("CSV 내보내기 실패: \(error.localizedDescription)")
        }
    }
}
