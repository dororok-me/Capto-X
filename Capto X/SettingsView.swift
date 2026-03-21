import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // ✨ UserDefaults에 자동 저장되는 설정값들
    @AppStorage("fontSize") private var fontSize: Double = 26.0
    @AppStorage("lineSpacing") private var lineSpacing: Double = 10.0
    @AppStorage("glossaryFontSizeRatio") private var glossaryFontSizeRatio: Double = 0.65
    @AppStorage("glossaryColor") private var glossaryColor: String = "secondary" // secondary, blue, red 등
    @AppStorage("isGlossaryEnabled") private var isGlossaryEnabled: Bool = true
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                // 1 & 2. 글자 및 레이아웃
                Section(header: Text("Layout & Text")) {
                    VStack(alignment: .leading) {
                        Text("Font Size: \(Int(fontSize))")
                        Slider(value: $fontSize, in: 18...45, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Line Spacing: \(Int(lineSpacing))")
                        Slider(value: $lineSpacing, in: 0...30, step: 2)
                    }
                }
                
                // 3 & 4. 글로서리 옵션
                Section(header: Text("Glossary Options")) {
                    Toggle("Enable Glossary", isOn: $isGlossaryEnabled)
                    
                    if isGlossaryEnabled {
                        VStack(alignment: .leading) {
                            Text("Glossary Size Ratio: \(String(format: "%.2f", glossaryFontSizeRatio))")
                            Slider(value: $glossaryFontSizeRatio, in: 0.4...0.9, step: 0.05)
                        }
                        
                        Picker("Glossary Color", selection: $glossaryColor) {
                            Text("Gray").tag("secondary")
                            Text("Blue").tag("blue")
                            Text("Red").tag("red")
                            Text("Green").tag("green")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                
                // 5. 나이트 모드
                Section(header: Text("Appearance")) {
                    Toggle("Night Mode", isOn: $isDarkMode)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
