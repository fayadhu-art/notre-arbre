import SwiftUI
import PhotosUI
import ArbreCore

/// Ajoute les enfants d'une personne à partir d'une capture d'écran (message reçu avec les prénoms et noms).
struct ImportCaptureView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var fermer
    let parent: UUID

    @State private var photo: PhotosPickerItem?
    @State private var lecture = false
    @State private var lignes: [LigneLue] = []
    @State private var autreParent = "aucun"
    @State private var dejaChoisi = false

    struct LigneLue: Identifiable {
        let id = UUID()
        var garder = true
        var prenom: String
        var nom: String
        var sexe: Sexe = .inconnu
    }

    var body: some View {
        let f = model.famille
        let p = f.personne(parent)
        let conj = f.conjoints(de: parent)
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photo, matching: .screenshots) {
                        Label(lignes.isEmpty ? "Choisir la capture d'écran" : "Choisir une autre capture", systemImage: "photo.on.rectangle")
                    }
                    if lecture { HStack { ProgressView(); Text("Lecture de la capture…").foregroundStyle(Color.gris) } }
                } footer: {
                    Text("La capture est lue sur ton iPhone. Tu vérifies ensuite chaque prénom et nom avant d'ajouter.")
                }
                if dejaChoisi && lignes.isEmpty && !lecture {
                    Section { Text("Je n'ai trouvé aucun nom sur cette capture. Essaie avec une capture plus nette ou plus zoomée.").foregroundStyle(Color.corailTexte) }
                }
                if !lignes.isEmpty {
                    if !conj.isEmpty {
                        Section("Autre parent") {
                            Picker("Autre parent", selection: $autreParent) {
                                ForEach(conj) { Text($0.nomComplet).tag($0.id.uuidString) }
                                Text("Une autre personne ou je ne sais pas").tag("aucun")
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                        }
                    }
                    Section {
                        ForEach($lignes) { $l in
                            VStack(spacing: 8) {
                                Toggle(isOn: $l.garder) {
                                    TextField("Prénom", text: $l.prenom).font(.system(size: 17, weight: .semibold))
                                }
                                .tint(Color.turquoise)
                                TextField("Nom", text: $l.nom)
                                Picker("Sexe", selection: $l.sexe) {
                                    Text("Garçon").tag(Sexe.homme)
                                    Text("Fille").tag(Sexe.femme)
                                    Text("?").tag(Sexe.inconnu)
                                }
                                .pickerStyle(.segmented)
                            }
                            .opacity(l.garder ? 1 : 0.45)
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("Enfants trouvés (\(lignes.filter(\.garder).count))")
                    } footer: {
                        Text("Décoche ce qui n'est pas un enfant (le nom de l'expéditeur, par exemple) et corrige si besoin.")
                    }
                }
            }
            .navigationTitle("Enfants de \(p?.prenom ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { fermer() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { ajouter() }
                        .disabled(!lignes.contains { $0.garder && !$0.prenom.trimmingCharacters(in: .whitespaces).isEmpty && !$0.nom.trimmingCharacters(in: .whitespaces).isEmpty })
                }
            }
            .onAppear { if conj.count == 1 { autreParent = conj[0].id.uuidString } }
            .onChange(of: photo) { Task { await lire() } }
        }
    }

    private func lire() async {
        guard let item = photo, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
        lecture = true
        let texte = await LectureCapture.texte(de: image)
        let f = model.famille
        let nomPere = [f.personne(parent)].compactMap { $0 }.first { $0.sexe == .homme }?.nom
            ?? f.conjoints(de: parent).first { $0.sexe == .homme }?.nom ?? (f.personne(parent)?.nom ?? "")
        let dejaLa = Set(f.enfants(de: parent).map { $0.prenom.lowercased() })
        lignes = nomsDepuisTexte(texte, nomParDefaut: nomPere).map {
            LigneLue(garder: !dejaLa.contains($0.prenom.lowercased()), prenom: $0.prenom, nom: $0.nom)
        }
        lecture = false
        dejaChoisi = true
    }

    private func ajouter() {
        let choisis = lignes.filter(\.garder).map { NouvelEnfant(prenom: $0.prenom, nom: $0.nom, sexe: $0.sexe) }
        model.ajouterEnfants(choisis, de: parent, avec: UUID(uuidString: autreParent))
        fermer()
    }
}
