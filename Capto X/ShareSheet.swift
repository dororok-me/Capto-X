import SwiftUI
import UIKit

// MARK: - 📤 공유 시트 (카톡, 메일, 메모장 등으로 내보내기)
// ShareSheet.swift 파일 수정
struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateString = formatter.string(from: Date())
        
        // 단순 텍스트가 아니라 파일 형태로 공유하면 이름이 붙습니다.
        let fileName = "CaptoX_Subtitle_\(dateString).txt"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try? text.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
