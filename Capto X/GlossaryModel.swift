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
    
    // ✨ [에러 해결] GlossaryView의 'overwrite' 인자를 인식하도록 수정
        func importFromCSV(contents: String, overwrite: Bool = false) {
            let lines = contents.components(separatedBy: .newlines)
            var newEntries: [GlossaryEntry] = []
            
            // 💡 overwrite가 true면 기존 목록을 비우고 시작합니다.
            if overwrite {
                self.entries.removeAll()
            }

            let existingSources = Set(entries.map { $0.source.lowercased().trimmingCharacters(in: .whitespaces) })
            var addedSources = Set<String>()

            for line in lines {
                let columns = line.components(separatedBy: ",")
                if columns.count >= 2 {
                    let s = columns[0].trimmingCharacters(in: .whitespaces)
                    let t = columns[1].trimmingCharacters(in: .whitespaces)
                    let lowerS = s.lowercased()
                    
                    if !s.isEmpty && !t.isEmpty && !existingSources.contains(lowerS) && !addedSources.contains(lowerS) {
                        newEntries.append(GlossaryEntry(source: s, target: t))
                        addedSources.insert(lowerS)
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.entries.append(contentsOf: newEntries)
                self.save()
            }
        }
    
    // ✨ 주석 로직 (자막에 글로서리 표시)
    // ContentView에서 단어 하나씩 넘어오므로, 단어 단위로 매칭합니다.
    // 예: "School" → "School(학교)", "학교" → "학교(school)"
    // ✨ [강화된 인식 로직] 자막 UI는 그대로 유지하고 인식률만 높였습니다.
    // ✨ [숙어 대응 annotate] 긴 숙어부터 우선적으로 찾아 빨간 괄호를 붙입니다.
    // ✨ [에러 해결] 인자 순서 교정 및 숙어 인식 로직 강화
        func annotate(text: String) -> AttributedString {
            guard !text.isEmpty else { return AttributedString("") }
            
            let fontSize = CGFloat(UserDefaults.standard.double(forKey: "fontSize"))
            let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
            let finalFontSize = fontSize > 0 ? fontSize : 26
            
            if entries.isEmpty {
                var basic = AttributedString(text)
                basic.font = .systemFont(ofSize: finalFontSize)
                basic.foregroundColor = isDarkMode ? .white : .black
                return basic
            }
            
            // 💡 긴 숙어부터 찾도록 글자 수 내림차순 정렬
            let sortedEntries = entries.sorted { $0.source.count > $1.source.count }
            var segments: [(text: String, translation: String?)] = [(text, nil)]
            
            for entry in sortedEntries {
                var nextSegments: [(text: String, translation: String?)] = []
                for segment in segments {
                    if segment.translation != nil {
                        nextSegments.append(segment)
                        continue
                    }
                    
                    let pattern = "\\b\(NSRegularExpression.escapedPattern(for: entry.source))\\b"
                    // ✅ [해결] pattern 인자를 options보다 앞에 배치했습니다.
                    if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                        let fullString = segment.text
                        let range = NSRange(location: 0, length: fullString.utf16.count)
                        let matches = regex.matches(in: fullString, options: [], range: range)
                        
                        if matches.isEmpty {
                            nextSegments.append(segment)
                            continue
                        }
                        
                        var lastIndex = 0
                        for match in matches {
                            let matchRange = match.range
                            if let preRange = Range(NSRange(location: lastIndex, length: matchRange.location - lastIndex), in: fullString) {
                                let preText = String(fullString[preRange])
                                if !preText.isEmpty { nextSegments.append((preText, nil)) }
                            }
                            if let foundRange = Range(matchRange, in: fullString) {
                                let foundText = String(fullString[foundRange])
                                nextSegments.append((foundText, entry.target))
                            }
                            lastIndex = matchRange.location + matchRange.length
                        }
                        if lastIndex < fullString.utf16.count {
                            let suffix = String(fullString.dropFirst(lastIndex))
                            nextSegments.append((suffix, nil))
                        }
                    } else {
                        nextSegments.append(segment)
                    }
                }
                segments = nextSegments
            }
            
            var result = AttributedString("")
            for segment in segments {
                var attr = AttributedString(segment.text)
                attr.font = .systemFont(ofSize: finalFontSize)
                attr.foregroundColor = isDarkMode ? .white : .black
                result.append(attr)
                
                if let target = segment.translation {
                    var annot = AttributedString("(\(target))")
                    annot.font = .systemFont(ofSize: finalFontSize)
                    annot.foregroundColor = .red // 뜻만 빨간색
                    result.append(annot)
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
