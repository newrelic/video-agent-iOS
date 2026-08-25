import UIKit

/// Append-only, auto-scrolling event log used to trace every THEOplayer event as it fires.
final class EventLogView: UIView {

    private let textView = UITextView()
    private var lineCount = 0
    private let maxLines = 500

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        textView.backgroundColor = .black
        textView.textColor = .green
        textView.layer.cornerRadius = 6
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// Appends one timestamped line. Safe to call from any thread.
    func log(_ message: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.log(message) }
            return
        }
        let timestamp = Self.timestampFormatter.string(from: Date())
        textView.text += "[\(timestamp)] \(message)\n"
        lineCount += 1
        if lineCount > maxLines, let text = textView.text, let firstNewline = text.firstIndex(of: "\n") {
            // Trim from the top so a long soak test doesn't grow this view unbounded.
            textView.text = String(text[text.index(after: firstNewline)...])
            lineCount -= 1
        }
        let bottom = NSRange(location: (textView.text as NSString).length - 1, length: 1)
        textView.scrollRangeToVisible(bottom)
    }

    func clear() {
        textView.text = ""
        lineCount = 0
    }
}
