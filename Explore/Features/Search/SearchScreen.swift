import SwiftUI
import UIKit

/// Search for blogs and tags, pushed from Discover's search button. The
/// field sits in the bar beside the back button and takes the keyboard
/// at once, as feed apps have it.
struct SearchScreen: View {
    @State private var query = ""
    @State private var width: CGFloat = 0

    var body: some View {
        SearchContent(query: query)
            .onGeometryChange(for: CGFloat.self) { geometry in
                geometry.size.width
            } action: { width in
                self.width = width
            }
            .navigationTitle("Search")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // The bar sizes its middle to fit, so the field asks for
                    // the room beside the back button itself.
                    SearchField(text: $query)
                        .frame(width: min(max(width - 92, 160), 600))
                }
            }
    }
}

/// A search field shaped like the system's, which stays in the bar instead
/// of covering it while in use.
private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            FocusedTextField(text: $text, placeholder: String(localized: "Search blogs and tags"))
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// A text field that takes the keyboard once it is on screen. SwiftUI's
/// focus state cannot reach a field in the navigation bar.
private struct FocusedTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.returnKeyType = .search
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        Task {
            // The keyboard is refused while the push is still running.
            try? await Task.sleep(for: .milliseconds(400))
            field.becomeFirstResponder()
        }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text {
            field.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func changed(_ field: UITextField) {
            text.wrappedValue = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}
