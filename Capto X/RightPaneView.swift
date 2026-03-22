import SwiftUI

struct RightPaneView: View {
    @Binding var selectedWord: String
    @ObservedObject var glossaryStore: GlossaryStore
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    @State private var dicHeight: CGFloat = 450
    @State private var glossaryHeight: CGFloat = 250
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                
                // 1. [상단] 다음 사전 (가독성 위해 상단 라벨 크게)
                sectionHeader(title: "다음 사전", icon: "character.book.closed", color: .blue)
                
                VStack(spacing: 0) {
                    if !selectedWord.isEmpty {
                        // 💡 DaumDicView 자체에서 zoom을 조절하므로 여기서는 너비만 맞춤
                        DaumDicView(searchTerm: selectedWord)
                    } else {
                        Text("단어를 터치하세요").font(.title3).foregroundColor(.gray).frame(maxHeight: .infinity)
                    }
                }
                .frame(height: dicHeight)
                
                dragHandle { value in
                    let newHeight = dicHeight + value.translation.height
                    if newHeight > 150 && newHeight < geometry.size.height * 0.6 { dicHeight = newHeight }
                }

                // 2. [중앙] 글로서리 (폰트 크기 14 -> 20으로 확대 ✨)
                sectionHeader(title: "글로서리", icon: "list.bullet.rectangle", color: .green)
                
                List(glossaryStore.entries) { entry in
                    HStack {
                        Text(entry.source)
                            .font(.system(size: 20, weight: .bold)) // 폰트 대폭 확대
                        Spacer()
                        Text(entry.target)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .frame(height: glossaryHeight)
                
                dragHandle { value in
                    let newHeight = glossaryHeight + value.translation.height
                    if newHeight > 100 && (dicHeight + newHeight) < geometry.size.height - 150 { glossaryHeight = newHeight }
                }

                // 3. [하단] 도량형 (폰트 및 간격 확대)
                sectionHeader(title: "도량형/환율", icon: "arrow.left.and.right", color: .orange)
                
                UnitConverterTabView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(isDarkMode ? Color.black : Color.white)
    }
    
    // 섹션 헤더 디자인 (더 크게 변경)
    private func sectionHeader(title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 16, weight: .black)).padding(10) // 헤더 폰트 확대
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.15))
    }
    
    private func dragHandle(onDrag: @escaping (DragGesture.Value) -> Void) -> some View {
        ZStack {
            Color.gray.opacity(0.05).frame(height: 30)
            RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.3)).frame(width: 60, height: 6)
        }
        .gesture(DragGesture().onChanged(onDrag))
    }
}

// MARK: - 도량형 변환기 (글자 크기 및 입력창 확대 ✨)
struct UnitConverterTabView: View {
    @State private var inputValue: String = ""
    private let rate: Double = 1350.0
    
    var body: some View {
        Form {
            Section {
                TextField("숫자 입력", text: $inputValue)
                    .font(.system(size: 24, weight: .bold)) // 입력창 폰트 확대
                    .keyboardType(.decimalPad)
                    .padding(.vertical, 5)
                    .onChange(of: inputValue) { newValue in
                        let filtered = newValue.filter { "0123456789.".contains($0) }
                        if let num = Double(filtered.replacingOccurrences(of: ",", with: "")) {
                            let formatter = NumberFormatter()
                            formatter.numberStyle = .decimal
                            inputValue = formatter.string(from: NSNumber(value: num)) ?? ""
                        } else if newValue.isEmpty { inputValue = "" }
                    }
            } header: {
                Text("변환할 수치").font(.caption).bold()
            }
            
            if let val = Double(inputValue.replacingOccurrences(of: ",", with: "")) {
                Section {
                    converterRow(label: "환율 ($➡₩)", value: val * rate, unit: "원", color: .blue)
                    converterRow(label: "면적 (평➡㎡)", value: val * 3.3057, unit: "㎡")
                    converterRow(label: "길이 (mi➡km)", value: val * 1.6093, unit: "km")
                    converterRow(label: "온도 (℉➡℃)", value: (val - 32) * 5/9, unit: "℃")
                } header: {
                    Text("실시간 결과").font(.caption).bold()
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    private func converterRow(label: String, value: Double, unit: String, color: Color = .primary) -> some View {
        HStack {
            Text(label).font(.system(size: 18)) // 레이블 확대
            Spacer()
            Text("\(format(value)) \(unit)")
                .font(.system(size: 20, weight: .black)) // 결과값 대폭 확대
                .foregroundColor(color)
        }
        .padding(.vertical, 2)
    }
    
    func format(_ v: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: v)) ?? ""
    }
}
