import SwiftUI
import ArbreCore

struct FamilleListeView: View {
    @Environment(AppModel.self) private var model
    @State private var recherche = ""

    var body: some View {
        let f = model.famille
        let liste = f.personnes
            .filter { recherche.isEmpty || $0.nomComplet.localizedStandardContains(recherche) }
            .sorted { $0.prenom.localizedCompare($1.prenom) == .orderedAscending }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Famille").font(.titreEcran()).foregroundStyle(Color.encre)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Color.gris)
                    TextField("Rechercher", text: $recherche)
                }
                .padding(.horizontal, 16).frame(height: 48)
                .glassEffect(.regular, in: .capsule)
                VStack(spacing: 0) {
                    ForEach(Array(liste.enumerated()), id: \.element.id) { i, p in
                        NavigationLink(value: p.id) {
                            HStack(spacing: 12) {
                                Avatar(initiales: p.initiales, branche: f.branche(de: p.id), taille: 40)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.nomComplet).font(.system(size: 16, weight: .medium)).foregroundStyle(Color.encre)
                                    Text(model.resume(p.id)).font(.system(size: 13)).foregroundStyle(Color.gris)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0x8E8E93))
                            }
                            .frame(minHeight: 60)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if i < liste.count - 1 { Divider().padding(.leading, 52) }
                    }
                }
                .padding(.horizontal, 16)
                .carteVerre(24)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(FondColore())
        .toolbar(.hidden, for: .navigationBar)
    }
}
