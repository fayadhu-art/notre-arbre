import SwiftUI
import ArbreCore

@main
struct NotreArbreApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RacineView()
                .environment(model)
                .environment(\.locale, localeFR)
                .task { await Rappel.autoriser() }
        }
    }
}

struct RacineView: View {
    @Environment(AppModel.self) private var model
    @State private var cheminAccueil = NavigationPath()
    @State private var cheminArbre = NavigationPath()
    @State private var cheminFamille = NavigationPath()

    var body: some View {
        @Bindable var model = model
        ZStack(alignment: .bottom) {
            switch model.onglet {
            case .accueil:
                NavigationStack(path: $cheminAccueil) { AccueilView().destinations() }
            case .arbre:
                NavigationStack(path: $cheminArbre) { ArbreView().destinations() }
            case .famille:
                NavigationStack(path: $cheminFamille) { FamilleListeView().destinations() }
            }
            BarreOnglets()
        }
        .sheet(item: $model.ajout) { a in
            FormulaireAjoutView(ajout: a).environment(model)
        }
        .sheet(item: Binding(get: { model.edition.map(IdentifiantFiche.init) }, set: { model.edition = $0?.id })) { e in
            if let p = model.famille.personne(e.id) { EditionView(personne: p, supprimer: {}).environment(model) }
        }
        .sheet(item: $model.couple) { c in
            EnfantsDuCoupleView(sujet: c.sujet, conjoint: c.conjoint).environment(model)
        }
        .fullScreenCover(isPresented: $model.objectifAtteint) {
            ObjectifAtteintView(terminer: { model.objectifAtteint = false; model.onglet = .accueil },
                                continuer: { model.objectifAtteint = false })
                .environment(model)
        }
        .sheet(isPresented: .constant(model.famille.moi == nil)) {
            PremierLancementView().environment(model).interactiveDismissDisabled()
        }
        .alert("Oups", isPresented: Binding(get: { model.erreur != nil }, set: { if !$0 { model.erreur = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.erreur ?? "")
        }
    }
}

struct IdentifiantFiche: Identifiable { let id: UUID }

extension View {
    func destinations() -> some View {
        navigationDestination(for: UUID.self) { FicheView(id: $0) }
    }
}

/// Barre d'onglets flottante en pilule, avec le bouton micro rond à droite.
struct BarreOnglets: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    onglet(.accueil, "Accueil", "house")
                    onglet(.arbre, "Arbre", "point.3.connected.trianglepath.dotted")
                    onglet(.famille, "Famille", "person.2")
                }
                .padding(.horizontal, 6)
                .frame(height: 64)
                .glassEffect(.regular.interactive(), in: .capsule)

                Button { model.onglet = .arbre } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.turquoise)
                        .frame(width: 64, height: 64)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Ajouter des personnes dans l'arbre")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func onglet(_ o: AppModel.Onglet, _ titre: String, _ icone: String) -> some View {
        let actif = model.onglet == o
        return Button { model.onglet = o } label: {
            VStack(spacing: 2) {
                Image(systemName: icone).font(.system(size: 20, weight: .medium))
                Text(titre).font(.system(size: 11, weight: actif ? .semibold : .medium))
            }
            .foregroundStyle(actif ? Color.turquoise : Color.encre)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(actif ? Color.turquoise.opacity(0.14) : .clear))
        }
        .buttonStyle(.plain)
    }
}

struct PremierLancementView: View {
    @Environment(AppModel.self) private var model
    @State private var prenom = ""
    @State private var nom = ""
    @State private var sexe: Sexe = .homme

    var body: some View {
        ZStack {
            FondColore()
            VStack(alignment: .leading, spacing: 20) {
                Text("Bienvenue").font(.titreEcran())
                Text("L'arbre part de toi. Ensuite, touche une personne dans l'arbre pour ajouter ses parents, ses frères et sœurs ou ses enfants.")
                    .font(.system(size: 16)).foregroundStyle(Color.gris)
                VStack(spacing: 0) {
                    TextField("Ton prénom", text: $prenom).textContentType(.givenName).padding(16)
                    Divider()
                    TextField("Ton nom", text: $nom).textContentType(.familyName).padding(16)
                }
                .carteVerre(22)
                Picker("Tu es", selection: $sexe) {
                    Text("Un homme").tag(Sexe.homme)
                    Text("Une femme").tag(Sexe.femme)
                }
                .pickerStyle(.segmented)
                Spacer()
                Button {
                    model.creerMoi(prenom: prenom.trimmingCharacters(in: .whitespaces), nom: nom.trimmingCharacters(in: .whitespaces), sexe: sexe)
                } label: {
                    Text("Commencer").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 58)
                }
                .verreTeinte(rayon: 29)
                .disabled(prenom.trimmingCharacters(in: .whitespaces).isEmpty || nom.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(24)
        }
    }
}
