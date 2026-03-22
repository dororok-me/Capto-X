import SwiftUI
import WebKit
import Combine
import AVFoundation
import MicrosoftCognitiveServicesSpeech

// MARK: - 1. 메인 화면
struct ContentView: View {
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var glossaryStore = GlossaryStore()
    
    @AppStorage("fontSize") private var fontSize: Double = 26.0
    @AppStorage("lineSpacing") private var lineSpacing: Double = 10.0
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @State private var subtitles: [String] = []
    @State private var selectedWord: String = ""
    @State private var isScrollPaused = false
    
    @State private var showGlossary = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    
    // ✨ 좌우 분할 너비 비율 (기본 0.5)
    @State private var leftPanelWidthRatio: CGFloat = 0.5
    @State private var lastTranslation: CGFloat = 0 // 👈 튀는 현상 방지용 변수
    
    let primaryBlue = Color(red: 50/255, green: 110/255, blue: 240/255)
    
    var body: some View {
            // 전체 화면 크기를 구하기 위한 GeometryReader
            GeometryReader { fullGeometry in
                let totalWidth = fullGeometry.size.width
                let totalHeight = fullGeometry.size.height
                
                // 💡 ZStack을 사용하여 두 창 위에 플로팅 핸들을 얹습니다.
                ZStack {
                    
                    // 1. [바닥 레이어] 자막 창과 사전 창 (경계선 없이 딱 붙음)
                    HStack(spacing: 0) {
                        
                        // --- [왼쪽] 자막 영역 ---
                        VStack(spacing: 0) {
                            headerView
                            subtitleScrollView
                            bottomMenuBar
                        }
                        .frame(width: totalWidth * leftPanelWidthRatio)
                        .background {
                            if isDarkMode { Color.black }
                            else { LegalPadBackground(fontSize: CGFloat(fontSize), lineSpacing: CGFloat(lineSpacing)) }
                        }

                        // ✨ [중앙] 빈 칸 없는 얇은 구분선만 남김 (여백 0)
                        Divider()
                            .frame(width: 1)
                            .background(Color.gray.opacity(0.3))
                        
                        // --- [오른쪽] 통합 메뉴 패널 ---
                        RightPaneView(selectedWord: $selectedWord, glossaryStore: glossaryStore)
                            .frame(width: totalWidth * (1 - leftPanelWidthRatio) - 1) // 구분선 1pt 제외
                            .background(isDarkMode ? Color(white: 0.1) : Color.white)
                    }
                    
                    // 2. [위 레이어] ✨ 유리 효과(Glassmorphism) 플로팅 좌우 화살표 핸들
                    // 2. [위 레이어] ✨ 초슬림 유리 핸들 (튀는 현상 해결 버전)
                                    ZStack {
                                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                                            .font(.system(size: 16, weight: .thin)) // 👈 폰트를 아주 얇고 세련되게
                                            .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.6))
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 6)
                                            .background(
                                                Capsule()
                                                    // 💡 더 투명한 머티리얼 효과 적용
                                                    .fill(.ultraThinMaterial.opacity(0.5))
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(Color.white.opacity(0.1), lineWidth: 0.3)
                                                    )
                                            )
                                    }
                                    .frame(width: 60, height: 160)
                                    .contentShape(Rectangle())
                                    .position(x: fullGeometry.size.width * leftPanelWidthRatio, y: fullGeometry.size.height * 0.5)
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                // ✨ [핵심] 튀는 현상 해결: 전체 이동거리에서 직전 이동거리를 뺀 만큼만 이동
                                                let actualDelta = value.translation.width - lastTranslation
                                                let deltaRatio = actualDelta / fullGeometry.size.width
                                                
                                                let newRatio = leftPanelWidthRatio + deltaRatio
                                                
                                                if newRatio > 0.25 && newRatio < 0.8 {
                                                    leftPanelWidthRatio = newRatio
                                                }
                                                // 현재 이동거리를 기록해서 다음 계산에 사용
                                                lastTranslation = value.translation.width
                                            }
                                            .onEnded { _ in
                                                // 드래그가 끝나면 기록 초기화
                                                lastTranslation = 0
                                            }
                                    )
                }
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
            .sheet(isPresented: $showGlossary) { GlossaryView(glossaryStore: glossaryStore) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShareSheet) { ShareSheet(text: subtitles.joined(separator: "\n")) }
        .onReceive(speechManager.$recognizedText) { text in
            if !text.isEmpty { subtitles.append(text); speechManager.recognizedText = "" }
        }
    }
}

