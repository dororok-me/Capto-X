import SwiftUI
import WebKit
import Combine
import AVFoundation
import MicrosoftCognitiveServicesSpeech

// MARK: - 1. 메인 화면 구조
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
    
    @State private var leftPanelWidthRatio: CGFloat = 0.6
    @State private var lastTranslation: CGFloat = 0
    
    let primaryBlue = Color(red: 50/255, green: 110/255, blue: 240/255)
    
    var body: some View {
        GeometryReader { fullGeometry in
            let totalWidth = fullGeometry.size.width
            
            ZStack {
                HStack(spacing: 0) {
                    // --- [왼쪽] 자막 영역 ---
                    ZStack(alignment: .bottom) {
                        VStack(spacing: 0) {
                            headerView
                            subtitleScrollView
                            Spacer().frame(height: 100)
                        }
                        .background {
                            if isDarkMode { Color.black }
                            else { LegalPadBackground(fontSize: CGFloat(fontSize), lineSpacing: CGFloat(lineSpacing)) }
                        }
                        
                        bottomMenuBar
                            .padding(.bottom, 30)
                    }
                    .frame(width: totalWidth * leftPanelWidthRatio)

                    Divider().frame(width: 1).background(Color.black.opacity(0.1))
                    
                    // --- [오른쪽] 사전/컨트롤 패널 ---
                    RightPaneView(selectedWord: $selectedWord, glossaryStore: glossaryStore)
                        .frame(width: totalWidth * (1 - leftPanelWidthRatio) - 1)
                }
                handleView(fullWidth: totalWidth)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .sheet(isPresented: $showGlossary) { GlossaryView(glossaryStore: glossaryStore) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShareSheet) { ShareSheet(text: subtitles.joined(separator: "\n")) }
        
        .onReceive(speechManager.$recognizedText) { text in
            if !text.isEmpty {
                subtitles.append(text)
                speechManager.recognizedText = ""
            }
        }
    }
}

// MARK: - 2. 하위 뷰 및 기능 로직 (Extension)
extension ContentView {
    
    // 헤더 영역
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
        .padding(.horizontal, 30).padding(.top, 20).padding(.bottom, 10)
    }
    
    // ✨ 자막 스크롤 뷰 (자동 스크롤 및 클릭/수정 기능 포함)
    private var subtitleScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: CGFloat(lineSpacing + 20)) {
                    
                    // [1] 완료된 자막들
                    ForEach(0..<subtitles.count, id: \.self) { index in
                        FlowLayout(spacing: 8) {
                            let words = subtitles[index].components(separatedBy: " ")
                            ForEach(0..<words.count, id: \.self) { wIndex in
                                let wordString = words[wIndex]
                                let cleanWord = wordString.trimmingCharacters(in: .punctuationCharacters)
                                
                                Text(glossaryStore.annotate(text: wordString))
                                    .font(.system(size: CGFloat(fontSize)))
                                    .foregroundColor(.black)
                                    .contentShape(Rectangle())
                                    .onTapGesture { self.selectedWord = cleanWord }
                                    .onLongPressGesture {
                                        showEditAlert(lineIndex: index, wordIndex: wIndex, currentWord: wordString)
                                    }
                            }
                        }
                        .id("line_\(index)")
                    }
                    
                    // [2] 실시간 인식 중인 자막
                    if !speechManager.currentlyRecognizing.isEmpty {
                        FlowLayout(spacing: 8) {
                            let currentWords = speechManager.currentlyRecognizing.components(separatedBy: " ")
                            ForEach(0..<currentWords.count, id: \.self) { cwIndex in
                                let cWordString = currentWords[cwIndex]
                                Text(glossaryStore.annotate(text: cWordString))
                                    .font(.system(size: CGFloat(fontSize)))
                                    .foregroundColor(.black.opacity(0.6))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        self.selectedWord = cWordString.trimmingCharacters(in: .punctuationCharacters)
                                    }
                            }
                        }
                        .id("realtime_marker")
                    }
                    
                    // ⚓️ 스크롤용 닻
                    Color.clear.frame(height: 50).id("bottom_anchor")
                }
                .padding(.leading, 100).padding(.trailing, 20).padding(.top, 40)
            }
            // 💡 자동 스크롤 로직
            .onChange(of: speechManager.currentlyRecognizing) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: subtitles.count) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    // 스크롤 이동 함수
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if !isScrollPaused {
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom_anchor", anchor: .bottom)
                }
            }
        }
    }

    // 하단 메뉴바
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
        .padding(.horizontal, 25).padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    // 녹음 버튼
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

    // 언어 토글
    private var languageToggleView: some View {
        HStack(spacing: 0) {
            Text("KR").font(.system(size: 11, weight: .bold)).foregroundColor(speechManager.currentLanguage == "ko-KR" ? .white : .gray).padding(.horizontal, 8).padding(.vertical, 4).background(speechManager.currentLanguage == "ko-KR" ? primaryBlue : Color.clear)
            Text("EN").font(.system(size: 11, weight: .bold)).foregroundColor(speechManager.currentLanguage == "en-US" ? .white : .gray).padding(.horizontal, 8).padding(.vertical, 4).background(speechManager.currentLanguage == "en-US" ? primaryBlue : Color.clear)
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.gray.opacity(0.2)))
        .onTapGesture { speechManager.toggleLanguage() }
    }

    // 패널 크기 조절 핸들
    private func handleView(fullWidth: CGFloat) -> some View {
        ZStack {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.system(size: 16, weight: .thin))
                .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.6))
                .padding(.vertical, 12).padding(.horizontal, 6)
                .background(Capsule().fill(.ultraThinMaterial.opacity(0.5)))
        }
        .position(x: fullWidth * leftPanelWidthRatio, y: UIScreen.main.bounds.height * 0.5)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let actualDelta = value.translation.width - lastTranslation
                    let deltaRatio = actualDelta / fullWidth
                    let newRatio = leftPanelWidthRatio + deltaRatio
                    if newRatio > 0.2 && newRatio < 0.8 { leftPanelWidthRatio = newRatio }
                    lastTranslation = value.translation.width
                }
                .onEnded { _ in lastTranslation = 0 }
        )
    }

    // ✨ [수정 완료] 자막 수정을 위한 팝업창 함수 (정확한 위치 배치)
    private func showEditAlert(lineIndex: Int, wordIndex: Int, currentWord: String) {
        let alert = UIAlertController(title: "단어 수정", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in textField.text = currentWord }
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            if let newText = alert.textFields?.first?.text {
                var wordList = subtitles[lineIndex].components(separatedBy: " ")
                if wordIndex < wordList.count {
                    wordList[wordIndex] = newText
                    subtitles[lineIndex] = wordList.joined(separator: " ")
                }
            }
        })
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(alert, animated: true)
        }
    }
}

