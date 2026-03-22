import SwiftUI

struct RightPaneView: View {
    @Binding var selectedWord: String
    @ObservedObject var glossaryStore: GlossaryStore
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    // ✨ 각 창의 높이 상태 (드래그로 변함)
    @State private var dicHeight: CGFloat = 450
    @State private var glossaryHeight: CGFloat = 250
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // 1. [상단] 사전 영역
                sectionView(title: "다음 사전", icon: "character.book.closed", color: .blue) {
                    if !selectedWord.isEmpty {
                        DaumDicView(searchTerm: selectedWord)
                    } else {
                        VStack {
                            Spacer()
                            Text("단어를 터치하여 검색").foregroundColor(.gray)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: dicHeight)
                
                // 🔥 첫 번째 드래그 핸들 (사전 - 글로서리 사이)
                dragHandle { value in
                    let newHeight = dicHeight + value.translation.height
                    if newHeight > 150 && newHeight < geometry.size.height * 0.6 {
                        dicHeight = newHeight
                    }
                }

                // 2. [중앙] 글로서리 영역
                sectionView(title: "글로서리", icon: "list.bullet.rectangle", color: .green) {
                    List(glossaryStore.entries) { entry in
                        HStack {
                            Text(entry.source).fontWeight(.semibold)
                            Spacer()
                            Text(entry.target).foregroundColor(.secondary)
                        }
                        .font(.system(size: 14))
                    }
                    .listStyle(.plain)
                }
                .frame(height: glossaryHeight)
                
                // 🔥 두 번째 드래그 핸들 (글로서리 - 도량형 사이)
                dragHandle { value in
                    let newHeight = glossaryHeight + value.translation.height
                    // 도량형 영역이 너무 작아지지 않게 제한
                    if newHeight > 100 && (dicHeight + newHeight) < geometry.size.height - 150 {
                        glossaryHeight = newHeight
                    }
                }

                // 3. [하단] 도량형 변환기 (남은 공간 자동 채움)
                sectionView(title: "도량형/환율", icon: "arrow.left.and.right", color: .orange) {
                    UnitConverterTabView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(isDarkMode ? Color.black : Color.white)
    }
    
    // 섹션 공통 디자인
    private func sectionView<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Label(title, systemImage: icon)
                .font(.caption).bold().padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(color.opacity(0.1))
            content()
        }
    }
    
    // ✨ 드래그 핸들 (에러 유발하는 .cursor 제거 버전)
    private func dragHandle(onDrag: @escaping (DragGesture.Value) -> Void) -> some View {
        ZStack {
            Color.gray.opacity(0.05).frame(height: 24) // 터치 영역 넉넉히
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 5)
        }
        .gesture(DragGesture().onChanged(onDrag))
    }
}

// MARK: - 3단 구성을 위한 도량형 변환기 (누락 에러 해결 ✨)
struct UnitConverterTabView: View {
    @State private var inputValue: String = ""
    private let rate: Double = 1350.0
    
    var body: some View {
        Form {
            Section("수치 입력") {
                TextField("숫자를 입력하세요", text: $inputValue)
                    .keyboardType(.decimalPad)
                    .onChange(of: inputValue) { newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if let num = Double(filtered.replacingOccurrences(of: ",", with: "")) {
                            let formatter = NumberFormatter()
                            formatter.numberStyle = .decimal
                            inputValue = formatter.string(from: NSNumber(value: num)) ?? ""
                        } else if newValue.isEmpty { inputValue = "" }
                    }
            }
            
            if let val = Double(inputValue.replacingOccurrences(of: ",", with: "")) {
                Section("실시간 변환") {
                    converterRow(label: "환율 ($ ➡ ₩)", value: val * rate, unit: "원", color: .blue)
                    converterRow(label: "면적 (평 ➡ ㎡)", value: val * 3.3057, unit: "㎡")
                    converterRow(label: "길이 (마일 ➡ km)", value: val * 1.6093, unit: "km")
                    converterRow(label: "온도 (℉ ➡ ℃)", value: (val - 32) * 5/9, unit: "℃")
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private func converterRow(label: String, value: Double, unit: String, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text("\(format(value)) \(unit)").bold().foregroundColor(color)
        }
    }
    
    func format(_ v: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: v)) ?? ""
    }
}
