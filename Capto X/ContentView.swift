import SwiftUI
import WebKit
import Combine
import AVFoundation
import MicrosoftCognitiveServicesSpeech

// MARK: - 1. 음성 인식 매니저 (데이터 전달 최적화)
class SpeechManager: ObservableObject {
    @Published var recognizedText: String = "" // 확정된 문장
    @Published var currentlyRecognizing: String = "" // 인식 중인 문장
    @Published var isRecording: Bool = false
    
    private var recognizer: SPXSpeechRecognizer?
    
    func start(key: String, region: String) {
        if isRecording { return }
        
        // 오디오 세션 강제 활성화 (아이패드 시스템 권한)
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true)
        
        do {
            guard let config = try? SPXSpeechConfiguration(subscription: key, region: region) else { return }
            config.speechRecognitionLanguage = "ko-KR"
            
            let audioConfig = SPXAudioConfiguration()
            recognizer = try SPXSpeechRecognizer(speechConfiguration: config, audioConfiguration: audioConfig)
            
            // [실시간 수신] 파란색 글자용
            recognizer?.addRecognizingEventHandler { _, evt in
                let text = evt.result.text ?? ""
                DispatchQueue.main.async {
                    self.currentlyRecognizing = text
                }
            }
            
            // [문장 확정] 검은색 누적용
            recognizer?.addRecognizedEventHandler { _, evt in
                let text = evt.result.text ?? ""
                if !text.isEmpty {
                    print(">>> [확정 데이터]: \(text)")
                    DispatchQueue.main.async {
                        self.recognizedText = text // ContentView의 onReceive로 신호 보냄
                        self.currentlyRecognizing = ""
                    }
                }
            }
            
            try recognizer?.startContinuousRecognition()
            DispatchQueue.main.async { self.isRecording = true }
        } catch {
            print("❌ Azure 에러: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        try? recognizer?.stopContinuousRecognition()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - 2. 다음 사전 웹뷰 (검색 시에만 로드)
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

// MARK: - 3. 메인 뷰
struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @State private var subtitles: [String] = []
    @State private var selectedWord: String = ""
    
    // Azure 설정
    let azureKey = "9STsqoasGraz5LB4lczPBL7MXkE9bCJ6Hrh6HvQ9KRkkzrutn7r6JQQJ99CCACYeBjFXJ3w3AAAYACOGGjUY"
        let azureRegion = "eastus"
    
    var body: some View {
        HStack(spacing: 0) {
            
            // --- [왼쪽 50%] 자막 기록 영역 ---
            VStack(spacing: 0) {
                // 🛠️ 상단 로고 및 버전 표시 영역 (수정된 부분)
                HStack(alignment: .bottom, spacing: 10) {
                    Text("Capto X")
                        .font(.custom("AmericanTypewriter-Bold", size: 28)) // 굴림체 느낌의 서체
                        .foregroundColor(.black)
                    
                    Text("Ver 1.0.")
                        .font(.custom("AmericanTypewriter", size: 16)) // 굴림체 느낌의 서체
                        .foregroundColor(.gray)
                        .padding(.bottom, 2) // 로고와 아래 맞춤
                    
                    Spacer() // 오른쪽으로 밀어냄
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 25) {
                            
                            // 1. 이미 확정된 자막들 (검은색)
                            ForEach(subtitles.indices, id: \.self) { index in
                                Text(subtitles[index])
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                                    .onTapGesture {
                                        // 터치 시 첫 단어 사전 검색
                                        if let first = subtitles[index].split(separator: " ").first {
                                            self.selectedWord = String(first)
                                        }
                                    }
                            }
                            
                            // 2. 현재 인식 중인 실시간 자막 (파란색)
                            if !speechManager.currentlyRecognizing.isEmpty {
                                Text(speechManager.currentlyRecognizing)
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("current_typing")
                            }

                            // 3. 마지막 여백 (한 줄 비우기)
                            Spacer()
                                .frame(height: 200)
                                .id("bottom_spacer")
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20) // 로고 영역 아래 여백 조정
                    }
                    .background(Color.white)
                    // 데이터가 바뀔 때마다 하단으로 자동 스크롤
                    .onChange(of: subtitles.count) { _ in
                        withAnimation { proxy.scrollTo("bottom_spacer", anchor: .bottom) }
                    }
                    .onChange(of: speechManager.currentlyRecognizing) { _ in
                        proxy.scrollTo("bottom_spacer", anchor: .bottom)
                    }
                }
                
                // 마이크 컨트롤 버튼
                HStack {
                    Button(action: {
                        if speechManager.isRecording { speechManager.stop() }
                        else { speechManager.start(key: azureKey, region: azureRegion) }
                    }) {
                        VStack {
                            Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(speechManager.isRecording ? .red : .blue)
                            Text(speechManager.isRecording ? "중지" : "시작")
                                .font(.caption)
                                .foregroundColor(.black)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // --- [오른쪽 50%] 사전 영역 ---
            VStack {
                if selectedWord.isEmpty {
                    Text("단어를 터치하면 사전이 나타납니다")
                        .foregroundColor(.gray)
                        .frame(maxHeight: .infinity)
                } else {
                    DaumDicView(searchTerm: selectedWord)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .edgesIgnoringSafeArea(.bottom)
        
        // 중요: Azure 서버로부터 확정된 문장을 받아 리스트에 추가하는 핵심 로직
        .onReceive(speechManager.$recognizedText) { newText in
            if !newText.isEmpty {
                print("!!! 화면에 자막 추가: \(newText)")
                withAnimation {
                    subtitles.append(newText)
                }
                speechManager.recognizedText = "" // 초기화하여 다음 문장 대기
            }
        }
    }
}
