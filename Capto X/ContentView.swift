import SwiftUI
import WebKit
import Combine
import AVFoundation
import MicrosoftCognitiveServicesSpeech

// MARK: - 1. 음성 인식 매니저 (에러 추적 기능 강화)
class SpeechManager: ObservableObject {
    @Published var currentlyRecognizing: String = ""
    @Published var finalResult: String = ""
    @Published var isRecording: Bool = false
    
    private var recognizer: SPXSpeechRecognizer?
    
    func start(key: String, region: String) {
        if isRecording { return }
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true)
        
        do {
            guard let config = try? SPXSpeechConfiguration(subscription: key, region: region) else { return }
            config.speechRecognitionLanguage = "ko-KR"
            let audioConfig = SPXAudioConfiguration()
            recognizer = try SPXSpeechRecognizer(speechConfiguration: config, audioConfiguration: audioConfig)
            
            // --- 🔍 여기서부터 에러를 추적하는 코드입니다 ---
            recognizer?.addCanceledEventHandler { _, evt in
                print("❌ [에러 발생] 이유 번호: \(evt.reason.rawValue)")
                print("❌ [상세 내용]: \(evt.errorDetails ?? "내용 없음")")
            }
            
            recognizer?.addSessionStartedEventHandler { _, _ in
                print("✅ [연결 상태] Azure 서버와 연결되었습니다!")
            }
            // ------------------------------------------

            recognizer?.addRecognizingEventHandler { _, evt in
                DispatchQueue.main.async { self.currentlyRecognizing = evt.result.text ?? "" }
            }
            
            recognizer?.addRecognizedEventHandler { _, evt in
                let text = evt.result.text ?? ""
                if !text.isEmpty {
                    DispatchQueue.main.async {
                        self.finalResult = text
                        self.currentlyRecognizing = ""
                    }
                }
            }
            
            try recognizer?.startContinuousRecognition()
            DispatchQueue.main.async { self.isRecording = true }
            print("🎙️ [알림] 마이크가 켜졌습니다. 말씀해 보세요!")
            
        } catch {
            print("❌ [시스템 오류]: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        try? recognizer?.stopContinuousRecognition()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
        print("🛑 [알림] 마이크가 꺼졌습니다.")
    }
}

// MARK: - 2. 다음 사전 웹뷰
struct DaumDicView: UIViewRepresentable {
    let searchTerm: String
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if !searchTerm.isEmpty,
           let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://dic.daum.net/search.do?q=\(encoded)") {
            uiView.load(URLRequest(url: url))
        }
    }
}

// MARK: - 3. 메인 화면
struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var subtitles: [String] = []
    @State private var selectedWord: String = ""
    
    // ⚠️ 여기에 본인의 Azure 키와 리전을 정확히 넣으세요!
    let azureKey = "9STsqoasGraz5LB4lczPBL7MXkE9bCJ6Hrh6HvQ9KRkkzrutn7r6JQQJ99CCACYeBjFXJ3w3AAAYACOGGjUY"
    let azureRegion = "eastus"
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("GenCap Pro - 실시간 기록").font(.headline).padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(.systemGray6))

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 25) {
                            ForEach(subtitles.indices, id: \.self) { index in
                                Text(subtitles[index])
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                                    .onTapGesture {
                                        if let first = subtitles[index].split(separator: " ").first {
                                            self.selectedWord = String(first)
                                        }
                                    }
                            }
                            if !speechManager.currentlyRecognizing.isEmpty {
                                Text(speechManager.currentlyRecognizing).font(.system(size: 30)).foregroundColor(.blue).frame(maxWidth: .infinity, alignment: .leading).id("current")
                            }
                            Spacer().frame(height: 250).id("bottom_spacer")
                        }
                        .padding(.horizontal, 40).padding(.top, 40)
                    }
                    .background(Color.white)
                    .onChange(of: subtitles.count) { _ in withAnimation { proxy.scrollTo("bottom_spacer", anchor: .bottom) } }
                    .onChange(of: speechManager.currentlyRecognizing) { _ in proxy.scrollTo("bottom_spacer", anchor: .bottom) }
                }
                
                HStack {
                    Button(action: {
                        if speechManager.isRecording { speechManager.stop() }
                        else { speechManager.start(key: azureKey, region: azureRegion) }
                    }) {
                        VStack {
                            Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(speechManager.isRecording ? .red : .blue)
                            Text(speechManager.isRecording ? "중지" : "시작").foregroundColor(.black)
                        }
                    }
                }
                .padding().frame(maxWidth: .infinity).background(Color(.systemGray6))
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            VStack {
                if selectedWord.isEmpty { Text("단어를 터치하면 사전이 나타납니다").foregroundColor(.gray).frame(maxHeight: .infinity) }
                else { DaumDicView(searchTerm: selectedWord).frame(maxHeight: .infinity) }
            }
            .frame(maxWidth: .infinity)
        }
        .edgesIgnoringSafeArea(.bottom)
        .onReceive(speechManager.$finalResult) { newText in
            if !newText.isEmpty {
                subtitles.append(newText)
                speechManager.finalResult = ""
            }
        }
    }
}
