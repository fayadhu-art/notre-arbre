import SwiftUI
import PhotosUI
import ArbreCore

struct LigneFiche: Identifiable {
    let id: UUID
    let initiales: String
    let nom: String
    let detail: String
    let branche: Branche
    let nouvelle: Bool
}

struct Bulle: Identifiable {
    enum Genre { case ia(String), moi(String), fiche([LigneFiche]) }
    let id = UUID()
    let genre: Genre
}

struct EntretienView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var fermer
    let depart: Manque?

    @State private var bulles: [Bulle] = []
    @State private var manque: Manque?
    @State private var proposition: Resultat?
    @State private var saisie = ""
    @State private var clavier = false
    @State private var analyse = false
    @State private var objectifAtteint = false
    @State private var photo: PhotosPickerItem?
    @State private var choixPhoto = false
    @State private var camera = false
    @State private var dictee = Dictee()
    @State private var assistant = Assistant()
    @FocusState private var champActif: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            FondColore(variante: 1)
            VStack(spacing: 0) {
                entete
                ScrollViewReader { lecteur in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if !assistant.disponible {
                                Text("L'IA d'Apple n'est pas disponible. Active Apple Intelligence dans Réglages, ou écris ta réponse : je la lirai plus simplement.")
                                    .font(.system(size: 14)).foregroundStyle(Color.encre)
                                    .padding(12).carteVerre(18)
                            }
                            ForEach(bulles) { vueBulle($0) }
                            if analyse { ProgressView("Je réfléchis…").padding(12).carteVerre(18) }
                            if let p = proposition { carteProposition(p) }
                            if proposition == nil && !analyse { raccourcis }
                            Color.clear.frame(height: 1).id("fin")
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 200)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: bulles.count) { withAnimation { lecteur.scrollTo("fin", anchor: .bottom) } }
                    .onChange(of: proposition != nil) { withAnimation { lecteur.scrollTo("fin", anchor: .bottom) } }
                }
            }
            commandes
        }
        .onAppear(perform: demarrer)
        .onChange(of: photo) { Task { await lirePhoto() } }
        .photosPicker(isPresented: $choixPhoto, selection: $photo, matching: .images)
        .fullScreenCover(isPresented: $camera) {
            AppareilPhoto { image in Task { await lireDocument(image) } }.ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $objectifAtteint) {
            ObjectifAtteintView(terminer: { objectifAtteint = false; fermer() },
                                continuer: { objectifAtteint = false })
                .environment(model)
        }
    }

    // MARK: Vues

    private var entete: some View {
        HStack {
            Button { dictee.arreter(); fermer() } label: {
                Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold)).foregroundStyle(Color.encre)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Retour à l'accueil")
            Spacer()
            Text("Entretien").font(.system(size: 17, weight: .semibold))
            Spacer()
            Text("\(model.ajoutsAujourdhui.count)/\(Objectif.cible) aujourd'hui")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.turquoise)
                .padding(.horizontal, 14).frame(height: 36)
                .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func vueBulle(_ b: Bulle) -> some View {
        switch b.genre {
        case .ia(let t):
            Text(t).font(.system(size: 16)).foregroundStyle(Color.encre)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .glassEffect(.regular, in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 8, bottomTrailingRadius: 22, topTrailingRadius: 22))
                .frame(maxWidth: 300, alignment: .leading)
        case .moi(let t):
            Text(t).font(.system(size: 16)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .glassEffect(.regular.tint(Color.turquoise.opacity(0.9)), in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22, bottomTrailingRadius: 8, topTrailingRadius: 22))
                .frame(maxWidth: .infinity, alignment: .trailing)
        case .fiche(let lignes):
            VStack(alignment: .leading, spacing: 10) {
                Label(lignes.contains(where: \.nouvelle) ? "Fiche créée" : "Fiche mise à jour", systemImage: "checkmark")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.turquoise)
                ForEach(lignes) { ligne($0) }
            }
            .padding(14)
            .frame(width: 300, alignment: .leading)
            .carteVerre(24)
        }
    }

    private func ligne(_ l: LigneFiche) -> some View {
        HStack(spacing: 12) {
            Avatar(initiales: l.initiales, branche: l.branche)
            VStack(alignment: .leading, spacing: 2) {
                Text(l.nom).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.encre)
                Text(l.detail).font(.system(size: 14)).foregroundStyle(Color.gris)
            }
        }
    }

    private func carteProposition(_ r: Resultat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(r.traite != nil && r.touchees.isEmpty ? "J'ai compris :" : "Voici ce que j'ai compris :")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.violetTexte)
            if r.touchees.isEmpty, let t = r.traite {
                Text(t.sujet == .enfants ? "Pas d'enfant pour le moment." : "Pas de frère ni de sœur.")
                    .font(.system(size: 16)).foregroundStyle(Color.encre)
            }
            ForEach(lignes(r)) { ligne($0) }
            HStack(spacing: 10) {
                Button("Corriger") { corriger() }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.turquoise)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .glassEffect(.regular.interactive(), in: .capsule)
                Button("Valider") { valider(r) }
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .verreTeinte(rayon: 23)
            }
        }
        .padding(14)
        .carteVerre(24)
    }

    private var raccourcis: some View {
        FlowLayout(spacing: 8) {
            puce("Je ne sais pas", icone: nil) { jeNeSaisPas() }
            puce("Demander à un proche", icone: nil) { demanderProche() }
            Menu {
                Button { camera = true } label: { Label("Prendre une photo", systemImage: "camera") }
                Button { choixPhoto = true } label: { Label("Choisir dans Photos", systemImage: "photo") }
            } label: {
                Label("Photo d'un document", systemImage: "camera").font(.system(size: 14)).foregroundStyle(Color.encre)
                    .padding(.horizontal, 14).frame(height: 40)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
        .padding(.top, 4)
    }

    private func puce(_ titre: String, icone: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(titre).font(.system(size: 14)).foregroundStyle(Color.encre)
                .padding(.horizontal, 14).frame(height: 40)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var commandes: some View {
        VStack(spacing: 12) {
            if clavier {
                HStack(spacing: 10) {
                    TextField("Ta réponse", text: $saisie, axis: .vertical)
                        .focused($champActif)
                        .lineLimit(1...4)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .glassEffect(.regular, in: .rect(cornerRadius: 22))
                        .submitLabel(.send)
                        .onSubmit { envoyer(saisie) }
                    Button { envoyer(saisie) } label: {
                        Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                    }
                    .verreTeinte(rayon: 23)
                    .accessibilityLabel("Envoyer")
                }
                .padding(.horizontal, 16)
            } else {
                Text(dictee.enCours ? (dictee.texte.isEmpty ? "Je t'écoute…" : dictee.texte) : (dictee.erreur ?? "Appuie et parle, puis appuie à nouveau pour envoyer"))
                    .font(.system(size: 13)).foregroundStyle(Color.encre)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.horizontal, 20)
            }
            HStack(spacing: 28) {
                Button { clavier.toggle(); champActif = clavier } label: {
                    Image(systemName: clavier ? "mic" : "keyboard").font(.system(size: 20)).foregroundStyle(Color.encre)
                        .frame(width: 56, height: 56)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel(clavier ? "Répondre à la voix" : "Écrire la réponse")

                Button { Task { await micro() } } label: {
                    Image(systemName: dictee.enCours ? "stop.fill" : "mic.fill")
                        .font(.system(size: 30, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 84, height: 84)
                }
                .glassEffect(.regular.tint((dictee.enCours ? Color.corail : Color.turquoise).opacity(0.9)).interactive(), in: .circle)
                .disabled(analyse || proposition != nil)
                .accessibilityLabel(dictee.enCours ? "Arrêter et envoyer" : "Appuyer pour répondre")

                Button { dictee.arreter(); model.onglet = .arbre; fermer() } label: {
                    Image(systemName: "point.3.connected.trianglepath.dotted").font(.system(size: 20)).foregroundStyle(Color.encre)
                        .frame(width: 56, height: 56)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Voir l'arbre")
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: Actions

    private func demarrer() {
        guard bulles.isEmpty else { return }
        manque = depart ?? model.listeManques.first
        poser()
    }

    private func poser() {
        if let m = manque {
            bulles.append(Bulle(genre: .ia(texte(m, famille: model.famille))))
        } else {
            bulles.append(Bulle(genre: .ia("Ton arbre est déjà bien rempli. Qui veux-tu ajouter ? Dis-moi son prénom et son lien avec toi.")))
        }
    }

    private func micro() async {
        if dictee.enCours {
            dictee.arreter()
            let t = dictee.texte
            if !t.trimmingCharacters(in: .whitespaces).isEmpty { envoyer(t) }
        } else {
            await dictee.demarrer()
        }
    }

    private func envoyer(_ t: String) {
        let reponse = t.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reponse.isEmpty else { return }
        saisie = ""
        champActif = false
        bulles.append(Bulle(genre: .moi(reponse)))
        Task { await analyser(reponse, origine: .entretien) }
    }

    private func analyser(_ reponse: String, origine: Origine) async {
        analyse = true
        let r = await assistant.proposer(reponse: reponse, manque: manque, famille: model.famille, origine: origine)
        analyse = false
        if r.estVide {
            bulles.append(Bulle(genre: .ia("Je n'ai pas bien compris. Tu peux le redire autrement ? Par exemple : « Mon père s'appelle Ahamada, il est né vers 1958. »")))
        } else {
            proposition = r
        }
    }

    private func lignes(_ r: Resultat) -> [LigneFiche] {
        r.touchees.compactMap { t in
            guard let p = r.famille.personne(t.id) else { return nil }
            var detail = r.famille.lienAvecMoi(t.id).majusculeInitiale
            if p.naissance.precision != .inconnue { detail += " · \(p.neAccorde) \(p.naissance.libelle)" }
            if let lieu = p.lieuNaissance, !lieu.isEmpty { detail += " · \(lieu)" }
            return LigneFiche(id: p.id, initiales: p.initiales, nom: p.nomComplet, detail: detail,
                              branche: r.famille.branche(de: p.id), nouvelle: t.nouvelle)
        }
    }

    private func valider(_ r: Resultat) {
        let l = lignes(r)
        let atteint = model.appliquer(r)
        proposition = nil
        if !l.isEmpty { bulles.append(Bulle(genre: .fiche(l))) }
        manque = model.listeManques.first
        poser()
        if atteint { objectifAtteint = true }
    }

    private func corriger() {
        proposition = nil
        if case .moi(let t)? = bulles.last(where: { if case .moi = $0.genre { return true } else { return false } })?.genre {
            saisie = t
        }
        clavier = true
        champActif = true
        bulles.append(Bulle(genre: .ia("D'accord, corrige ta réponse ou redis-la.")))
    }

    private func jeNeSaisPas() {
        guard let m = manque else { return }
        model.reporter(m)
        bulles.append(Bulle(genre: .moi("Je ne sais pas")))
        let suivante = model.listeManques.first { $0 != m }
        manque = suivante
        if suivante == nil {
            bulles.append(Bulle(genre: .ia("Pas de souci, on y reviendra.")))
        }
        poser()
    }

    private func demanderProche() {
        let p = manque?.personne.flatMap { model.famille.personne($0) }
        let liste = model.listeManques
        DemandeProche.envoyer(messageQuestions(pour: p, manques: liste, famille: model.famille))
    }

    private func lirePhoto() async {
        guard let item = photo, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        photo = nil
        await lireDocument(image)
    }

    private func lireDocument(_ image: UIImage) async {
        analyse = true
        let texteLu = (try? await LectureDocument.texte(de: image)) ?? ""
        analyse = false
        guard !texteLu.isEmpty else {
            bulles.append(Bulle(genre: .ia("Je n'arrive pas à lire ce document. Essaie avec une photo plus nette, bien à plat.")))
            return
        }
        bulles.append(Bulle(genre: .moi("Photo d'un document")))
        await analyser(texteLu, origine: .document)
    }
}

/// Dispose les puces sur plusieurs lignes.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largeur = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, hauteurLigne: CGFloat = 0, maxX: CGFloat = 0
        for v in subviews {
            let t = v.sizeThatFits(.unspecified)
            if x + t.width > largeur, x > 0 { x = 0; y += hauteurLigne + spacing; hauteurLigne = 0 }
            x += t.width + spacing
            maxX = max(maxX, x - spacing)
            hauteurLigne = max(hauteurLigne, t.height)
        }
        return CGSize(width: maxX, height: y + hauteurLigne)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, hauteurLigne: CGFloat = 0
        for v in subviews {
            let t = v.sizeThatFits(.unspecified)
            if x + t.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += hauteurLigne + spacing; hauteurLigne = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
            x += t.width + spacing
            hauteurLigne = max(hauteurLigne, t.height)
        }
    }
}

/// Appareil photo pour les documents.
struct AppareilPhoto: UIViewControllerRepresentable {
    let prise: (UIImage) -> Void
    @Environment(\.dismiss) private var fermer

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinateur { Coordinateur(self) }

    final class Coordinateur: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AppareilPhoto
        init(_ p: AppareilPhoto) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.prise(image) }
            parent.fermer()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.fermer() }
    }
}
