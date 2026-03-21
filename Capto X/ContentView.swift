import SwiftUI
import WebKit
import Combine
import AVFoundation
import MicrosoftCognitiveServicesSpeech

// MARK: - 1. 메인 화면
struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var glossaryStore = GlossaryStore()
    
    // Settings와 공유하는 설정값들
    @AppStorage("fontSize") private var fontSize: Double = 26.0
    @AppStorage("lineSpacing") private var lineSpacing: Double = 10.0
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @State private var subtitles: [String] = []
    @State private var selectedWord: String = ""
    @State private var isScrollPaused = false
    
    @State private var showGlossary = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    
    let primaryBlue = Color(red: 50/255, green: 110/255, blue: 240/255)
    
    var body: some View {
        GeometryReader { fullGeometry in
            HStack(spacing: 0) {
                
                // --- [왼쪽 50%] 자막 및 제어 영역 ---
                VStack(spacing: 0) {
                    // [상단] 로고 (Ultra Bold / Heavy 적용)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Capto X")
                                .font(.system(size: 32, weight: .heavy))
                                .foregroundColor(primaryBlue)
                            Text("v1.0").font(.system(size: 12)).foregroundColor(.gray).padding(.leading, 2)
                        }
                        Spacer()
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up").font(.title2).foregroundColor(primaryBlue)
                        }
                    }
                    .padding(.horizontal, 30).padding(.vertical, 20)
                    .background(isDarkMode ? Color.black : Color.white)

                    // [중앙] 자막 스크롤 영역
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: CGFloat(lineSpacing + 10)) {
                                ForEach(subtitles.indices, id: \.self) { index in
                                    Text(glossaryStore.annotate(text: subtitles[index]))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(index)
                                        .onTapGesture {
                                            if let first = subtitles[index].split(separator: " ").first {
                                                self.selectedWord = String(first)
                                            }
                                        }
                                }
                                
                                if !speechManager.currentlyRecognizing.isEmpty {
                                    Text(glossaryStore.annotate(text: speechManager.currentlyRecognizing))
                                        .foregroundColor(primaryBlue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id("realtime_anchor")
                                }
                                Color.clear.frame(height: 100).id("bottom_anchor")
                            }
                            .padding(.horizontal, 40)
                        }
                        .background(isDarkMode ? Color.black : Color.white)
                        .onChange(of: speechManager.currentlyRecognizing) { _ in
                            if !isScrollPaused { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                        }
                    }
                    
                    // [하단] 메뉴바
                    HStack(spacing: 18) {
                        MenuActionButton(icon: "character.book.closed", label: "Glossary", isActive: showGlossary) { showGlossary = true }
                        
                        languageToggleView
                        
                        MenuActionButton(icon: "textformat.size", label: "Font", isActive: false) {
                            fontSize = fontSize > 40 ? 20 : fontSize + 4
                        }

                        // 🔥 중앙 Start/Stop 버튼 (Marquee 애니메이션)
                        Button(action: {
                            speechManager.isRecording ? speechManager.stop() : speechManager.start()
                        }) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.gray.opacity(0.2), lineWidth: 1.5)
                                        .frame(width: 60, height: 60)

                                    // 🔥 중앙 Start/Stop 버튼 내의 Canvas 로직 수정
                                    if speechManager.isRecording {
                                        TimelineView(.animation) { timeline in
                                            Canvas { context, size in
                                                // 1. 문구 뒤에 공백을 명시적으로 추가 (한 단어 크기만큼)
                                                let rawString = "Transcribing        "
                                                let text = Text(rawString)
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(primaryBlue)
                                                
                                                let resolved = context.resolve(text)
                                                // 전체 텍스트 영역의 너비를 측정
                                                let textSize = resolved.measure(in: CGSize(width: CGFloat.infinity, height: size.height))
                                                
                                                // 2. 속도 조절 (20.0)
                                                let t = timeline.date.timeIntervalSinceReferenceDate
                                                let speed = 20.0
                                                // 0부터 textSize.width까지 반복되는 오프셋
                                                let xOffset = CGFloat((t * speed).truncatingRemainder(dividingBy: textSize.width))
                                                
                                                // 3. 원형 마스킹 (글자가 테두리 안에서만 보이게)
                                                context.clip(to: Path(ellipseIn: CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)))
                                                
                                                // ✨ 4. 그리기 로직 (완전 고정 방식)
                                                // 기준점을 원의 왼쪽 끝(0)으로 잡고, xOffset만큼 왼쪽으로 당깁니다.
                                                let yPos = size.height / 2
                                                
                                                // 첫 번째 문구 뭉치
                                                context.draw(resolved, at: CGPoint(x: -xOffset, y: yPos), anchor: .leading)
                                                
                                                // 두 번째 문구 뭉치 (첫 번째 문구 바로 뒤에 밀착)
                                                context.draw(resolved, at: CGPoint(x: textSize.width - xOffset, y: yPos), anchor: .leading)
                                                
                                                // 세 번째 문구 뭉치 (안전을 위해 하나 더 배치)
                                                context.draw(resolved, at: CGPoint(x: (textSize.width * 2) - xOffset, y: yPos), anchor: .leading)
                                            }
                                        }
                                        .frame(width: 60, height: 60)
                                    }
                                    
                                    else {
                                        Image(systemName: "mic.circle.fill")
                                            .font(.system(size: 55)).foregroundColor(primaryBlue)
                                    }
                                }
                                
                                if speechManager.isRecording {
                                    Text(speechManager.timeString).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(isDarkMode ? .white : .black)
                                } else {
                                    Text("Start").font(.system(size: 10)).foregroundColor(.gray)
                                }
                            }
                        }

                        MenuActionButton(icon: isScrollPaused ? "pause.circle.fill" : "pause.circle", label: "Scroll", isActive: isScrollPaused) { isScrollPaused.toggle() }
                        MenuActionButton(icon: "trash", label: "Clear", isActive: false) { subtitles.removeAll(); selectedWord = "" }
                        MenuActionButton(icon: "gearshape", label: "Settings", isActive: showSettings) { showSettings = true }
                    }
                    .padding(.top, 10).padding(.bottom, 25)
                    .frame(maxWidth: .infinity)
                    .background(isDarkMode ? Color.black : Color.white)
                }
                .frame(width: fullGeometry.size.width * 0.5)

                Divider()
                
                // --- [오른쪽 50%] 사전 영역 ---
                VStack {
                    if selectedWord.isEmpty {
                        Text("단어를 터치하여 검색").foregroundColor(.gray).frame(maxHeight: .infinity)
                    } else {
                        DaumDicView(searchTerm: selectedWord).edgesIgnoringSafeArea(.bottom)
                    }
                }
                .frame(width: fullGeometry.size.width * 0.5)
                .background(isDarkMode ? Color(white: 0.1) : Color.white)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showGlossary) { GlossaryView(store: glossaryStore) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShareSheet) { ShareSheet(text: subtitles.joined(separator: "\n")) }
        .onReceive(speechManager.$recognizedText) { text in
            if !text.isEmpty { subtitles.append(text); speechManager.recognizedText = "" }
        }
    }
    
    private var languageToggleView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("KR").font(.system(size: 11, weight: .bold)).foregroundColor(speechManager.currentLanguage == "ko-KR" ? .white : .gray).padding(.horizontal, 8).padding(.vertical, 4).background(speechManager.currentLanguage == "ko-KR" ? primaryBlue : Color.clear)
                Text("EN").font(.system(size: 11, weight: .bold)).foregroundColor(speechManager.currentLanguage == "en-US" ? .white : .gray).padding(.horizontal, 8).padding(.vertical, 4).background(speechManager.currentLanguage == "en-US" ? primaryBlue : Color.clear)
            }.clipShape(Capsule()).overlay(Capsule().stroke(Color.gray.opacity(0.2))).onTapGesture { speechManager.toggleLanguage() }
            Text("Language").font(.system(size: 10)).foregroundColor(.gray)
        }
    }
}

