import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct RightPaneView: View {
    @Binding var selectedWord: String
    @ObservedObject var glossaryStore: GlossaryStore
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    // 화면 높이 설정
    @State private var previewHeight: CGFloat = 400
    @State private var dicHeight: CGFloat = 300
    
    // 브라우저 및 파일 상태
    @State private var webAddress: String = "https://www.google.com"
    @State private var inputAddress: String = "https://www.google.com"
    @State private var showFileImporter = false
    @State private var selectedFileURL: URL?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // 1. [맨 위] Document Preview (바탕색 분홍색)
                VStack(spacing: 0) {
                    HStack {
                        Label("Document Preview", systemImage: "doc.text.magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Button(action: { showFileImporter = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8).background(Color.purple.opacity(0.1))

                    ZStack {
                        Color.orange.opacity(0.1) // 분홍색/살구색 배경
                        
                        if let fileURL = selectedFileURL {
                            WKWebViewRepresentable(url: fileURL)
                                .id(fileURL.absoluteString)
                        } else {
                            VStack {
                                Image(systemName: "doc.badge.plus").font(.largeTitle).foregroundColor(.gray)
                                Text("파일을 불러오세요").font(.caption).foregroundColor(.gray).padding(.top, 5)
                            }
                        }
                    }
                }
                .frame(height: previewHeight)
                
                dragHandle { value in
                    let newHeight = previewHeight + value.translation.height
                    if newHeight > 100 && newHeight < geometry.size.height * 0.6 {
                        previewHeight = newHeight
                    }
                }

                // 2. [중간] 다음 사전
                DaumDicView(searchTerm: selectedWord)
                    .frame(height: dicHeight)
                
                dragHandle { value in
                    let newHeight = dicHeight + value.translation.height
                    if newHeight > 100 && (previewHeight + newHeight) < geometry.size.height - 200 {
                        dicHeight = newHeight
                    }
                }

                // 3. [맨 아래] 사파리 스타일 브라우저
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari.fill").foregroundColor(.blue)
                        TextField("주소 입력 또는 검색", text: $inputAddress, onCommit: loadWebPage)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 13))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        
                        Button(action: loadWebPage) {
                            Image(systemName: "magnifyingglass").foregroundColor(.blue)
                        }
                    }
                    .padding(8).background(Color(UIColor.secondarySystemBackground))
                    
                    WKWebViewRepresentable(url: URL(string: webAddress) ?? URL(string: "https://www.google.com")!)
                        .id(webAddress)
                    
                    HStack {
                        Button(action: { webAddress = "https://www.google.com"; inputAddress = webAddress }) {
                            Image(systemName: "house").padding()
                        }
                        Spacer()
                        Button(action: loadWebPage) {
                            Image(systemName: "arrow.clockwise").padding()
                        }
                    }
                    .font(.system(size: 18))
                    .frame(height: 44)
                    .background(Color(UIColor.secondarySystemBackground))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
        .background(isDarkMode ? Color.black : Color.white)
    }
    
    // MARK: - 헬퍼 함수
    
    private func loadWebPage() {
        let trimmed = inputAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        if !trimmed.contains(".") {
            webAddress = "https://www.google.com/search?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        } else {
            webAddress = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        }
        inputAddress = webAddress
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let selectedURL = urls.first else { return }
            if selectedURL.startAccessingSecurityScopedResource() {
                let fileManager = FileManager.default
                let coordinator = NSFileCoordinator()
                var coordinatorError: NSError?
                
                coordinator.coordinate(readingItemAt: selectedURL, options: .withoutChanges, error: &coordinatorError) { (newURL) in
                    do {
                        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(newURL.lastPathComponent)
                        if fileManager.fileExists(atPath: tempURL.path) { try fileManager.removeItem(at: tempURL) }
                        try fileManager.copyItem(at: newURL, to: tempURL)
                        DispatchQueue.main.async { self.selectedFileURL = tempURL }
                    } catch { print("복사 실패: \(error)") }
                }
                selectedURL.stopAccessingSecurityScopedResource()
            }
        case .failure(let error): print("선택 실패: \(error)")
        }
    }

    private func dragHandle(onDrag: @escaping (DragGesture.Value) -> Void) -> some View {
        ZStack {
            Color.gray.opacity(0.05).frame(height: 20)
            RoundedRectangle(cornerRadius: 1.5).fill(Color.gray.opacity(0.3)).frame(width: 35, height: 3)
        }
        .gesture(DragGesture().onChanged(onDrag))
    }
}

// MARK: - 헬퍼 컴포넌트: ✨ 이 부분이 빠져서 에러가 났었습니다! ✨
struct WKWebViewRepresentable: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if url.isFileURL {
            uiView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            uiView.load(URLRequest(url: url))
        }
    }
}
