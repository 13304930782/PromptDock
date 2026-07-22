import SwiftUI

struct LanguageMenu: View {
    @Binding var selection: String

    var body: some View {
        Menu {
            Picker("Language", selection: $selection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.title).tag(language.rawValue)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Language", systemImage: "globe")
        }
        .help("Language")
        .accessibilityLabel("Language")
    }
}