// MARK: - 2. 하단 버튼 컴포넌트
struct MenuActionButton: View {
    let icon: String; let label: String; let isActive: Bool; let action: () -> Void
    let primaryBlue = Color(red: 50/255, green: 110/255, blue: 240/255)
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(isActive ? primaryBlue.opacity(0.1) : Color.clear).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 22)).foregroundColor(isActive ? primaryBlue : .gray)
                }
                Text(label).font(.system(size: 10, weight: .medium)).foregroundColor(isActive ? primaryBlue : .gray)
            }
        }
    }
}

// MARK: - 3. 다음 사전 웹뷰
struct DaumDicView: UIViewRepresentable {
    let searchTerm: String
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://dic.daum.net/search.do?q=\(encoded)") {
            uiView.load(URLRequest(url: url))
        }
    }
}

// MARK: - 4. 음성 인식 관리 (SpeechManager)
class SpeechManager: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var currentlyRecognizing: String = ""
    @Published var isRecording: Bool = false
    @Published var currentLanguage = "en-US" // 기본 영어
    @Published var timeElapsed: Int = 0
    private var timer: Timer?
    private var recognizer: SPXSpeechRecognizer?
    
    var timeString: String {
        let minutes = timeElapsed / 60
        let seconds = timeElapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func toggleLanguage() {
        currentLanguage = (currentLanguage == "ko-KR") ? "en-US" : "ko-KR"
        if isRecording { stop(); start() }
    }
    
    func start() {
        if isRecording { return }
        timeElapsed = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in self.timeElapsed += 1 }
        
        let azureKey = "9STsqoasGraz5LB4lczPBL7MXkE9bCJ6Hrh6HvQ9KRkkzrutn7r6JQQJ99CCACYeBjFXJ3w3AAAYACOGGjUY"
        let azureRegion = "eastus"
        let config = try? SPXSpeechConfiguration(subscription: azureKey, region: azureRegion)
        config?.speechRecognitionLanguage = currentLanguage
        recognizer = try? SPXSpeechRecognizer(speechConfiguration: config!, audioConfiguration: SPXAudioConfiguration())
        
        recognizer?.addRecognizingEventHandler { _, evt in
            DispatchQueue.main.async { self.currentlyRecognizing = evt.result.text ?? "" }
        }
        recognizer?.addRecognizedEventHandler { _, evt in
            let text = evt.result.text ?? ""
            if !text.isEmpty {
                DispatchQueue.main.async { self.recognizedText = text; self.currentlyRecognizing = "" }
            }
        }
        try? recognizer?.startContinuousRecognition()
        isRecording = true
    }
    
    func stop() {
        timer?.invalidate(); timer = nil
        try? recognizer?.stopContinuousRecognition()
        isRecording = false
    }
}

// MARK: - 5. 공유 시트

