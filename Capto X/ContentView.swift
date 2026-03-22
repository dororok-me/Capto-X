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
    
    let primaryBlue = Color(red: 50/255, green: 110/255, blue: 240/255)
    
    var body: some View {
            // 전체 화면 크기를 구하기 위한 GeometryReader
            GeometryReader { fullGeometry in
                let totalWidth = fullGeometry.size.width
                
                HStack(spacing: 0) {
                
                // --- [왼쪽] 자막 및 제어 영역 ---
                    VStack(spacing: 0) {
                                        headerView
                                        subtitleScrollView
                                        bottomMenuBar
                                    }
                                    // ✨ 너비를 전체 너비의 비율(leftPanelWidthRatio)만큼 정확하게 할당합니다.
                                    .frame(width: totalWidth * leftPanelWidthRatio)
                                    .background {
                                        if isDarkMode { Color.black }
                                        else { LegalPadBackground(fontSize: CGFloat(fontSize), lineSpacing: CGFloat(lineSpacing)) }
                                    }

                                    // 🔥 [중앙] 좌우 드래그 핸들 (세로 구분선)
                                    ZStack {
                                        Divider()
                                            .frame(width: 1)
                                            .background(Color.gray.opacity(0.5))
                                        
                                        // 시각적 핸들 (손잡이)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.gray.opacity(0.5))
                                            .frame(width: 4, height: 80)
                                    }
                                    .contentShape(Rectangle()) // 터치 영역을 핸들 주위로 확장
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                // 드래그한 거리만큼 비율을 계산해서 실시간 업데이트
                                                let deltaRatio = value.translation.width / totalWidth
                                                let newRatio = leftPanelWidthRatio + deltaRatio
                                                
                                                // 너무 한쪽으로 쏠리지 않게 제한 (30% ~ 70% 사이)
                                                if newRatio > 0.3 && newRatio < 0.7 {
                                                    leftPanelWidthRatio = newRatio
                                                }
                                            }
                                    )
                                    
                                    // --- [오른쪽] 통합 메뉴 패널 ---
                                    RightPaneView(selectedWord: $selectedWord, glossaryStore: glossaryStore)
                                        // ✨ 너비를 [전체 너비 - 왼쪽 너비]로 할당하여 빈 칸을 없앱니다.
                                        .frame(width: totalWidth * (1 - leftPanelWidthRatio))
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
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { handleWordTap(text: subtitles[index]) }
                            .id(index)
                    }
                    if !speechManager.currentlyRecognizing.isEmpty {
                        Text(glossaryStore.annotate(text: speechManager.currentlyRecognizing))
                            .font(.system(size: CGFloat(fontSize)))
                            .foregroundColor(primaryBlue).frame(maxWidth: .infinity, alignment: .leading).id("realtime_anchor")
                    }
                    Color.clear.frame(height: 120).id("bottom_anchor")
                }.padding(.leading, 100).padding(.trailing, 40)
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
