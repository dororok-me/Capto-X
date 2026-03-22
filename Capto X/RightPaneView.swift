import SwiftUI
import WebKit
import UniformTypeIdentifiers // ✨ 파일 타입을 인식하기 위해 꼭 필요합니다.

struct RightPaneView: View {
    @Binding var selectedWord: String
    @ObservedObject var glossaryStore: GlossaryStore
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    // ✨ 각 창의 높이 상태 (드래그 조절용)
    @State private var dicHeight: CGFloat = 400
    @State private var unitHeight: CGFloat = 250
    
    // ✨ 문서/웹 뷰어용 상태
    @State private var urlString: String = "https://www.google.com"
    @State private var showFileImporter = false
    @State private var selectedFileURL: URL?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // 1. [상단] 다음 사전
                sectionHeader(title: "다음 사전", icon: "character.book.closed", color: .blue)
                DaumDicView(searchTerm: selectedWord)
                    .frame(height: dicHeight)
                
                dragHandle { value in
                    let newHeight = dicHeight + value.translation.height
                    if newHeight > 100 && newHeight < geometry.size.height * 0.5 { dicHeight = newHeight }
                }

                // 2. [중앙] 도량형 변환기 (에러 해결: 하단에 정의됨)
                sectionHeader(title: "도량형/환율", icon: "arrow.left.and.right", color: .orange)
                UnitConverterTabView()
                    .frame(height: unitHeight)
                
                dragHandle { value in
                    let newHeight = unitHeight + value.translation.height
                    if newHeight > 100 && (dicHeight + newHeight) < geometry.size.height - 250 { unitHeight = newHeight }
                }

                // 3. [하단] ✨ 문서 및 웹 뷰어 (나머지 공간 전체)
                VStack(spacing: 0) {
                    HStack {
                        Label("참고 자료 (PPT/Word/Web)", systemImage: "doc.text.magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        // 파일 불러오기 버튼
                        Button(action: { showFileImporter = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8).background(Color.purple.opacity(0.1))

                    // RightPaneView 내부의 뷰어 호출 부분
                    if let fileURL = selectedFileURL {
                        // ✨ .id(fileURL)을 붙여주면 파일이 바뀔 때마다 뷰를 완전히 새로 만듭니다.
                        WKWebViewRepresentable(url: fileURL)
                            .id(fileURL.absoluteString)
                    } else {
                        WKWebViewRepresentable(url: URL(string: urlString)!)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // ✨ 파일 탐색기 설정 (에러 해결: 명확한 타입 지정)
        .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.presentation, .plainText, .pdf, .rtf, .spreadsheet, UTType("com.microsoft.word.doc")!, UTType("org.openxmlformats.wordprocessingml.document")!],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        guard let selectedURL = urls.first else { return }
                        
                        // 1. 보안 리소스 접근 시작
                        if selectedURL.startAccessingSecurityScopedResource() {
                            defer { selectedURL.stopAccessingSecurityScopedResource() }
                            
                            do {
                                // 2. 임시 폴더 경로 생성
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(selectedURL.lastPathComponent)
                                
                                // 기존에 같은 이름의 파일이 있으면 삭제
                                if FileManager.default.fileExists(atPath: tempURL.path) {
                                    try FileManager.default.removeItem(at: tempURL)
                                }
                                
                                // 3. 파일을 앱 내부 임시 공간으로 복사 (샌드박스 우회 핵심 ⭐)
                                try FileManager.default.copyItem(at: selectedURL, to: tempURL)
                                
                                // 4. 복사된 안전한 경로를 할당
                                self.selectedFileURL = tempURL
                                print("파일 복사 성공: \(tempURL.path)")
                                
                            } catch {
                                print("파일 복사 실패: \(error.localizedDescription)")
                            }
                        }
                    case .failure(let error):
                        print("파일 선택 실패: \(error.localizedDescription)")
                    }
                }
                .background(isDarkMode ? Color.black : Color.white)
    }
    
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 14, weight: .bold)).padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.1))
    }
    
    private func dragHandle(onDrag: @escaping (DragGesture.Value) -> Void) -> some View {
        ZStack {
            Color.gray.opacity(0.05).frame(height: 20)
            RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3)).frame(width: 40, height: 4)
        }
        .gesture(DragGesture().onChanged(onDrag))
    }
}

// MARK: - 헬퍼 컴포넌트: 도량형 변환기 (에러 해결 ✨)
struct UnitConverterTabView: View {
    @State private var inputValue: String = ""
    private let rate: Double = 1350.0
    
    var body: some View {
        Form {
            Section("수치 입력") {
                TextField("숫자 입력", text: $inputValue)
                    .font(.title3.bold())
                    .keyboardType(.decimalPad)
                    .onChange(of: inputValue) { newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if let num = Double(filtered.replacingOccurrences(of: ",", with: "")) {
                            let formatter = NumberFormatter()
                            formatter.numberStyle = .decimal
                            inputValue = formatter.string(from: NSNumber(value: num)) ?? ""
                        } else if newValue.isEmpty { inputValue = "" }
                    }
            }
            
            if let val = Double(inputValue.replacingOccurrences(of: ",", with: "")) {
                Section("변환 결과") {
                    HStack { Text("환율 ($➡₩)"); Spacer(); Text("\(format(val * rate)) 원").bold().foregroundColor(.blue) }
                    HStack { Text("면적 (평➡㎡)"); Spacer(); Text("\(format(val * 3.3057)) ㎡").bold() }
                    HStack { Text("온도 (℉➡℃)"); Spacer(); Text("\(format((val - 32) * 5/9)) ℃").bold() }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    func format(_ v: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: v)) ?? ""
    }
}

// MARK: - 헬퍼 컴포넌트: 웹/문서 뷰어
struct WKWebViewRepresentable: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // ✨ 로컬 파일 접근 권한 설정 강화
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = true
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // ✨ 로컬 파일인지 일반 웹(http)인지 구분
        if url.isFileURL {
            // 파일이 위치한 '폴더' 전체에 대해 읽기 권한을 부여하며 로드합니다.
            let directoryURL = url.deletingLastPathComponent()
            uiView.loadFileURL(url, allowingReadAccessTo: directoryURL)
        } else {
            uiView.load(URLRequest(url: url))
        }
    }
}
