import SwiftUI
import ArbreCore

/// Petite carte d'une personne : cercle, prénom, NOM, parenté. Réutilisée par les vues Générations et Familles.
struct CartePersonne: View {
    let famille: Famille
    let id: UUID
    var compacte = false
    var surPersonne: ((UUID) -> Void)?

    var body: some View {
        let p = famille.personne(id)
        let b = famille.branche(de: id)
        let alliance = !famille.estDeLaFamille(id)
        Button { surPersonne?(id) } label: {
            VStack(spacing: 3) {
                Avatar(initiales: p?.initiales ?? "", branche: b, taille: compacte ? 36 : 44)
                Text(p?.prenom ?? "").font(.system(size: compacte ? 13 : 14, weight: .semibold)).foregroundStyle(Color.encre)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(p?.nom.uppercased() ?? "").font(.system(size: 11)).foregroundStyle(Color.gris)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(famille.parente(de: id)).font(.system(size: 10, weight: alliance ? .regular : .semibold)).italic(alliance)
                    .foregroundStyle(alliance ? Color.gris : (b == .pere ? Color.corailTexte : (b == .mere ? Color.violetTexte : Color.turquoise)))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p?.nomComplet ?? ""), \(famille.parente(de: id))")
    }
}

/// Vue « Générations » : une section par génération, du plus ancien au plus jeune.
struct GenerationsView: View {
    let famille: Famille
    var surPersonne: ((UUID) -> Void)?

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(parGeneration(famille)) { g in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(g.titre.uppercased()).font(.system(size: 13, weight: .semibold)).tracking(0.5).foregroundStyle(Color.gris)
                        Spacer()
                        Text("\(g.personnes.count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.gris)
                    }
                    .padding(.horizontal, 6)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 6)], spacing: 6) {
                        ForEach(g.personnes) { p in CartePersonne(famille: famille, id: p.id, surPersonne: surPersonne) }
                    }
                    .padding(8)
                    .carteVerre(24)
                }
            }
        }
    }
}

/// Vue « Familles » : une carte par couple (ou parent seul) avec ses enfants en dessous.
struct FamillesView: View {
    let famille: Famille
    var surPersonne: ((UUID) -> Void)?

    var body: some View {
        LazyVStack(spacing: 14) {
            ForEach(Array(famillesUneParUne(famille).enumerated()), id: \.element.id) { i, c in
                let couleur = ArbreDessin.palette[i % ArbreDessin.palette.count]
                VStack(alignment: .leading, spacing: 8) {
                    Text("Famille de " + c.parents.compactMap { famille.personne($0)?.prenom }.joined(separator: " et "))
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(couleur)
                    HStack(spacing: 0) {
                        ForEach(Array(c.parents.enumerated()), id: \.element) { j, pid in
                            if j > 0 {
                                Image(systemName: "heart.fill").font(.system(size: 13)).foregroundStyle(couleur.opacity(0.8)).padding(.horizontal, 4)
                            }
                            CartePersonne(famille: famille, id: pid, surPersonne: surPersonne)
                        }
                    }
                    if !c.enfants.isEmpty {
                        Text(c.enfants.count > 1 ? "\(c.enfants.count) enfants" : "1 enfant")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.gris)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 4)], spacing: 4) {
                            ForEach(c.enfants, id: \.self) { e in CartePersonne(famille: famille, id: e, compacte: true, surPersonne: surPersonne) }
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 18).fill(couleur.opacity(0.08)))
                    }
                }
                .padding(14)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(couleur).frame(width: 5).padding(.vertical, 14)
                }
                .carteVerre(24)
            }
        }
    }
}

/// Vue « Roue » : moi au centre, mes parents puis mes grands-parents en demi-cercles autour.
/// Côté père à droite, côté mère à gauche. Toucher une case vide ajoute l'ancêtre manquant.
struct RoueView: View {
    @Environment(AppModel.self) private var model
    let famille: Famille
    var surPersonne: ((UUID) -> Void)?

    static let rayonCentre: CGFloat = 64
    static let epaisseur: CGFloat = 78
    static let anneaux = 4

    var body: some View {
        let sosa = numerosSosa(famille, generations: Self.anneaux + 1)
        let R = Self.rayonCentre + CGFloat(Self.anneaux) * Self.epaisseur
        let largeur = 2 * R + 20, hauteur = R + 30
        GeometryReader { g in
            let echelle = min(1, (g.size.width) / largeur)
            ZStack {
                ForEach(1...Self.anneaux, id: \.self) { k in
                    ForEach(0..<(1 << k), id: \.self) { i in
                        segment(anneau: k, index: i, sosa: sosa, R: R)
                    }
                }
                centre(sosa[1], R: R)
            }
            .frame(width: largeur, height: hauteur)
            .scaleEffect(echelle, anchor: .topLeading)
            .frame(width: largeur * echelle, height: hauteur * echelle, alignment: .topLeading)
        }
        .frame(height: (R + 30) * min(1, (UIScreen.main.bounds.width - 40) / (2 * R + 20)))
    }

