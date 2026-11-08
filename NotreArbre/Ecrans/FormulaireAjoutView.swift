import SwiftUI
import ArbreCore

/// Formulaire pour ajouter un proche à la personne touchée dans l'arbre.
struct FormulaireAjoutView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var fermer
    let ajout: Ajout

    @State private var prenom = ""
    @State private var nom = ""
    @State private var sexe: Sexe = .inconnu
    @State private var lieu = ""
    @State private var notes = ""
    /// Autre parent d'un enfant, ou parents en commun d'un frère ou d'une sœur.
    @State private var choixParents = ""
    @FocusState private var champPrenom: Bool

    var body: some View {
        let sujet = model.famille.personne(ajout.pour)
        NavigationStack {
            Form {
                Section {
                    TextField("Prénom", text: $prenom)
                        .textContentType(.givenName)
                        .focused($champPrenom)
                    TextField("Nom", text: $nom)
                        .textContentType(.familyName)
                    if ajout.lien != .pere && ajout.lien != .mere {
                        Picker("Sexe", selection: $sexe) {
                            Text("Homme").tag(Sexe.homme)
                            Text("Femme").tag(Sexe.femme)
                            Text("Je ne sais pas").tag(Sexe.inconnu)
                        }
                    }
                } header: {
                    Text(titre(sujet))
                }
                if !optionsParents.isEmpty {
                    Section {
                        Picker(ajout.lien == .enfant ? "Autre parent" : "Parents en commun", selection: $choixParents) {
                            ForEach(optionsParents, id: \.cle) { Text($0.titre).tag($0.cle) }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } header: {
                        Text(ajout.lien == .enfant ? "Qui est l'autre parent ?" : "Même père et même mère ?")
                    }
                }
                Section {
                    TextField("Village de naissance (facultatif)", text: $lieu)
                } footer: {
                    Text("Le prénom et le nom sont obligatoires. Le reste peut attendre.")
                }
                Section("Notes") {
                    TextField("Ce que tu sais d'autre", text: $notes, axis: .vertical).lineLimit(2...6)
                }
            }
            .navigationTitle(ajout.lien.action(pour: sujet, famille: model.famille))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { enregistrer() }
                        .disabled(prenom.trimmingCharacters(in: .whitespaces).isEmpty || nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                switch ajout.lien {
                case .pere: sexe = .homme
                case .mere: sexe = .femme
                case .conjoint:
                    sexe = sujet?.sexe == .homme ? .femme : (sujet?.sexe == .femme ? .homme : .inconnu)
                default: break
                }
                if choixParents.isEmpty { choixParents = optionsParents.first?.cle ?? "" }
                champPrenom = true
            }
        }
    }

    private struct OptionParents { let cle: String; let titre: String; let ids: [UUID] }

    /// Choix proposés : l'autre parent d'un enfant (épouses, mari) ou les parents en commun d'un frère ou d'une sœur.
    private var optionsParents: [OptionParents] {
        let f = model.famille
        switch ajout.lien {
        case .enfant:
            let conj = f.conjoints(de: ajout.pour)
            guard !conj.isEmpty else { return [] }
            return conj.map { OptionParents(cle: $0.id.uuidString, titre: $0.nomComplet, ids: [$0.id]) }
                + [OptionParents(cle: "aucun", titre: "Une autre personne ou je ne sais pas", ids: [])]
        case .fratrie:
            let ps = f.parents(de: ajout.pour)
            guard ps.count == 2, let pere = f.pere(de: ajout.pour), let mere = f.mere(de: ajout.pour) else { return [] }
            return [OptionParents(cle: "deux", titre: "Même père et même mère", ids: [pere.id, mere.id]),
                    OptionParents(cle: "pere", titre: "Même père seulement (\(pere.prenom))", ids: [pere.id]),
                    OptionParents(cle: "mere", titre: "Même mère seulement (\(mere.prenom))", ids: [mere.id])]
        default:
            return []
        }
    }

    private func titre(_ sujet: Personne?) -> String {
        let nom = sujet?.prenom ?? ""
        let estMoi = ajout.pour == model.famille.moiID
        switch ajout.lien {
        case .pere: return estMoi ? "Ton père" : "Le père de \(nom)"
        case .mere: return estMoi ? "Ta mère" : "La mère de \(nom)"
        case .fratrie: return estMoi ? "Ton frère ou ta sœur" : "Un frère ou une sœur de \(nom)"
        case .enfant: return estMoi ? "Ton enfant" : "Un enfant de \(nom)"
        case .conjoint:
            if sujet?.sexe == .homme { return estMoi ? "Ton épouse" : "Une épouse de \(nom)" }
            if sujet?.sexe == .femme { return estMoi ? "Ton mari" : "Le mari de \(nom)" }
            return estMoi ? "Ton conjoint" : "Le conjoint de \(nom)"
        }
    }

    private func enregistrer() {
        let p = Personne(prenom: prenom.trimmingCharacters(in: .whitespaces).majusculeInitiale,
                         nom: nom.trimmingCharacters(in: .whitespaces),
                         sexe: sexe,
                         lieuNaissance: lieu.trimmingCharacters(in: .whitespaces).isEmpty ? nil : lieu.trimmingCharacters(in: .whitespaces).majusculeInitiale,
                         notes: notes,
                         origine: .saisie)
        fermer()
        let choisis = optionsParents.isEmpty ? nil : optionsParents.first { $0.cle == choixParents }?.ids
        model.ajouter(p, a: ajout.pour, lien: ajout.lien, parentsChoisis: choisis)
    }
}

/// Menu d'ajout autour d'une personne, réutilisé dans l'arbre et la fiche.
struct MenuAjout: View {
    @Environment(AppModel.self) private var model
    let id: UUID

    var body: some View {
        ForEach(model.liensPossibles(id), id: \.self) { l in
            Button { model.ajout = Ajout(pour: id, lien: l) } label: {
                Label(l.action(pour: model.famille.personne(id), famille: model.famille), systemImage: l.icone)
            }
        }
    }
}
