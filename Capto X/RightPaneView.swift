import SwiftUI
import WebKit

struct RightPaneView: View {
    @Binding var selectedWord: String
    @ObservedObject var glossaryStore: GlossaryStore
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    // ✨ 탭 상태를 관리하는 변수 (0: 사전, 1: 글로서리, 2: 도량형)
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. [상단] 탭 선택 메뉴 (이게 보여야 합니다!)
            Picker("Menu", selection: $selectedTab) {
                Text("사전").tag(0)
                Text("글로서리").tag(1)
                Text("도량형").tag(2)
            }
            .pickerStyle(.segmented) // 가로로 나열된 버튼 형태
            .padding()
            .background(isDarkMode ? Color.black : Color.white)
            
            Divider()
            
            // 2. [중앙] 선택된 탭에 따른 화면 표시
            if selectedTab == 0 {
                // --- 사전 탭 ---
                VStack(spacing: 0) {
                    if !selectedWord.isEmpty {
                        HStack {
                            Text("검색어: \(selectedWord)").bold()
                            Spacer()
                            Button("글로서리 추가") {
                                glossaryStore.add(source: selectedWord, target: "")
                            }
                            .buttonStyle(.borderedProminent).controlSize(.mini)
                        }
                        .padding(10).background(Color.blue.opacity(0.05))
                        
                        DaumDicView(searchTerm: selectedWord)
                    } else {
                        Text("단어를 터치하여 검색").foregroundColor(.gray).frame(maxHeight: .infinity)
                    }
                }
            } else if selectedTab == 1 {
                // --- 글로서리 리스트 탭 ---
                List(glossaryStore.entries) { entry in
                    HStack {
                        Text(entry.source).fontWeight(.semibold)
                        Spacer()
                        Text(entry.target).foregroundColor(.secondary)
                    }
                }
                .listStyle(.plain)
            } else {
                // --- 도량형 변환기 탭 ---
                UnitConverterTabView()
            }
        }
    }
}

// MARK: - 도량형 변환기 화면 (RightPaneView 내부에서 사용)
struct UnitConverterTabView: View {
    @State private var inputValue: String = ""
    private let rate: Double = 1350.0 // 기본 환율
    
    var body: some View {
        Form {
            Section("숫자 입력 (실시간 쉼표)") {
                TextField("수치를 입력하세요", text: $inputValue)
                    .keyboardType(.decimalPad)
                    .onChange(of: inputValue) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if let num = Double(filtered) {
                            let formatter = NumberFormatter()
                            formatter.numberStyle = .decimal
                            inputValue = formatter.string(from: NSNumber(value: num)) ?? ""
                        } else if newValue.isEmpty { inputValue = "" }
                    }
            }
            
            if let val = Double(inputValue.replacingOccurrences(of: ",", with: "")) {
                Section("변환 결과") {
                    HStack { Text("환율 ($ ➡ ₩)"); Spacer(); Text("\(format(val * rate)) 원").bold() }
                    HStack { Text("면적 (평 ➡ ㎡)"); Spacer(); Text("\(format(val * 3.3057)) ㎡").bold() }
                    HStack { Text("길이 (마일 ➡ km)"); Spacer(); Text("\(format(val * 1.6093)) km").bold() }
                }
            }
        }
    }
    
    func format(_ v: Double) -> String {
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: v)) ?? ""
    }
}
