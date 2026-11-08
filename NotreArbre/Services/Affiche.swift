import SwiftUI
import ArbreCore

enum FormatAffiche: String, CaseIterable, Identifiable {
    case a2, a1, a0
    var id: String { rawValue }
    var titre: String { rawValue.uppercased() }

    /// Taille en millimètres, en paysage (largeur, hauteur).
    var millimetres: (Double, Double) {
        switch self {
        case .a2: (594, 420)
        case .a1: (841, 594)
        case .a0: (1189, 841)
        }
    }

    var points: CGSize { CGSize(width: millimetres.0 * 72 / 25.4, height: millimetres.1 * 72 / 25.4) }

    var description: String {
        let (l, h) = millimetres
        return "\(Int(l / 10)) × \(Int(h / 10)) cm, en paysage"
    }
}

/// Crée le PDF vectoriel de l'affiche et renvoie son adresse.
@MainActor
func pdfAffiche(famille: Famille, format: FormatAffiche) -> URL? {
    let taille = format.points
    let rendu = ImageRenderer(content: AfficheContenu(famille: famille, taille: taille))
    rendu.proposedSize = ProposedViewSize(taille)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("famille-bazama-\(format.rawValue).pdf")
    var cadre = CGRect(origin: .zero, size: taille)
    var ok = false
    rendu.render { _, dessiner in
        guard let ctx = CGContext(url as CFURL, mediaBox: &cadre, nil) else { return }
        ctx.beginPDFPage(nil)
        dessiner(ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        ok = true
    }
    return ok ? url : nil
}

struct AfficheContenu: View {
    let famille: Famille
    let taille: CGSize

    var body: some View {
        let marge = 20 * 72 / 25.4
        let d = disposer(famille)
        let hautTitre = taille.height * 0.09
        let basPied = taille.height * 0.03
        let dispo = CGSize(width: taille.width - 2 * marge, height: taille.height - 2 * marge - hautTitre - basPied - 40)
        let echelle = max(0.1, min(dispo.width / max(d.taille.0, 1), dispo.height / max(d.taille.1, 1)))
        VStack(spacing: 20) {
            Text("Famille BAZAMA")
                .font(.system(size: hautTitre * 0.7, weight: .bold))
                .foregroundStyle(Color.encre)
                .frame(height: hautTitre)
            ArbreDessin(famille: famille, pourImpression: true)
                .scaleEffect(echelle, anchor: .topLeading)
                .frame(width: d.taille.0 * echelle, height: d.taille.1 * echelle, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text("\(famille.personnes.count) personnes · édité le \(Date().formatted(.dateTime.day().month(.wide).year().locale(localeFR)))")
                .font(.system(size: basPied * 0.6))
                .foregroundStyle(Color.gris)
                .frame(height: basPied)
        }
        .padding(marge)
        .frame(width: taille.width, height: taille.height)
        .background(Color.white)
        .environment(\.locale, localeFR)
    }
}
