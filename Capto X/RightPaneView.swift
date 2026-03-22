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
    @State private var webAddress: String = "https://www.google.com"
    @State private var inputAddress: String = "https://www.google.com"
    @State private var showFileImporter = false
    @State private var selectedFileURL: URL?

    // ✨ 언어 판별 및 URL 생성 로직
    private var dictionaryURL: URL {
        let trimmed = selectedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return URL(string: "https://dic.daum.net")! }
        let isEnglish = trimmed.range(of: "[a-zA-Z]", options: .regularExpression) != nil
        let encodedWord = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = isEnglish
            ? "https://dic.daum.net/search.do?q=\(encodedWord)&dic=eng"
            : "https://dic.daum.net/search.do?q=\(encodedWord)&dic=kren"
        return URL(string: urlString) ?? URL(string: "https://dic.daum.net")!
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // 1. Document Preview
                VStack(spacing: 0) {
                    customHeader(title: "Document Preview", icon: "doc.text") {
                        Button(action: { showFileImporter = true }) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.system(size: 18))
                        }
                    }
                    ZStack {
                        Color.orange.opacity(0.05)
                        if let fileURL = selectedFileURL {
                            WKWebViewRepresentable(url: fileURL).id(fileURL.absoluteString)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "plus.viewfinder").font(.system(size: 30)).foregroundColor(.gray)
                                Text("터치하여 문서 불러오기").font(.system(size: 13)).foregroundColor(.gray)
                            }
                            .onTapGesture { showFileImporter = true }
                        }
                    }
                }
                .frame(height: previewHeight)
                
                dragHandle { value in
                    let newHeight = previewHeight + value.translation.height
                    if newHeight > 100 && newHeight < geometry.size.height * 0.6 { previewHeight = newHeight }
                }

                // 2. Dictionary (✨ 에러 완전 해결 구역)
                VStack(spacing: 0) {
                    customHeader(title: "Dictionary", icon: "character.book.closed") {
                        // 💡 해결 핵심: action에 클로저({})를 직접 쓰지 않고 함수 이름만 넘깁니다.
                        Button(action: addCurrentWordToGlossary) {
                            HStack(spacing: 4) {
                                Text("Add to Glossary").font(.caption2)
                                Image(systemName: "plus.square.on.square")
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    WKWebViewRepresentable(url: dictionaryURL).id(selectedWord)
                }
                .frame(height: dicHeight)
                
                dragHandle { value in
                    let newHeight = dicHeight + value.translation.height
                    if newHeight > 100 && (previewHeight + newHeight) < geometry.size.height - 200 { dicHeight = newHeight }
                }

                // 3. Web Search
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "safari").foregroundColor(.blue).font(.system(size: 14, weight: .bold))
                        TextField("Search or enter address", text: $inputAddress, onCommit: loadWebPage)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 14)).padding(6)
                            .background(Color(UIColor.systemBackground)).cornerRadius(8)
                        Button(action: loadWebPage) { Image(systemName: "magnifyingglass").foregroundColor(.primary) }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    
                    WKWebViewRepresentable(url: URL(string: webAddress) ?? URL(string: "https://www.google.com")!).id(webAddress)
                    
                    HStack {
                        Button(action: { webAddress = "https://www.google.com"; inputAddress = webAddress }) { Image(systemName: "house") }
                        Spacer()
                        Button(action: loadWebPage) { Image(systemName: "arrow.clockwise") }
                    }
                    .padding(.horizontal, 40).padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            handleFileImport(result: result)
        }
        .background(isDarkMode ? Color.black : Color.white)
    }
    
    // MARK: - ✨ 에러 해결용 전용 함수 (함수 분리법)
    
    private func addCurrentWordToGlossary() {
        // 💡 ObservedObject를 직접 참조(self.glossaryStore)하여 함수를 실행합니다.
        // 여기서 $기호를 쓰지 않는 것이 포인트입니다.
        let word = selectedWord.trimmingCharacters(in: .whitespacesAndNewlines)
        if !word.isEmpty {
            self.glossaryStore.addEntry(word: word, definition: "사전 검색됨")
        }
    }

    @ViewBuilder
    private func customHeader<Content: View>(title: String, icon: String, @ViewBuilder action: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .bold))
            Spacer()
            action()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemBackground))
    }

    private func dragHandle(onDrag: @escaping (DragGesture.Value) -> Void) -> some View {
        ZStack {
            Color(UIColor.separator).opacity(0.2).frame(height: 1)
            Capsule().fill(Color.gray.opacity(0.4)).frame(width: 40, height: 4).padding(.vertical, 8)
        }
        .gesture(DragGesture().onChanged(onDrag))
    }

    private func loadWebPage() {
        let trimmed = inputAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return }
        webAddress = trimmed.contains(".") ? (trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)") : "https://www.google.com/search?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        inputAddress = webAddress
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

// MARK: - 웹뷰 컴포넌트
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
