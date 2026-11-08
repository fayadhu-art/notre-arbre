import SwiftUI
import ArbreCore

struct FicheView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var fermer
    let id: UUID
    @State private var edition = false

    var body: some View {
        Group {
            if let p = model.famille.personne(id) { contenu(p) } else { Text("Cette personne n'existe plus.") }
        }
        .background(FondColore())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Modifier") { edition = true } }
        }
        .sheet(isPresented: $edition) {
            if let p = model.famille.personne(id) { EditionView(personne: p, supprimer: { fermer() }).environment(model) }
        }
    }

    private func contenu(_ p: Personne) -> some View {
        let f = model.famille
        let b = f.branche(de: id)
        let aSavoir = model.listeManques.filter { $0.personne == id }
        return ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(p.initiales)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(b.pleine ? .white : Color.turquoise)
                        .frame(width: 96, height: 96)
                        .glassEffect(b.pleine ? .regular.tint(b.couleur.opacity(0.88)) : .regular, in: .circle)
                    Text(p.nomComplet).font(.system(size: 28, weight: .bold)).foregroundStyle(Color.encre)
                    Text(sousTitre(p)).font(.system(size: 15)).foregroundStyle(Color.gris).multilineTextAlignment(.center)
                }
                section("Liens") {
                    let liens = liensDe(p)
                    if liens.isEmpty {
                        Text("Aucun lien pour le moment.").font(.system(size: 15)).foregroundStyle(Color.gris).padding(.vertical, 12)
                    }
                    ForEach(Array(liens.enumerated()), id: \.offset) { i, l in
                        NavigationLink(value: l.0.id) {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(l.0.nomComplet).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.encre)
                                    Text(l.1).font(.system(size: 13)).foregroundStyle(Color.gris)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0x8E8E93))
                            }
                            .frame(minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        if i < liens.count - 1 { Divider() }
                    }
                }
                if !aSavoir.isEmpty {
                    section("Ce qu'on ne sait pas encore") {
                        ForEach(aSavoir, id: \.self) { m in
                            HStack(spacing: 10) {
                                Circle().stroke(Color.turquoise.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [4, 3])).frame(width: 22, height: 22)
                                Text(libelle(m)).font(.system(size: 15)).foregroundStyle(Color.encre)
                            }
                            .frame(minHeight: 44)
                        }
                        Text("Touche « Ajouter un proche » ou « Modifier » pour compléter.")
                            .font(.system(size: 13)).foregroundStyle(Color.gris).padding(.bottom, 8)
                    }
                }
                if !p.notes.isEmpty {
                    section("Notes") { Text(p.notes).font(.system(size: 15)).padding(.vertical, 10) }
                }
                Text("Ajouté\(p.sexe == .femme ? "e" : "") \(origine(p.origine)) le \(p.ajouteeLe.formatted(.dateTime.day().month(.wide).year().locale(localeFR)))")
                    .font(.system(size: 12)).foregroundStyle(Color.gris)

                VStack(spacing: 10) {
                    Menu { MenuAjout(id: id) } label: {
                        Label("Ajouter un proche", systemImage: "plus")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                    }
                    .verreTeinte(rayon: 28)
                    Button {
                        DemandeProche.envoyer(messageQuestions(pour: p, manques: model.listeManques, famille: model.famille))
                    } label: {
                        Label("Demander à un proche", systemImage: "paperplane")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.turquoise)
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }

    private func section<C: View>(_ titre: String, @ViewBuilder _ contenu: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titre.uppercased()).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.gris).tracking(0.5)
                .padding(.top, 12).padding(.bottom, 4)
            contenu()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .carteVerre(24)
    }

    private func sousTitre(_ p: Personne) -> String {
        var morceaux: [String] = []
        if p.naissance.precision != .inconnue { morceaux.append("\(p.neAccorde.majusculeInitiale) \(p.naissance.libelle)") }
        if let l = p.lieuNaissance, !l.isEmpty { morceaux.append("à \(l)") }
        let lien = model.famille.lienAvecMoi(p.id)
        if !lien.isEmpty { morceaux.append(lien) }
        return morceaux.joined(separator: " · ")
    }

    private func liensDe(_ p: Personne) -> [(Personne, String)] {
        let f = model.famille
        func detail(_ x: Personne, _ role: String) -> String {
            let date = x.naissance.precision == .inconnue ? "" : " · \(x.neAccorde) \(x.naissance.libelle)"
            let toi = x.id == f.moiID ? " · toi" : ""
            return role + date + toi
        }
        var l: [(Personne, String)] = []
        l += f.parents(de: p.id).map { ($0, detail($0, $0.sexe == .femme ? "Sa mère" : "Son père")) }
        l += f.conjoints(de: p.id).map { ($0, detail($0, $0.sexe == .femme ? "Son épouse" : "Son époux")) }
        l += f.freresEtSoeurs(de: p.id).map { ($0, detail($0, $0.sexe == .femme ? "Sa sœur" : "Son frère")) }
        l += f.enfants(de: p.id).map { ($0, detail($0, $0.sexe == .femme ? "Sa fille" : "Son fils")) }
        return l
    }

    private func libelle(_ m: Manque) -> String {
        switch m.sujet {
        case .parents, .grandsParents: "Ses parents"
        case .freresSoeurs: "Ses frères et sœurs"
        case .enfants: "Ses enfants"
        case .dateNaissance: "Son année de naissance"
        case .lieuNaissance: "Son village de naissance"
        }
    }

    private func origine(_ o: Origine) -> String {
        switch o {
        case .entretien: "à l'oral"
        case .document: "depuis un document"
        case .saisie: "à la main"
        }
    }
}

struct EditionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var fermer
    @State var personne: Personne
    let supprimer: () -> Void
    @State private var dateTexte = ""
    @State private var confirmer = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Prénom", text: $personne.prenom)
                    TextField("Nom", text: $personne.nom)
                    Picker("Sexe", selection: $personne.sexe) {
                        Text("Homme").tag(Sexe.homme)
                        Text("Femme").tag(Sexe.femme)
                        Text("Je ne sais pas").tag(Sexe.inconnu)
                    }
                }
                Section {
                    TextField("Ex. vers 1958, 12 mars 1985", text: $dateTexte)
                    Text("Compris : \(DateFloue.depuis(texte: dateTexte).libelle)").foregroundStyle(Color.gris)
                    TextField("Village de naissance", text: Binding(get: { personne.lieuNaissance ?? "" }, set: { personne.lieuNaissance = $0 }))
                } header: { Text("Naissance") }
                Section("Notes") {
                    TextField("Ce que tu sais d'autre", text: $personne.notes, axis: .vertical).lineLimit(3...8)
                }
                if personne.id != model.famille.moiID {
                    Section {
                        Button("Supprimer cette personne", role: .destructive) { confirmer = true }
                    }
                }
            }
            .navigationTitle(personne.prenom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        personne.naissance = dateTexte.trimmingCharacters(in: .whitespaces).isEmpty ? .inconnue : DateFloue.depuis(texte: dateTexte)
                        model.modifier(personne)
                        fermer()
                    }
                    .disabled(personne.prenom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Supprimer \(personne.prenom) de l'arbre ?", isPresented: $confirmer, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    model.supprimer(personne.id)
                    fermer()
                    supprimer()
                }
            }
            .onAppear { dateTexte = personne.naissance.precision == .inconnue ? "" : personne.naissance.libelle }
        }
    }
}
