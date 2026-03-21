import SwiftUI
import WebKit
import Combine
import AVFoundation
import MicrosoftCognitiveServicesSpeech

// MARK: - 1. 메인 화면 (UI)
struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var glossaryStore = GlossaryStore()
    
    @State private var subtitles: [String] = []
    @State private var selectedWord: String = ""
    @State private var isScrollPaused = false
    @State private var fontSize: CGFloat = 26
    
    @State private var showGlossary = false
    @State private var showShareSheet = false
    @State private var animatePulse = false // 애니메이션용
    
    let primaryBlue = Color(red: 50/255, green: 110/255, blue: 240/255)
    
    var body: some View {
        GeometryReader { fullGeometry in
            HStack(spacing: 0) {
                // --- [왼쪽 50%] 자막 및 제어 영역 ---
                VStack(spacing: 0) {
                    // [상단] 로고 (Ultra Bold 적용)
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
                    .background(Color.white)

                    // [중앙] 자막 스크롤 영역
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 25) {
                                ForEach(subtitles.indices, id: \.self) { index in
                                    Text(glossaryStore.annotate(text: subtitles[index], isKorean: speechManager.currentLanguage == "ko-KR", fontSize: fontSize))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(index)
                                        .onTapGesture {
                                            if let first = subtitles[index].split(separator: " ").first {
                                                self.selectedWord = String(first)
                                            }
                                        }
                                }
                                if !speechManager.currentlyRecognizing.isEmpty {
                                    Text(glossaryStore.annotate(text: speechManager.currentlyRecognizing, isKorean: speechManager.currentLanguage == "ko-KR", fontSize: fontSize))
                                        .foregroundColor(primaryBlue)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id("realtime_anchor")
                                }
                                Color.clear.frame(height: 100).id("bottom_anchor")
                            }
                            .padding(.horizontal, 40)
                        }
                        .background(Color.white)
                        .onChange(of: speechManager.currentlyRecognizing) { _ in
                            if !isScrollPaused { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                        }
                    }
                    
                    // [하단] 메뉴바 (순서: Glossary, Language, Font, Start, Scroll, Clear, Settings)
                    HStack(spacing: 18) {
                        MenuActionButton(icon: "character.book.closed", label: "Glossary", isActive: showGlossary) { showGlossary = true }
                        
                        languageToggleView
                        
                        MenuActionButton(icon: "textformat.size", label: "Font", isActive: false) {
                            fontSize = fontSize > 35 ? 20 : fontSize + 6
                        }

                        // 🔥 중앙 Start/Stop 버튼 (애니메이션 & 타이머)
                        Button(action: {
                            speechManager.isRecording ? speechManager.stop() : speechManager.start()
                        }) {
                            VStack(spacing: 4) {
                                ZStack {
                                    if speechManager.isRecording {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 55, height: 55)
                                            .scaleEffect(animatePulse ? 1.4 : 1.0)
                                            .opacity(animatePulse ? 0.0 : 0.4)
                                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: animatePulse)
                                            .onAppear { animatePulse = true }
                                            .onDisappear { animatePulse = false }
                                    }
                                    Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                        .font(.system(size: 55))
                                        .foregroundColor(speechManager.isRecording ? .red : primaryBlue)
                                }
                                if speechManager.isRecording {
                                    Text(speechManager.timeString).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.red)
                                } else {
                                    Text("Start").font(.system(size: 10)).foregroundColor(.gray)
                                }
                            }
                        }

                        MenuActionButton(icon: isScrollPaused ? "pause.circle.fill" : "pause.circle", label: "Scroll", isActive: isScrollPaused) { isScrollPaused.toggle() }
                        MenuActionButton(icon: "trash", label: "Clear", isActive: false) { subtitles.removeAll(); selectedWord = "" }
                        MenuActionButton(icon: "gearshape", label: "Settings", isActive: false) { }
                    }
                    .padding(.top, 10).padding(.bottom, 25)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                }
                .frame(width: fullGeometry.size.width * 0.5)

                Divider()
                
                // --- [오른쪽 50%] 사전 영역 ---
                VStack {
                    if selectedWord.isEmpty {
                        Text("단어를 터치하여 검색").font(.subheadline).foregroundColor(.gray).frame(maxHeight: .infinity)
                    } else {
                        DaumDicView(searchTerm: selectedWord).edgesIgnoringSafeArea(.bottom)
                    }
                }
                .frame(width: fullGeometry.size.width * 0.5)
            }
        }
        .sheet(isPresented: $showGlossary) { GlossaryView(store: glossaryStore) }
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

// MARK: - 4. 음성 인식 및 타이머 관리 (SpeechManager)
class SpeechManager: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var currentlyRecognizing: String = ""
    @Published var isRecording: Bool = false
    
    // ✨ 기본 선택 언어를 영어(en-US)로 변경
    @Published var currentLanguage = "en-US"
    
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.timeElapsed += 1
        }
        
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
