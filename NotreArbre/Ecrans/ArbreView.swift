import SwiftUI
import ArbreCore

/// Le dessin de l'arbre, réutilisé à l'écran et pour l'affiche PDF.
struct ArbreDessin: View {
    static let largeur: Double = 104
    static let ecart: Double = 150
    /// Couleurs des traits, une par famille, bien distinctes les unes des autres.
    static let palette: [Color] = [0x0F766E, 0xE4572E, 0x7C3AED, 0x2563EB, 0xD97706, 0xDB2777, 0x16A34A, 0x0891B2, 0x9D174D, 0x4D7C0F]
        .map { Color(hex: $0) }
    let famille: Famille
    var pourImpression = false
    var surPersonne: ((UUID) -> Void)? = nil
    var surATrouver: ((Noeud) -> Void)? = nil
    /// Personne dont on affiche uniquement les liens (le reste de l'arbre est estompé).
    var focus: UUID? = nil
    var surNom: ((UUID) -> Void)? = nil

    private func visible(_ id: UUID?) -> Bool {
        guard let focus else { return true }
        guard let id else { return false }
        return famille.lienDirect(de: id, avec: focus) != nil
    }

    var body: some View {
        let d = disposer(famille, largeurNoeud: Self.largeur, ecartGeneration: Self.ecart)
        ZStack(alignment: .topLeading) {
            // Une couleur par famille (couple ou parent seul, avec ses enfants).
            ForEach(Array(Set(d.traits.map(\.groupe))).sorted(), id: \.self) { g in
                let couleur = Self.palette[g % Self.palette.count]
                Path { p in
                    for t in d.traits where t.groupe == g && !t.pointille && (focus == nil || t.personnes.contains(focus!)) {
                        p.move(to: CGPoint(x: t.de.0, y: t.de.1)); p.addLine(to: CGPoint(x: t.a.0, y: t.a.1))
                    }
                }
                .stroke(couleur.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                Path { p in
                    for t in d.traits where t.groupe == g && !t.pointille && focus != nil && !t.personnes.contains(focus!) {
                        p.move(to: CGPoint(x: t.de.0, y: t.de.1)); p.addLine(to: CGPoint(x: t.a.0, y: t.a.1))
                    }
                }
                .stroke(couleur.opacity(0.12), style: StrokeStyle(lineWidth: 2))
                Path { p in
                    for t in d.traits where t.groupe == g && t.pointille {
                        p.move(to: CGPoint(x: t.de.0, y: t.de.1)); p.addLine(to: CGPoint(x: t.a.0, y: t.a.1))
                    }
                }
                .stroke(couleur.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }

            ForEach(d.noeuds, id: \.cle) { n in
              Group {
                cercle(n).position(x: n.x, y: n.y)
                Text(n.libelle)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.encre)
                    .lineLimit(1).minimumScaleFactor(0.7).frame(width: Self.largeur)
                    .position(x: n.x, y: n.y + 41)
                Text(sousTitre(n))
                    .font(.system(size: 12, weight: n.id == nil ? .regular : .medium))
                    .foregroundStyle(n.id == nil ? Color.gris : Color.encre.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.7).frame(width: Self.largeur)
                    .position(x: n.x, y: n.y + 58)
                if let id = n.id {
                    let b = famille.branche(de: id)
                    let alliance = !famille.estDeLaFamille(id)
                    Text(focus.flatMap { famille.lienDirect(de: id, avec: $0) } ?? famille.parente(de: id))
                        .font(.system(size: 11, weight: alliance ? .medium : .semibold))
                        .italic(alliance)
                        .foregroundStyle(alliance ? Color.gris : (b == .pere ? Color.corailTexte : (b == .mere ? Color.violetTexte : Color.turquoise)))
                        .lineLimit(1).minimumScaleFactor(0.7).frame(width: Self.largeur)
                        .position(x: n.x, y: n.y + 75)
                }
                // Toucher le nom : affiche uniquement les liens de cette personne.
                if let id = n.id {
                    Color.clear
                        .frame(width: Self.largeur, height: 52)
                        .contentShape(Rectangle())
                        .position(x: n.x, y: n.y + 58)
                        .onTapGesture { surNom?(id) }
                        .accessibilityLabel("Voir les liens de \(n.libelle)")
                        .accessibilityAddTraits(.isButton)
                }
              }
              .opacity(visible(n.id) ? 1 : 0.15)
            }
        }
        .frame(width: d.taille.0, height: d.taille.1, alignment: .topLeading)
    }

    private func sousTitre(_ n: Noeud) -> String {
        if let id = n.id, let p = famille.personne(id) { return p.nom.uppercased() }
        guard let pour = n.pour, let enfant = famille.personne(pour) else { return "" }
        let role = n.role == .femme ? "mère" : "père"
        let voyelle = "aeiouyhAEIOUYHÉé".contains(enfant.prenom.first ?? "x")
        return "\(role) \(voyelle ? "d'" : "de ")\(enfant.prenom)"
    }

    @ViewBuilder
    private func cercle(_ n: Noeud) -> some View {
        if let id = n.id, let p = famille.personne(id) {
            let b = famille.branche(de: id)
            let contenu = Text(p.initiales)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(b.pleine ? .white : Color.turquoise)
                .frame(width: 52, height: 52)
            Group {
                if pourImpression {
                    contenu.background(Circle().fill(b.pleine ? b.couleur : Color.turquoiseClair))
                        .overlay(Circle().stroke(b.pleine ? .clear : Color.turquoise.opacity(0.5), lineWidth: 1.5))
                } else if b.pleine {
                    contenu.glassEffect(.regular.tint(b.couleur.opacity(0.88)).interactive(), in: .circle)
                } else {
                    contenu.glassEffect(.regular.interactive(), in: .circle)
                }
            }
            .onTapGesture { surPersonne?(id) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(p.nomComplet), \(famille.parente(de: id))")
            .accessibilityAddTraits(.isButton)
        } else {
            Text("?")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.turquoise)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Color.white.opacity(pourImpression ? 1 : 0.35)))
                .overlay(Circle().stroke(Color.turquoise.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [4, 3])))
                .onTapGesture { surATrouver?(n) }
                .accessibilityLabel("À trouver, \(sousTitre(n))")
                .accessibilityAddTraits(.isButton)
        }
    }
}

