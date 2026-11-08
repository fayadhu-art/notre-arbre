import SwiftUI
import ArbreCore

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
    static let turquoise = Color(hex: 0x0F766E)
    static let turquoiseClair = Color(hex: 0xE6F2F0)
    static let corail = Color(hex: 0xFF7A59)
    static let corailTexte = Color(hex: 0xC2410C)
    static let violet = Color(hex: 0x7C3AED)
    static let violetTexte = Color(hex: 0x6D28D9)
    static let encre = Color(hex: 0x1D1D1F)
    static let gris = Color(hex: 0x48484A)
    static let fond = Color(hex: 0xEEF1F4)
}

extension Branche {
    var couleur: Color {
        switch self {
        case .moi: .turquoise
        case .pere: .corail
        case .mere: .violet
        case .autre: .turquoise
        }
    }
    /// Les personnes « autre » sont en verre clair avec texte turquoise, comme dans la maquette.
    var pleine: Bool { self != .autre }
}

extension View {
    /// Carte en verre (Liquid Glass d'iOS).
    func carteVerre(_ rayon: CGFloat = 28) -> some View {
        glassEffect(.regular, in: .rect(cornerRadius: rayon))
    }
    /// Verre teinté turquoise pour les actions principales.
    func verreTeinte(_ couleur: Color = .turquoise, rayon: CGFloat) -> some View {
        glassEffect(.regular.tint(couleur.opacity(0.9)).interactive(), in: .rect(cornerRadius: rayon))
    }
}

/// Fond coloré flou derrière le verre : turquoise, corail, violet, jaune.
struct FondColore: View {
    var variante = 0
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let positions: [(UInt32, CGFloat, CGFloat, CGFloat)] = variante == 1
                ? [(0x1FB5A3, 340, w - 210, -40), (0xFF7A59, 300, -140, 380), (0x8B6CF6, 320, w - 260, h - 260), (0xFFC857, 220, w - 230, 150)]
                : [(0x1FB5A3, 340, -110, -60), (0xFF7A59, 300, w - 180, 300), (0x8B6CF6, 320, -40, h - 240), (0xFFC857, 220, w - 230, 150)]
            ZStack(alignment: .topLeading) {
                Color.fond
                ForEach(0..<positions.count, id: \.self) { i in
                    let p = positions[i]
                    Circle()
                        .fill(Color(hex: p.0))
                        .frame(width: p.1, height: p.1)
                        .blur(radius: 70)
                        .opacity(p.0 == 0xFFC857 ? 0.6 : 0.8)
                        .offset(x: p.2, y: p.3)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Avatar rond avec initiales, couleur de la branche.
struct Avatar: View {
    let initiales: String
    let branche: Branche
    var taille: CGFloat = 44

    var body: some View {
        Text(initiales)
            .font(.system(size: taille * 0.36, weight: .semibold))
            .foregroundStyle(branche.pleine ? .white : Color.turquoise)
            .frame(width: taille, height: taille)
            .background(Circle().fill(branche.pleine ? branche.couleur : Color.turquoise.opacity(0.14)))
    }
}

extension Font {
    static func titreEcran() -> Font { .system(size: 34, weight: .bold) }
}

let localeFR = Locale(identifier: "fr_FR")

extension String {
    var majusculeInitiale: String { prefix(1).uppercased() + dropFirst() }
}
