import SwiftUI

/// The Explore mark and name, as the website's header shows them; Discover
/// carries it in place of a title.
struct BrandTitle: View {
    var body: some View {
        HStack(spacing: 7) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 19)
            Text(verbatim: "Explore")
                .font(.headline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Explore"))
        .accessibilityAddTraits(.isHeader)
    }
}
