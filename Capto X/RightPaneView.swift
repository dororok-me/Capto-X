import SwiftUI
import WebKit
import SafariServices // ✨ 사파리 브라우저 기능을 위해 필수
import UniformTypeIdentifiers

struct RightPaneView: View {
    @Binding var selectedWord: String
    @ObservedObject var glossaryStore: GlossaryStore
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    // 💡 초기 높이 설정 (사용자 기호에 맞게 조정 가능)
    @State private var previewHeight: CGFloat = 400 // 문서창 초기 높이 상향
    @State private var dicHeight: CGFloat = 300
    
    @State private var webURLString: String = "https://www.google.com"
    @State private var inputURL: String = "https://www.google.com"
    
    @State private var showFileImporter = false
    @State private var selectedFileURL: URL?

    private var dictionaryURL: URL {
        let trimmed = selectedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return URL(string: "https://m.dic.daum.net")! }
        let isEnglish = trimmed.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        let encodedWord = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = isEnglish
            ? "https://m.dic.daum.net/search.do?q=\(encodedWord)&dic=eng"
            : "https://m.dic.daum.net/search.do?q=\(encodedWord)&dic=kren"
        return URL(string: urlString) ?? URL(string: "https://m.dic.daum.net")!
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // --- [1] Document Preview 섹션 (확장 가능 버전) ---
                VStack(spacing: 0) {
                    rightPaneHeader(title: "Document Preview", icon: "doc.text") {
                        Button(action: { showFileImporter = true }) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue)
                        }
                    }
                    ZStack {
                        Color.gray.opacity(0.05)
                        if let fileURL = selectedFileURL {
                            WKWebViewRepresentable(url: fileURL).id(fileURL.absoluteString)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.badge.plus").font(.title).foregroundColor(.gray)
                                Text("문서 불러오기").font(.caption).foregroundColor(.gray)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { showFileImporter = true }
                        }
                    }
                }
                .frame(height: previewHeight)
                
                // 💡 문서창 높이 조절 핸들 (최대 80%까지 확장 가능)
                dividerHandle { value in
                    let newHeight = previewHeight + value.translation.height
                    // 최소 100, 최대 화면의 80%까지 허용
                    if newHeight > 100 && newHeight < geometry.size.height * 0.8 {
                        previewHeight = newHeight
                    }
                }

                // --- [2] Dictionary 섹션 ---
                VStack(spacing: 0) {
                    rightPaneHeader(title: "Dictionary", icon: "character.book.closed") {
                        Button(action: addToGlossary) {
                            HStack(spacing: 4) {
                                Text("Add").font(.caption2).bold()
                                Image(systemName: "plus.square.on.square")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    WKWebViewRepresentable(url: dictionaryURL).id(selectedWord)
                }
                .frame(height: dicHeight)
                
                // 사전창 높이 조절 핸들
                dividerHandle { value in
                    let newHeight = dicHeight + value.translation.height
                    // 하단 브라우저 공간 최소 150은 남겨둠
                    if newHeight > 100 && (previewHeight + newHeight) < geometry.size.height - 150 {
                        dicHeight = newHeight
                    }
                }

                // --- [3] Mini Browser 섹션 (자동 나머지 채움) ---
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "safari").foregroundColor(.blue).font(.system(size: 14))
                        TextField("Search or URL", text: $inputURL, onCommit: loadWebPage)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 13))
                            .padding(6)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(8)
                        Button(action: loadWebPage) {
                            Image(systemName: "arrow.clockwise").font(.system(size: 14))
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))

                    WKWebViewRepresentable(url: URL(string: webURLString) ?? URL(string: "https://www.google.com")!)
                        .id(webURLString)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            handleFileImport(result: result)
        }
        .background(isDarkMode ? Color.black : Color.white)
    }
    
    // --- (로직 부분은 동일하여 생략 가능하지만, 완전성을 위해 포함) ---
    private func loadWebPage() {
        let trimmed = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        webURLString = trimmed.contains(".") ? (trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)") : "https://www.google.com/search?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        inputURL = webURLString
    }

    private func addToGlossary() {
        let word = selectedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        if !word.isEmpty { self.glossaryStore.addEntry(word: word, definition: "사전 검색됨") }
    }

    @ViewBuilder
    private func rightPaneHeader<Content: View>(title: String, icon: String, @ViewBuilder action: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .bold))
            Spacer()
            action()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func dividerHandle(onDrag: @escaping (DragGesture.Value) -> Void) -> some View {
        ZStack {
            Color(UIColor.separator).opacity(0.3).frame(height: 1)
            Capsule().fill(Color.gray.opacity(0.5)).frame(width: 40, height: 6) // 핸들 가독성 상향
                .padding(.vertical, 10).contentShape(Rectangle())
        }
        .gesture(DragGesture().onChanged(onDrag))
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        if case .success(let urls) = result, let url = urls.first {
            if url.startAccessingSecurityScopedResource() {
                let coordinator = NSFileCoordinator()
                coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: nil) { newURL in
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(newURL.lastPathComponent)
                    try? FileManager.default.removeItem(at: tempURL)
                    try? FileManager.default.copyItem(at: newURL, to: tempURL)
                    DispatchQueue.main.async { self.selectedFileURL = tempURL }
                }
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

// MARK: - [부품 1] 모바일용 웹뷰 (사전용)
struct WKWebViewRepresentable: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        
        // 💡 "나는 아이폰이다"라고 속여서 모바일 UI를 불러옵니다.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
}

// MARK: - [부품 2] 사파리 브라우저 (하단 검색용)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let safariVC = SFSafariViewController(url: url)
        safariVC.preferredControlTintColor = .systemBlue
        safariVC.dismissButtonStyle = .close
        return safariVC
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