// MARK: - 3. 필수 보조 부품 (컴포넌트)
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

struct LegalPadBackground: View {
    var fontSize: CGFloat; var lineSpacing: CGFloat
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color(red: 255/255, green: 253/255, blue: 208/255)
                Path { path in
                    let rowHeight = fontSize + lineSpacing + 12
                    var y = rowHeight + 40
                    while y < geo.size.height {
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += rowHeight
                    }
                }.stroke(Color.blue.opacity(0.1), lineWidth: 1)
                
                HStack(spacing: 2) {
                    Rectangle().fill(Color.red.opacity(0.2)).frame(width: 1.5)
                    Rectangle().fill(Color.red.opacity(0.2)).frame(width: 1.5)
                }
                .padding(.leading, 80).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var width: CGFloat = 0; var height: CGFloat = 0; var currentX: CGFloat = 0; var currentY: CGFloat = 0; var lineHeight: CGFloat = 0
        for size in sizes {
            if currentX + size.width > (proposal.width ?? .infinity) {
                currentX = 0; currentY += lineHeight + spacing; lineHeight = 0
            }
            currentX += size.width + spacing; lineHeight = max(lineHeight, size.height)
            width = max(width, currentX); height = max(height, currentY + lineHeight)
        }
        return CGSize(width: width, height: height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var currentX: CGFloat = bounds.minX; var currentY: CGFloat = bounds.minY; var lineHeight: CGFloat = 0
        for index in subviews.indices {
            if currentX + sizes[index].width > bounds.maxX {
                currentX = bounds.minX; currentY += lineHeight + spacing; lineHeight = 0
            }
            subviews[index].place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += sizes[index].width + spacing; lineHeight = max(lineHeight, sizes[index].height)
        }
    }
}

// MARK: - 4. 음성 인식 엔진 (SpeechManager)
class SpeechManager: ObservableObject {
    @Published var recognizedText: String = ""
    @Published var currentlyRecognizing: String = ""
    @Published var isRecording: Bool = false
    @Published var currentLanguage = "en-US"
    @Published var timeElapsed: Int = 0
    private var timer: Timer?
    private var recognizer: SPXSpeechRecognizer?
    
    var timeString: String {
        let minutes = timeElapsed / 60; let seconds = timeElapsed % 60
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
        let azureKey = "Bd4s4ErdcKXQEUmGLviSnEIdcfnlE0xl128Lz6AEXtjXa3GFc7mKJQQJ99CCACNns7RXJ3w3AAAYACOGEb7n"
        let azureRegion = "koreacentral"
        guard let config = try? SPXSpeechConfiguration(subscription: azureKey, region: azureRegion) else { return }
        config.speechRecognitionLanguage = currentLanguage
        guard let speechRecognizer = try? SPXSpeechRecognizer(speechConfiguration: config, audioConfiguration: SPXAudioConfiguration()) else { return }
        self.recognizer = speechRecognizer
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
