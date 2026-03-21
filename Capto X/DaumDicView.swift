import SwiftUI
import WebKit

struct DaumDicView: UIViewRepresentable {
    let searchTerm: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        // ✨ [핵심] 웹사이트에 "나 아이폰이야"라고 속이는 코드 (User Agent 변경)
        // 이 코드가 들어가면 다음 사전이 자동으로 모바일 전용 레이아웃을 내보냅니다.
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (khtml, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1"
        
        // 화면 너비에 딱 맞게 고정하는 보조 스크립트
        let scriptSource = """
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.getElementsByTagName('head')[0].appendChild(meta);
        """
        let userScript = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(userScript)
        
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://dic.daum.net/search.do?q=\(encoded)") {
            uiView.load(URLRequest(url: url))
        }
    }
}
