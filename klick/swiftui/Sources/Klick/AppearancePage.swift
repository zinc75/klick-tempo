// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import MatrixKit
import AppearanceKit

/// The look of the application: dark, the one of the system or light, and the accent. The same page in every application of the
/// collection (the controls are in AppearanceKit).
struct AppearancePage: View {
    @Environment(AppearanceSettings.self) private var appearance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Affichage").font(.title2).fontWeight(.semibold)
                    Text("Le thème de la fenêtre et la couleur d'accent.")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                VStack(spacing: 0) {
                    SettingRow(title: "Apparence", detail: String(localized: "Sombre par défaut ; Système suit le réglage de macOS.")) {
                        AppearanceModePicker(settings: appearance)
                    }
                    Divider()
                    SettingRow(title: "Couleur d'accent") {
                        AccentSwatches(settings: appearance)
                    }
                }
                .padding(.horizontal, 14)
                .blockBackground()
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 26)
        }
        .scrollEdgeEffectStyleIfAvailable()
    }
}
