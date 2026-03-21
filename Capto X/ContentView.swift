import SwiftUI
import WebKit
import Combine
import AVFoundation
import MicrosoftCognitiveServicesSpeech

// MARK: - 1. 메인 화면
struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var glossaryStore = GlossaryStore() // GlossaryModel.swift 연결
    
    @State private var subtitles: [String] = []
    @State private var selectedWord: String = ""
    @State private var isScrollPaused = false
    @State private var fontSize: CGFloat = 26
    
    // 화면 전환 상태 변수
    @State private var showGlossary = false
    @State private var showShareSheet = false
    
    let primaryBlue = Color(red: 50/255, green: 110/255, blue: 240/255)
    
    var body: some View {
        GeometryReader { fullGeometry in
            HStack(spacing: 0) {
                
                // --- [왼쪽 50%] 자막 및 제어 영역 ---
                VStack(spacing: 0) {
                    // [상단] 로고 및 공유 버튼
                    HStack(alignment: .center) {
                        Text("Capto X")
                            .font(.custom("Gulim", size: 28))
                            .foregroundColor(primaryBlue)
                        Text("v1.0").font(.caption).foregroundColor(.gray).padding(.top, 10)
                        
                        Spacer()
                        
                        // 내보내기(공유) 버튼
                        Button(action: { showShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(primaryBlue)
                        }
                    }
                    .padding(.horizontal, 30).padding(.vertical, 20)
                    .background(Color.white)

                    // [중앙] 자막 스크롤 영역
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 25) {
                                // 1. 확정 자막 (검은색 + 실시간 글로서리 적용)
                                ForEach(subtitles.indices, id: \.self) { index in
                                    Text(glossaryStore.annotate(text: subtitles[index], isKorean: speechManager.currentLanguage == "ko-KR", fontSize: fontSize))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(index)
                                        .onTapGesture {
                                            // 단어 터치 시 사전 검색용 단어 추출
                                            if let first = subtitles[index].split(separator: " ").first {
                                                self.selectedWord = String(first)
                                            }
                                        }
                                }
                                
                                // 2. 🔥 실시간 자막 (파란색 + 즉시 글로서리 강조)
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
                        // 실시간 텍스트 변화에 따른 스크롤 추적
                        .onChange(of: speechManager.currentlyRecognizing) { _ in
                            if !isScrollPaused { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                        }
                        .onChange(of: subtitles.count) { _ in
                            if !isScrollPaused {
                                withAnimation { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                            }
                        }
                    }
                    
                    // [하단] 메뉴바
                    HStack(spacing: 25) {
                        MenuActionButton(icon: "character.book.closed", label: "Glossary", isActive: showGlossary) {
                            showGlossary = true
                        }
                        
                        languageToggleView
                        
                        // 중앙 시작/중지 버튼
                        Button(action: {
                            if speechManager.isRecording { speechManager.stop() }
                            else { speechManager.start() }
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                    .font(.system(size: 55)).foregroundColor(primaryBlue)
                                Text(speechManager.isRecording ? "Stop" : "Start").font(.system(size: 10)).foregroundColor(.gray)
                            }
                        }

                        MenuActionButton(icon: "textformat.size", label: "Font", isActive: false) {
                            fontSize = fontSize > 35 ? 20 : fontSize + 6
                        }
                        MenuActionButton(icon: isScrollPaused ? "pause.circle.fill" : "pause.circle", label: "Scroll", isActive: isScrollPaused) {
                            isScrollPaused.toggle()
                        }
                        MenuActionButton(icon: "trash", label: "Clear", isActive: false) {
                            subtitles.removeAll(); selectedWord = ""
                        }
                    }
                    .padding(.top, 10).padding(.bottom, 25)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: -5)
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
        // 시트(팝업) 연결
        .sheet(isPresented: $showGlossary) {
            GlossaryView(store: glossaryStore)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(text: subtitles.joined(separator: "\n"))
        }
        .onReceive(speechManager.$recognizedText) { text in
            if !text.isEmpty { subtitles.append(text); speechManager.recognizedText = "" }
        }
    }
    
    // 언어 선택 컴포넌트
    private var languageToggleView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("KR").font(.system(size: 11, weight: .bold))
                    .foregroundColor(speechManager.currentLanguage == "ko-KR" ? .white : .gray)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(speechManager.currentLanguage == "ko-KR" ? primaryBlue : Color.clear)
                Text("EN").font(.system(size: 11, weight: .bold))
                    .foregroundColor(speechManager.currentLanguage == "en-US" ? .white : .gray)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(speechManager.currentLanguage == "en-US" ? primaryBlue : Color.clear)
            }
            .clipShape(Capsule()).overlay(Capsule().stroke(Color.gray.opacity(0.2)))
            .onTapGesture { speechManager.toggleLanguage() }
            Text("Language").font(.system(size: 10)).foregroundColor(.gray)
        }
    }
}

// MARK: - 2. 하단 버튼 컴포넌트 (디자인 보조)
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

// MARK: - 3. 다음 사전 웹뷰 (UI 부품)
struct DaumDicView: UIViewRepresentable {
    let searchTerm: String
    func makeUIView(context: Context) -> WKWebView { return WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard !searchTerm.isEmpty else { return }
        if let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://dic.daum.net/search.do?q=\(encoded)") {
            uiView.load(URLRequest(url: url))
        }
    }
}

// MARK: - 4. 음성 인식 매니저 (핵심 로직)
class SpeechManager: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var currentlyRecognizing: String = ""
    @Published var isRecording: Bool = false
    @Published var currentLanguage = "ko-KR"
    private var recognizer: SPXSpeechRecognizer?
    
    func toggleLanguage() {
        currentLanguage = (currentLanguage == "ko-KR") ? "en-US" : "ko-KR"
        if isRecording { stop(); start() }
    }
    
    func start() {
        if isRecording { return }
        // ⚠️ 통역사님의 Azure Key와 Region을 입력하세요
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
    func stop() { try? recognizer?.stopContinuousRecognition(); isRecording = false }
}
