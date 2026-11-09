import SwiftUI
import ArbreCore

/// L'arbre « en escalier » : chaque personne sur sa ligne, ses enfants juste en dessous, décalés,
/// reliés par un trait vertical de la couleur de leur famille. L'arbre grandit vers le bas.
struct EscalierView: View {
    @Environment(AppModel.self) private var model
    var famille: Famille? = nil
    var surPersonne: ((UUID) -> Void)? = nil

    static let colonne: CGFloat = 22
    static let hauteurTrait: CGFloat = 24

    var body: some View {
        let f = famille ?? model.famille
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(escalier(f)) { l in ligne(l, f) }
        }
    }

    @ViewBuilder
    private func ligne(_ l: LigneEscalier, _ f: Famille) -> some View {
        if case .titre(let t) = l.genre {
            Text(t.uppercased())
                .font(.system(size: 13, weight: .semibold)).tracking(0.5)
                .foregroundStyle(t == "Côté père" ? Color.corailTexte : (t == "Côté mère" ? Color.violetTexte : Color.gris))
                .padding(.top, l.id == 0 ? 4 : 22).padding(.bottom, 6)
        } else {
            let couleur = l.groupe >= 0 ? ArbreDessin.palette[l.groupe % ArbreDessin.palette.count] : Color.clear
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<max(0, l.profondeur - 1), id: \.self) { i in
                    Guide(type: (l.guides[safe: i] ?? false) ? .continue : .vide, couleur: .gray.opacity(0.35))
                        .frame(width: Self.colonne)
                }
                if l.profondeur > 0 {
                    Guide(type: l.dernier ? .dernier : .milieu, couleur: couleur)
                        .frame(width: Self.colonne)
                }
                contenu(l, f)
                    .padding(.vertical, 5)
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func contenu(_ l: LigneEscalier, _ f: Famille) -> some View {
        switch l.genre {
        case .personne(let id, let conjoint):
            VStack(alignment: .leading, spacing: 4) {
                personne(id, f)
                if let c = conjoint {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(Color.corail.opacity(0.8))
                        personne(c, f, petit: true)
                    }
                    .padding(.leading, 8)
                }
            }
        case .union(let c):
            HStack(spacing: 6) {
                Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(Color.corail.opacity(0.8))
                personne(c, f, petit: true)
            }
        case .renvoi(let id):
            HStack(spacing: 8) {
                Text(f.personne(id)?.nomComplet ?? "").font(.system(size: 15)).foregroundStyle(Color.gris)
                Text("voir plus haut").font(.system(size: 12)).italic().foregroundStyle(Color.gris)
            }
            .frame(minHeight: 34)
        case .titre:
            EmptyView()
        }
    }

    private func personne(_ id: UUID, _ f: Famille, petit: Bool = false) -> some View {
        let p = f.personne(id)
        let b = f.branche(de: id)
        let alliance = !f.estDeLaFamille(id)
        return Button { surPersonne?(id) } label: {
            HStack(spacing: 10) {
                Avatar(initiales: p?.initiales ?? "", branche: b, taille: petit ? 28 : 34)
                VStack(alignment: .leading, spacing: 0) {
                    (Text(p?.prenom ?? "").font(.system(size: petit ? 14 : 16, weight: .semibold))
                     + Text(" " + (p?.nom.uppercased() ?? "")).font(.system(size: petit ? 13 : 14)).foregroundColor(Color.gris))
                        .foregroundStyle(Color.encre)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(f.parente(de: id))
                        .font(.system(size: 12, weight: alliance ? .regular : .medium))
                        .italic(alliance)
                        .foregroundStyle(alliance ? Color.gris : (b == .pere ? Color.corailTexte : (b == .mere ? Color.violetTexte : Color.turquoise)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p?.nomComplet ?? ""), \(f.parente(de: id))")
    }
}

/// Un morceau de trait d'une colonne : vertical qui continue, embranchement (├) ou dernier enfant (└).
struct Guide: View {
    enum TypeGuide { case vide, `continue`, milieu, dernier }
    let type: TypeGuide
    let couleur: Color

    var body: some View {
        GeometryReader { g in
            Path { p in
                let x = g.size.width / 2
                let y = EscalierView.hauteurTrait
                switch type {
                case .vide: break
                case .continue:
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: g.size.height))
                case .milieu:
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: g.size.height))
                    p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: g.size.width, y: y))
                case .dernier:
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: g.size.width, y: y))
                }
            }
            .stroke(couleur, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}