    private func centre(_ id: UUID?, R: CGFloat) -> some View {
        let p = id.flatMap { famille.personne($0) }
        return ZStack {
            DemiDisque(rayon: Self.rayonCentre).fill(Color.turquoise)
            VStack(spacing: 0) {
                Text(p?.prenom ?? "").font(.system(size: 13, weight: .bold))
                Text(p?.nom.uppercased() ?? "").font(.system(size: 9))
            }
            .foregroundStyle(.white)
            .frame(width: Self.rayonCentre * 1.6)
            .position(x: R + 10, y: R + 10 - Self.rayonCentre * 0.4)
        }
        .onTapGesture { if let id { surPersonne?(id) } }
    }

    @ViewBuilder
    private func segment(anneau k: Int, index i: Int, sosa: [Int: UUID], R: CGFloat) -> some View {
        let n = (1 << k) + i
        let nb = Double(1 << k)
        // i = 0 : lignée la plus paternelle, placée tout à droite.
        let debut = 360 - Double(i + 1) * 180 / nb, fin = 360 - Double(i) * 180 / nb
        let r1 = Self.rayonCentre + CGFloat(k - 1) * Self.epaisseur, r2 = r1 + Self.epaisseur - 3
        let id = sosa[n]
        let enfant = sosa[n / 2]
        let cote: Branche = i < (1 << k) / 2 ? .pere : .mere
        let forme = Secteur(rayonInterieur: r1, rayonExterieur: r2, debut: .degrees(debut), fin: .degrees(fin))
        let milieu = (debut + fin) / 2 * .pi / 180
        let rm = (r1 + r2) / 2
        let cx = R + 10 + rm * CGFloat(cos(milieu)), cy = R + 10 + rm * CGFloat(sin(milieu))
        let tangent = k <= 2
        let angleTexte = tangent ? (debut + fin) / 2 + 90 : ((debut + fin) / 2 < 270 ? (debut + fin) / 2 + 180 : (debut + fin) / 2)
        ZStack {
            if let id, let p = famille.personne(id) {
                forme.fill(cote.couleur.opacity(0.20 + 0.10 * Double(4 - k)))
                forme.stroke(cote.couleur.opacity(0.7), lineWidth: 1.5)
                VStack(spacing: 0) {
                    Text(p.prenom).font(.system(size: k >= 3 ? 9 : 12, weight: .semibold))
                    Text(p.nom.uppercased()).font(.system(size: k >= 3 ? 7.5 : 9))
                }
                .foregroundStyle(Color.encre)
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(width: tangent ? rm * CGFloat(.pi / nb) * 0.9 : Self.epaisseur - 8)
                .rotationEffect(.degrees(angleTexte))
                .position(x: cx, y: cy)
            } else {
                forme.fill(Color.white.opacity(0.25))
                forme.stroke(Color.gris.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                if enfant != nil { Text("?").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.gris).position(x: cx, y: cy) }
            }
        }
        .contentShape(forme)
        .onTapGesture {
            if let id { surPersonne?(id) } else if let e = enfant { model.ajout = Ajout(pour: e, lien: n % 2 == 0 ? .pere : .mere) }
        }
        .accessibilityLabel(id.flatMap { famille.personne($0)?.nomComplet } ?? "Ancêtre à trouver")
    }
}

/// Morceau d'anneau entre deux rayons et deux angles, centré en bas au milieu.
struct Secteur: Shape {
    let rayonInterieur: CGFloat
    let rayonExterieur: CGFloat
    let debut: Angle
    let fin: Angle
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.maxY - 20)
        var p = Path()
        p.addArc(center: c, radius: rayonExterieur, startAngle: debut, endAngle: fin, clockwise: false)
        p.addArc(center: c, radius: rayonInterieur, startAngle: fin, endAngle: debut, clockwise: true)
        p.closeSubpath()
        return p
    }
}

struct DemiDisque: Shape {
    let rayon: CGFloat
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.maxY - 20)
        var p = Path()
        p.move(to: c)
        p.addArc(center: c, radius: rayon - 3, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.closeSubpath()
        return p
    }
}
