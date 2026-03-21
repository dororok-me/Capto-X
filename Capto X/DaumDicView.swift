import SwiftUI
import WebKit

struct DaumDicView: UIViewRepresentable {
    let searchTerm: String

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://dic.daum.net/search.do?q=\(encoded)") {
            uiView.load(URLRequest(url: url))
        }
    }
}
