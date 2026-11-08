import SwiftUI
import UniformTypeIdentifiers
import ArbreCore

struct ObjectifAtteintView: View {
    @Environment(AppModel.self) private var model
    let terminer: () -> Void
    let continuer: () -> Void
    @State private var exporter = false

    var body: some View {
        let ajouts = model.ajoutsAujourdhui
        ZStack {
            FondColore()
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 64, weight: .bold)).foregroundStyle(Color.turquoise)
                        .frame(width: 150, height: 150)
                        .overlay(Circle().stroke(Color.turquoise, lineWidth: 10).padding(13))
                        .frame(width: 176, height: 176)
                        .glassEffect(.regular, in: .circle)
                        .padding(.top, 40)
                        .accessibilityLabel("Objectif atteint")
                    Text("Objectif atteint").font(.system(size: 30, weight: .bold)).foregroundStyle(Color.encre)
                    Text("\(ajouts.count) personnes ajoutées aujourd'hui.\n\(model.serie) jour\(model.serie > 1 ? "s" : "") d'affilée\(model.serie >= model.record && model.serie > 1 ? ", nouveau record." : ".")")
                        .font(.system(size: 16)).foregroundStyle(Color(hex: 0x3A3A3C)).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("AJOUTÉES AUJOURD'HUI").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.gris).tracking(0.5)
                            .padding(.top, 12).padding(.bottom, 4)
                        ForEach(Array(ajouts.enumerated()), id: \.element.id) { i, p in
                            HStack(spacing: 12) {
                                Avatar(initiales: p.initiales, branche: model.famille.branche(de: p.id), taille: 34)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.nomComplet).font(.system(size: 15, weight: .medium))
                                    Text(model.resume(p.id)).font(.system(size: 13)).foregroundStyle(Color.gris)
                                }
                            }
                            .frame(minHeight: 52)
                            if i < ajouts.count - 1 { Divider() }
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .carteVerre(24)

                    Button { exporter = true } label: {
                        Label("Enregistrer une copie de l'arbre", systemImage: "externaldrive.badge.icloud")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.violetTexte)
                            .frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    Text("Garde une copie dans iCloud Drive ou Fichiers : tu pourras tout restaurer si tu réinstalles l'appli.")
                        .font(.system(size: 12)).foregroundStyle(Color.gris).multilineTextAlignment(.center)

                    Button(action: terminer) {
                        Text("Terminer pour aujourd'hui").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                    }
                    .verreTeinte(rayon: 28)
                    .padding(.top, 8)
                    Button(action: continuer) {
                        Text("Continuer quand même").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.turquoise)
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .fileExporter(isPresented: $exporter, document: DocumentSauvegarde(data: model.exporter() ?? Data()),
                      contentType: .json, defaultFilename: DocumentSauvegarde.nomDuJour) { _ in }
    }
}

struct DocumentSauvegarde: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }

    static var nomDuJour: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "notre-arbre-\(f.string(from: Date())).json"
    }
}

struct ReglagesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var fermer
    @State private var exporter = false
    @State private var importer = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { exporter = true } label: { Label("Enregistrer une copie de l'arbre", systemImage: "square.and.arrow.down") }
                    Button { importer = true } label: { Label("Restaurer une copie", systemImage: "arrow.counterclockwise") }
                } header: { Text("Sauvegarde") } footer: {
                    Text("Restaurer remplace l'arbre actuel par celui de la copie.")
                }
                Section("Rappel") {
                    Text("Chaque jour à 19 h, si tes 5 personnes ne sont pas faites.")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { fermer() } } }
            .fileExporter(isPresented: $exporter, document: DocumentSauvegarde(data: model.exporter() ?? Data()),
                          contentType: .json, defaultFilename: DocumentSauvegarde.nomDuJour) { _ in }
            .fileImporter(isPresented: $importer, allowedContentTypes: [.json]) { resultat in
                guard case .success(let url) = resultat else { return }
                let acces = url.startAccessingSecurityScopedResource()
                defer { if acces { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url) { model.restaurer(data) } else { model.erreur = "Ce fichier n'a pas pu être lu." }
                fermer()
            }
        }
    }
}
