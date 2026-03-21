import Foundation
import SwiftUI
import Combine
import UIKit // ✨ NSMutableParagraphStyle 사용을 위해 필요합니다.

// MARK: - 단어장 데이터 구조
struct GlossaryEntry: Identifiable, Codable {
    var id = UUID()
    var source: String
    var target: String
}

// MARK: - 단어장 관리 및 주석 로직
class GlossaryStore: ObservableObject {
    @Published var entries: [GlossaryEntry] = []
    private let saveKey = "glossary_entries"
    
    init() {
        load()
    }
    
    // ✨ 핵심: 설정값(AppStorage) 및 문단 스타일(줄 간격) 반영
    func annotate(text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString("") }
        
        // ⚙️ UserDefaults에서 설정값 실시간 읽기
        let fontSize = CGFloat(UserDefaults.standard.double(forKey: "fontSize"))
        let lineSpacing = CGFloat(UserDefaults.standard.double(forKey: "lineSpacing"))
        let sizeRatio = CGFloat(UserDefaults.standard.double(forKey: "glossaryFontSizeRatio"))
        let colorName = UserDefaults.standard.string(forKey: "glossaryColor") ?? "secondary"
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        let isEnabled = UserDefaults.standard.bool(forKey: "isGlossaryEnabled")
        
        // 1. 문단 스타일 설정 (줄 간격 핵심 로직)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        // 통역 자막 특성상 왼쪽 정렬을 기본으로 합니다.
        paragraphStyle.alignment = .left
        
        // 2. 기본 AttributedString 생성 및 스타일 적용
        var result = AttributedString(text)
        result.font = .systemFont(ofSize: fontSize, weight: .regular)
        result.foregroundColor = isDarkMode ? .white : .black
        
        // ✨ ParagraphStyle 주입 (이게 있어야 lineSpacing이 먹힙니다)
        result.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
        
        // 3. 글로서리 기능이 꺼져있으면 여기서 즉시 반환
        if !isEnabled { return result }
        
        // 4. 단어 매칭 로직 (Whole Word Matching)
        let plainString = text
        var matches: [(range: Range<String.Index>, translation: String)] = []
        
        for entry in entries {
            let terms = [(entry.source, entry.target), (entry.target, entry.source)]
            for item in terms {
                let trimmedTerm = item.0.trimmingCharacters(in: .whitespaces)
                guard !trimmedTerm.isEmpty else { continue }
                
                let escapedTerm = NSRegularExpression.escapedPattern(for: trimmedTerm)
                let pattern = "\\b\(escapedTerm)\\b"
                
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let nsRange = NSRange(plainString.startIndex..<plainString.endIndex, in: plainString)
                    let results = regex.matches(in: plainString, options: [], range: nsRange)
                    
                    for match in results {
                        if let range = Range(match.range, in: plainString) {
                            matches.append((range: range, translation: item.1))
                        }
                    }
                }
            }
        }
        
        // 5. 주석 색상 결정
        let annoColor: Color = {
            switch colorName {
            case "blue": return .blue
            case "red": return .red
            case "green": return .green
            default: return .secondary
            }
        }()
        
        // 6. 역순으로 주석 삽입 (인덱스 꼬임 방지)
        let sortedMatches = matches.sorted { $0.range.lowerBound > $1.range.lowerBound }
        var lastAppliedRange: Range<String.Index>? = nil
        
        for match in sortedMatches {
            if let last = lastAppliedRange, match.range.upperBound > last.lowerBound { continue }
            
            if let attrRange = Range(match.range, in: result) {
                // 하이라이트 배경 (나이트 모드 고려)
                result[attrRange].backgroundColor = Color.yellow.opacity(isDarkMode ? 0.25 : 0.35)
                
                // 주석 텍스트 생성
                var annotation = AttributedString(" (\(match.translation))")
                annotation.font = .systemFont(ofSize: fontSize * sizeRatio, weight: .medium)
                annotation.foregroundColor = annoColor
                
                // 주석에도 줄 간격 스타일이 유지되도록 머지 (선택 사항)
                annotation.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
                
                result.insert(annotation, at: attrRange.upperBound)
                lastAppliedRange = match.range
            }
        }
        
        return result
    }
    
    // MARK: - CRUD 로직 및 저장 (기존과 동일)
    func add(source: String, target: String) {
        let s = source.trimmingCharacters(in: .whitespaces)
        let t = target.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty && !t.isEmpty {
            entries.append(GlossaryEntry(source: s, target: t))
            save()
        }
    }
    
    func update(id: UUID, source: String, target: String) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].source = source.trimmingCharacters(in: .whitespaces)
            entries[index].target = target.trimmingCharacters(in: .whitespaces)
            save()
        }
    }
    
    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }
    
    func resetAll() {
        entries.removeAll()
        save()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
            entries = decoded
        }
    }
    
    func exportToCSV() -> String {
        return entries.map { "\($0.source),\($0.target)" }.joined(separator: "\n")
    }
    
    func importFromCSV(content: String, overwrite: Bool) {
        if overwrite { entries.removeAll() }
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ",")
            if parts.count >= 2 {
                add(source: parts[0], target: parts[1])
            }
        }
    }
}