struct ArbreView: View {
    @Environment(AppModel.self) private var model
    @State private var zoom: CGFloat = 1
    @State private var zoomDepart: CGFloat = 1
    @State private var fiche: UUID?
    @State private var choix: UUID?
    @State private var focus: UUID?
    @State private var affiche = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("L'arbre").font(.titreEcran()).foregroundStyle(Color.encre)
                    Text("\(model.famille.personnes.count) personnes · \(model.famille.nombreGenerations) générations")
                        .font(.system(size: 15)).foregroundStyle(Color.gris)
                }
                Spacer()
                Button { affiche = true } label: {
                    Image(systemName: "printer").font(.system(size: 18, weight: .medium)).foregroundStyle(Color.encre)
                        .frame(width: 44, height: 44)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Imprimer l'arbre en grand format")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    puce { HStack(spacing: 6) { Circle().stroke(Color.turquoise, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 12, height: 12); Text("à compléter") } }
                    puce { HStack(spacing: 6) { Circle().fill(Color.violet).frame(width: 12, height: 12); Text("côté mère"); Circle().fill(Color.corail).frame(width: 12, height: 12).padding(.leading, 6); Text("côté père") } }
                    puce { Text("gris italique = par alliance").italic() }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .top) {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                let d = disposer(model.famille, largeurNoeud: ArbreDessin.largeur, ecartGeneration: ArbreDessin.ecart)
                ArbreDessin(famille: model.famille,
                            surPersonne: { choix = $0 },
                            surATrouver: { n in
                                guard let pour = n.pour else { return }
                                model.ajout = Ajout(pour: pour, lien: n.role == .femme ? .mere : .pere)
                            },
                            focus: focus,
                            surNom: { id in withAnimation(.easeInOut(duration: 0.25)) { focus = focus == id ? nil : id } })
                    .scaleEffect(zoom, anchor: .topLeading)
                    .frame(width: d.taille.0 * zoom, height: d.taille.1 * zoom, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
            }
            .defaultScrollAnchor(.top)
            .padding(.top, 140)
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { zoom = min(2.5, max(0.4, zoomDepart * $0.magnification)) }
                    .onEnded { _ in zoomDepart = zoom }
            )
        }
        .overlay(alignment: .bottom) {
            if let f = focus, let p = model.famille.personne(f) {
                Button { withAnimation(.easeInOut(duration: 0.25)) { focus = nil } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.checkmark").foregroundStyle(Color.turquoise)
                        Text("Les liens de \(p.nomComplet)").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.encre)
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.gris)
                    }
                    .padding(.horizontal, 18).frame(height: 48)
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                .padding(.bottom, 92)
                .accessibilityLabel("Revenir à tout l'arbre")
            }
        }
        .background(FondColore())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $fiche) { FicheView(id: $0) }
        .confirmationDialog(choix.flatMap { model.famille.personne($0)?.nomComplet } ?? "",
                            isPresented: Binding(get: { choix != nil }, set: { if !$0 { choix = nil } }),
                            titleVisibility: .visible, presenting: choix) { id in
            MenuAjout(id: id)
            Button("Voir la fiche") { fiche = id }
            Button("Annuler", role: .cancel) {}
        }
        .sheet(isPresented: $affiche) { AfficheView().environment(model).presentationDetents([.medium]) }
    }

    private func puce<C: View>(@ViewBuilder _ contenu: () -> C) -> some View {
        contenu()
            .font(.system(size: 12)).foregroundStyle(Color.encre)
            .padding(.horizontal, 12).frame(height: 30)
            .glassEffect(.regular, in: .capsule)
    }
}

struct AfficheView: View {
    @Environment(AppModel.self) private var model
    @State private var format: FormatAffiche = .a1
    @State private var fichier: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Imprimer l'arbre").font(.system(size: 24, weight: .bold))
            Text("Un PDF net à toutes les tailles, avec « Famille BAZAMA » en haut. Envoie-le à un imprimeur.")
                .font(.system(size: 15)).foregroundStyle(Color.gris)
            Picker("Format", selection: $format) {
                ForEach(FormatAffiche.allCases) { Text($0.titre).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: format) { fichier = nil }
            Text(format.description).font(.system(size: 13)).foregroundStyle(Color.gris)
            Spacer()
            if let fichier {
                ShareLink(item: fichier) {
                    Label("Partager le PDF", systemImage: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                }
                .verreTeinte(rayon: 28)
            } else {
                Button { fichier = pdfAffiche(famille: model.famille, format: format) } label: {
                    Label("Créer le PDF \(format.titre)", systemImage: "doc.richtext")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 56)
                }
                .verreTeinte(rayon: 28)
            }
        }
        .padding(24)
    }
}
