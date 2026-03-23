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
    // ✨ [수정 기능] 특정 단어의 내용을 변경하고 저장하는 '요리법'입니다.
        func update(id: UUID, source: String, target: String) {
            if let index = entries.firstIndex(where: { $0.id == id }) {
                entries[index].source = source.trimmingCharacters(in: .whitespaces)
                entries[index].target = target.trimmingCharacters(in: .whitespaces)
                
                save() // 변경된 내용을 기기에 저장
                objectWillChange.send() // 화면에 "바뀌었으니 다시 그려라!"라고 신호 보냄
            }
        }
    @Published var entries: [GlossaryEntry] = []
    private let saveKey = "glossary_entries"
    
    init() {
        load()
    }
    
    // ✨ [리셋 기능] 모든 데이터를 삭제하고 저장소까지 비웁니다.
    func resetAll() {
        DispatchQueue.main.async {
            self.entries.removeAll()
            self.save()
            print("🗑️ 용어집이 초기화되었습니다.")
        }
    }
    
    // ✨ [고속 CSV 임포트] 비동기로 안전하게 처리
    func importFromCSV(contents: String, overwrite: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let lines = contents.components(separatedBy: .newlines)
            var newEntries: [GlossaryEntry] = []
            
            var existingSources = overwrite ? Set<String>() : Set(self.entries.map { $0.source.lowercased().trimmingCharacters(in: .whitespaces) })
            var localAddedSources = Set<String>()

            for line in lines {
                let columns = line.components(separatedBy: ",")
                if columns.count >= 2 {
                    let s = columns[0].trimmingCharacters(in: .whitespaces)
                    let t = columns[1].trimmingCharacters(in: .whitespaces)
                    let lowerS = s.lowercased()
                    
                    if !s.isEmpty && !t.isEmpty && !existingSources.contains(lowerS) && !localAddedSources.contains(lowerS) && lowerS != "source" {
                        newEntries.append(GlossaryEntry(source: s, target: t))
                        localAddedSources.insert(lowerS)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if overwrite { self.entries = newEntries }
                else { self.entries.append(contentsOf: newEntries) }
                self.save()
            }
        }
    }
    
    // ✨ [숙어 인식] 문장 내에서 긴 숙어부터 찾아 강조
    func annotate(text: String) -> AttributedString {
        guard !text.isEmpty else { return AttributedString("") }
        
        let fontSize = CGFloat(UserDefaults.standard.double(forKey: "fontSize"))
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        let finalFontSize = fontSize > 0 ? fontSize : 26
        
        let isEnabled: Bool = UserDefaults.standard.object(forKey: "isGlossaryEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "isGlossaryEnabled")
        
        if !isEnabled || entries.isEmpty {
            var basic = AttributedString(text)
            basic.font = .systemFont(ofSize: finalFontSize)
            basic.foregroundColor = isDarkMode ? .white : .black
            return basic
        }
        
        let sortedEntries = entries.sorted { $0.source.count > $1.source.count }
        var segments: [(text: String, translation: String?)] = [(text, nil)]
        
        for entry in sortedEntries {
            var nextSegments: [(text: String, translation: String?)] = []
            for segment in segments {
                if segment.translation != nil {
                    nextSegments.append(segment)
                    continue
                }
                
                let escapedSource = NSRegularExpression.escapedPattern(for: entry.source)
                let pattern = "(?<=^|[\\s\\p{P}])\(escapedSource)(?=$|[\\s\\p{P}])"
                
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
        
        var finalResult = AttributedString("")
        for segment in segments {
            var attr = AttributedString(segment.text)
            attr.font = .systemFont(ofSize: finalFontSize)
            attr.foregroundColor = isDarkMode ? .white : .black
            finalResult.append(attr)
            
            if let translation = segment.translation {
                var annot = AttributedString("(\(translation))")
                annot.font = .systemFont(ofSize: finalFontSize)
                annot.foregroundColor = .red
                finalResult.append(annot)
            }
        }
        return finalResult
    }
    
    // MARK: - 기본 로직
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
    
    func exportToCSV() -> String {
        var csvString = "Source,Target\n"
        for entry in entries {
            csvString += "\(entry.source),\(entry.target)\n"
        }
        return csvString
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
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
} // 👈 마지막 괄호 확인