// MARK: - 하위 뷰 구성 (Extension으로 분리하여 가독성 향상)
extension ContentView {
    private var headerView: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Capto X").font(.system(size: 32, weight: .heavy)).foregroundColor(primaryBlue)
                Text("v1.0").font(.system(size: 12)).foregroundColor(.gray).padding(.leading, 2)
            }
            Spacer()
            Button(action: { showShareSheet = true }) {
                Image(systemName: "square.and.arrow.up").font(.title2).foregroundColor(primaryBlue)
            }
        }
        .padding(.horizontal, 30).padding(.top, 20).padding(.bottom, 10).background(Color.clear)
    }
    
    private var subtitleScrollView: some View {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: CGFloat(lineSpacing + 10)) {
                        ForEach(subtitles.indices, id: \.self) { index in
                            Text(glossaryStore.annotate(text: subtitles[index]))
                                .font(.system(size: CGFloat(fontSize)))
                                // ✨ 핵심: 너비를 부모 창에 딱 맞게 고정하여 좌우 스크롤 방지
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true) // 가로는 고정, 세로로만 늘어남
                                .contentShape(Rectangle())
                                .onTapGesture { handleWordTap(text: subtitles[index]) }
                                .id(index)
                        }
                        
                        // 실시간 인식 중인 텍스트도 동일하게 설정
                        if !speechManager.currentlyRecognizing.isEmpty {
                            Text(glossaryStore.annotate(text: speechManager.currentlyRecognizing))
                                .font(.system(size: CGFloat(fontSize)))
                                .foregroundColor(primaryBlue)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("realtime_anchor")
                        }
                        
                        Color.clear.frame(height: 120).id("bottom_anchor")
                    }
                    // 자막이 벽에 너무 붙지 않게 여백 조절
                    .padding(.horizontal, 20)
                }
                .background(Color.clear)
                .onChange(of: speechManager.currentlyRecognizing) { _ in
                    if !isScrollPaused { proxy.scrollTo("bottom_anchor", anchor: .bottom) }
                }
            }
        }
    
    private var bottomMenuBar: some View {
        HStack(spacing: 18) {
            MenuActionButton(icon: "character.book.closed", label: "Glossary", isActive: showGlossary) { showGlossary = true }
            languageToggleView
            MenuActionButton(icon: "textformat.size", label: "Font", isActive: false) { fontSize = fontSize > 40 ? 20 : fontSize + 4 }
            recordButtonView
            MenuActionButton(icon: isScrollPaused ? "pause.circle.fill" : "pause.circle", label: "Scroll", isActive: isScrollPaused) { isScrollPaused.toggle() }
            MenuActionButton(icon: "trash", label: "Clear", isActive: false) { subtitles.removeAll(); selectedWord = "" }
            MenuActionButton(icon: "gearshape", label: "Settings", isActive: showSettings) { showSettings = true }
        }
        .padding(.top, 15).padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(isDarkMode ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
    }

    private var recordButtonView: some View {
        Button(action: { speechManager.isRecording ? speechManager.stop() : speechManager.start() }) {
            VStack(spacing: 4) {
                ZStack {
                    Circle().stroke(isDarkMode ? .white.opacity(0.2) : .gray.opacity(0.2), lineWidth: 1.5).frame(width: 60, height: 60)
                    Image(systemName: speechManager.isRecording ? "stop.circle.fill" : "mic.circle.fill").font(.system(size: 55)).foregroundColor(primaryBlue)
                }
                Text(speechManager.isRecording ? speechManager.timeString : "Start").font(.system(size: 11, weight: .bold, design: .monospaced))
            }
        }
    }

    private var languageToggleView: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("KR").font(.system(size: 11, weight: .bold)).foregroundColor(speechManager.currentLanguage == "ko-KR" ? .white : .gray).padding(.horizontal, 8).padding(.vertical, 4).background(speechManager.currentLanguage == "ko-KR" ? primaryBlue : Color.clear)
                Text("EN").font(.system(size: 11, weight: .bold)).foregroundColor(speechManager.currentLanguage == "en-US" ? .white : .gray).padding(.horizontal, 8).padding(.vertical, 4).background(speechManager.currentLanguage == "en-US" ? primaryBlue : Color.clear)
            }.clipShape(Capsule()).overlay(Capsule().stroke(Color.gray.opacity(0.2))).onTapGesture { speechManager.toggleLanguage() }
        }
    }

    private func handleWordTap(text: String) {
        let cleaned = text.components(separatedBy: CharacterSet.punctuationCharacters).joined()
        if let first = cleaned.split(separator: " ").first { self.selectedWord = String(first) }
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

// MARK: - 3. 리걸 패드 배경
struct LegalPadBackground: View {
    var fontSize: CGFloat; var lineSpacing: CGFloat
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color(red: 255/255, green: 253/255, blue: 208/255)
                Path { path in
                    let rowHeight = fontSize + lineSpacing + 10
                    var y = rowHeight + 20
                    while y < geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += rowHeight
                    }
                }.stroke(Color.blue.opacity(0.15), lineWidth: 1)
                Rectangle().fill(Color.red.opacity(0.2)).frame(width: 1.5).padding(.leading, 80).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - 4. 음성 인식 관리 (SpeechManager)
class SpeechManager: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var currentlyRecognizing: String = ""
    @Published var isRecording: Bool = false
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
            if !text.isEmpty { DispatchQueue.main.async { self.recognizedText = text; self.currentlyRecognizing = "" } }
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
