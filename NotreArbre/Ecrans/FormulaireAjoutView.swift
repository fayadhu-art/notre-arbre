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
    @State private var dateTexte = ""
    @State private var lieu = ""
    @State private var notes = ""
    @FocusState private var champPrenom: Bool

    var body: some View {
        let sujet = model.famille.personne(ajout.pour)
        let date = DateFloue.depuis(texte: dateTexte)
        NavigationStack {
            Form {
                Section {
                    TextField("Prénom", text: $prenom)
                        .textContentType(.givenName)
                        .focused($champPrenom)
                    TextField("Nom (facultatif)", text: $nom)
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
                Section {
                    TextField("Ex. vers 1958, 1958, 12 mars 1985", text: $dateTexte)
                    if !dateTexte.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label("Compris : \(date.libelle)", systemImage: date.precision == .inconnue ? "questionmark.circle" : "checkmark.circle")
                            .foregroundStyle(date.precision == .inconnue ? Color.corailTexte : Color.turquoise)
                    }
                    TextField("Village de naissance", text: $lieu)
                } header: {
                    Text("Naissance")
                } footer: {
                    Text("Laisse vide si tu ne sais pas. Tu pourras compléter plus tard.")
                }
                Section("Notes") {
                    TextField("Ce que tu sais d'autre", text: $notes, axis: .vertical).lineLimit(2...6)
                }
            }
            .navigationTitle(ajout.lien.action)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { enregistrer(date) }
                        .disabled(prenom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                switch ajout.lien {
                case .pere: sexe = .homme
                case .mere: sexe = .femme
                default: break
                }
                champPrenom = true
            }
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
        case .conjoint: return estMoi ? "Ton conjoint" : "Le conjoint de \(nom)"
        }
    }

    private func enregistrer(_ date: DateFloue) {
        let p = Personne(prenom: prenom.trimmingCharacters(in: .whitespaces).majusculeInitiale,
                         nom: nom.trimmingCharacters(in: .whitespaces),
                         sexe: sexe,
                         naissance: dateTexte.trimmingCharacters(in: .whitespaces).isEmpty ? .inconnue : date,
                         lieuNaissance: lieu.trimmingCharacters(in: .whitespaces).isEmpty ? nil : lieu.trimmingCharacters(in: .whitespaces).majusculeInitiale,
                         notes: notes,
                         origine: .saisie)
        fermer()
        model.ajouter(p, a: ajout.pour, lien: ajout.lien)
    }
}

/// Menu d'ajout autour d'une personne, réutilisé dans l'arbre et la fiche.
struct MenuAjout: View {
    @Environment(AppModel.self) private var model
    let id: UUID

    var body: some View {
        ForEach(model.liensPossibles(id), id: \.self) { l in
            Button { model.ajout = Ajout(pour: id, lien: l) } label: { Label(l.action, systemImage: l.icone) }
        }
    }
}
