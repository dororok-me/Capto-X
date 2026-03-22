import Foundation
import SwiftUI
import Combine
import UIKit

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
    
    // ✨ [RightPaneView 호환] 단어 추가 함수
    func addEntry(word: String, definition: String) {
        let s = word.trimmingCharacters(in: .whitespaces)
        let t = definition.trimmingCharacters(in: .whitespaces)
        
        if !s.isEmpty && !t.isEmpty {
            if !entries.contains(where: { $0.source.lowercased() == s.lowercased() }) {
                entries.append(GlossaryEntry(source: s, target: t))
                save()
            }
        }
    }
    
    // ✨ [GlossaryView 호환] CSV 내보내기 (Export)
    func exportToCSV() -> String {
        // 첫 줄 헤더(선택)를 넣거나 바로 데이터만 넣을 수 있습니다.
        var csvString = "Source,Target\n"
        for entry in entries {
            csvString += "\(entry.source),\(entry.target)\n"
        }
        return csvString
    }
    
    // ✨ [GlossaryView 호환] CSV 가져오기 (Import)
    func importFromCSV(content: String, overwrite: Bool) {
        if overwrite { entries.removeAll() }
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.components(separatedBy: ",")
            if parts.count >= 2 {
                let source = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let target = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 헤더 제외 및 유효성 검사
                if !source.isEmpty && !target.isEmpty && source.lowercased() != "source" {
                    add(source: source, target: target)
                }
            }
        }
        save()
    }
    
    // ✨ 주석 로직 (자막에 글로서리 표시)
    func annotate(text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString("") }
        
        let fontSize = CGFloat(UserDefaults.standard.double(forKey: "fontSize"))
        let lineSpacing = CGFloat(UserDefaults.standard.double(forKey: "lineSpacing"))
        let sizeRatio = CGFloat(UserDefaults.standard.double(forKey: "glossaryFontSizeRatio"))
        let colorName = UserDefaults.standard.string(forKey: "glossaryColor") ?? "secondary"
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        let isEnabled = UserDefaults.standard.bool(forKey: "isGlossaryEnabled")
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = .left
        
        var result = AttributedString(text)
        result.font = .systemFont(ofSize: fontSize > 0 ? fontSize : 18, weight: .regular)
        result.foregroundColor = isDarkMode ? .white : .black
        result.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
        
        if !isEnabled { return result }
        
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
        
        let annoColor: Color = {
            switch colorName {
            case "blue": return .blue
            case "red": return .red
            case "green": return .green
            default: return .secondary
            }
        }()
        
        let sortedMatches = matches.sorted { $0.range.lowerBound > $1.range.lowerBound }
        var lastAppliedRange: Range<String.Index>? = nil
        
        for match in sortedMatches {
            if let last = lastAppliedRange, match.range.upperBound > last.lowerBound { continue }
            
            if let attrRange = Range(match.range, in: result) {
                result[attrRange].backgroundColor = Color.yellow.opacity(isDarkMode ? 0.25 : 0.35)
                
                var annotation = AttributedString(" (\(match.translation))")
                let annoSize = (fontSize > 0 ? fontSize : 18) * (sizeRatio > 0 ? sizeRatio : 0.7)
                annotation.font = .systemFont(ofSize: annoSize, weight: .medium)
                annotation.foregroundColor = annoColor
                annotation.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
                
                result.insert(annotation, at: attrRange.upperBound)
                lastAppliedRange = match.range
            }
        }
        return result
    }
    
    // MARK: - 기본 CRUD 로직
    func add(source: String, target: String) {
        let s = source.trimmingCharacters(in: .whitespaces)
        let t = target.trimmingCharacters(in: .whitespaces)
        if !s.isEmpty && !t.isEmpty {
            if !entries.contains(where: { $0.source.lowercased() == s.lowercased() }) {
                entries.append(GlossaryEntry(source: s, target: t))
                save()
            }
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
}
