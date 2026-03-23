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
    // ContentView에서 단어 하나씩 넘어오므로, 단어 단위로 매칭합니다.
    // 예: "School" → "School(학교)", "학교" → "학교(school)"
    func annotate(text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString("") }
        
        let fontSize = CGFloat(UserDefaults.standard.double(forKey: "fontSize"))
        let lineSpacing = CGFloat(UserDefaults.standard.double(forKey: "lineSpacing"))
        let sizeRatio = CGFloat(UserDefaults.standard.double(forKey: "glossaryFontSizeRatio"))
        let colorName = UserDefaults.standard.string(forKey: "glossaryColor") ?? "secondary"
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        
        // ✨ [핵심 수정] UserDefaults.bool()은 값이 없으면 false를 반환함
        // Settings에서 한번도 토글 안 했으면 false가 되어 글로서리가 안 보이는 버그!
        // object(forKey:)로 nil 체크해서 기본값을 true로 처리
        let isEnabled: Bool
        if UserDefaults.standard.object(forKey: "isGlossaryEnabled") == nil {
            isEnabled = true  // 기본값: 글로서리 켜짐
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: "isGlossaryEnabled")
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.alignment = .left
        
        var result = AttributedString(text)
        result.font = .systemFont(ofSize: fontSize > 0 ? fontSize : 18, weight: .regular)
        result.foregroundColor = isDarkMode ? .white : .black
        result.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
        
        if !isEnabled { return result }
        
        // ✨ [핵심] 단어 앞뒤의 구두점만 제거 (중간 글자는 건드리지 않음)
        // 예: "are," → "are", "School." → "School", "학교" → "학교"
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var cleanWord = trimmed
        // 앞쪽 구두점 제거
        while let first = cleanWord.first, !first.isLetter && !first.isNumber {
            cleanWord.removeFirst()
        }
        // 뒤쪽 구두점 제거
        while let last = cleanWord.last, !last.isLetter && !last.isNumber {
            cleanWord.removeLast()
        }
        
        guard !cleanWord.isEmpty else { return result }
        
        // ✨ 글로서리에서 매칭되는 번역어 찾기
        var translation: String? = nil
        let lowerClean = cleanWord.lowercased()
        
        for entry in entries {
            let src = entry.source.trimmingCharacters(in: .whitespaces)
            let tgt = entry.target.trimmingCharacters(in: .whitespaces)
            
            // source와 매칭되면 target을 보여줌 (예: School → 학교)
            if src.lowercased() == lowerClean {
                translation = tgt
                break
            }
            // target과 매칭되면 source를 보여줌 (예: 학교 → School)
            if tgt.lowercased() == lowerClean {
                translation = src
                break
            }
        }
        
        // ✨ 매칭된 단어가 있으면 "(번역어)" 를 뒤에 붙임
        if let found = translation {
            // 원래 단어에 노란 배경 하이라이트
            let fullRange = result.startIndex..<result.endIndex
            result[fullRange].backgroundColor = Color.yellow.opacity(isDarkMode ? 0.25 : 0.35)
            
            // 괄호 안 번역어 스타일
            let annoColor: Color = {
                switch colorName {
                case "blue": return .blue
                case "red": return .red
                case "green": return .green
                default: return .secondary
                }
            }()
            
            var annotation = AttributedString("(\(found))")
            let annoSize = (fontSize > 0 ? fontSize : 18) * (sizeRatio > 0 ? sizeRatio : 0.7)
            annotation.font = .systemFont(ofSize: annoSize, weight: .medium)
            annotation.foregroundColor = annoColor
            annotation.mergeAttributes(AttributeContainer([.paragraphStyle: paragraphStyle]))
            
            result.append(annotation)
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
