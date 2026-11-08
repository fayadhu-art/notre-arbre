import SwiftUI
import ArbreCore

struct AccueilView: View {
    @Environment(AppModel.self) private var model
    @State private var reglages = false

    var body: some View {
        let n = model.ajoutsAujourdhui.count
        let reste = max(0, Objectif.cible - n)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                entete
                carteObjectif(n: n, reste: reste)
                Button { model.onglet = .arbre } label: {
                    Label("Ajouter des personnes", systemImage: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 58)
                }
                .verreTeinte(rayon: 29)
                chiffres
                if let m = model.listeManques.first { suggestion(m) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .background(FondColore())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $reglages) { ReglagesView().environment(model) }
    }

    private var entete: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(localeFR)).majusculeInitiale)
                    .font(.system(size: 15)).foregroundStyle(Color.gris)
                Text("Notre arbre").font(.titreEcran()).foregroundStyle(Color.encre)
            }
            Spacer()
            Button { reglages = true } label: {
                Text(model.famille.moi?.initiales ?? "")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.turquoise)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Réglages et sauvegarde")
        }
    }

    private func carteObjectif(n: Int, reste: Int) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                ZStack {
                    Circle().stroke(Color.black.opacity(0.08), lineWidth: 12)
                    Circle().trim(from: 0, to: min(1, Double(n) / Double(Objectif.cible)))
                        .stroke(Color.turquoise, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(min(n, 99))/\(Objectif.cible)").font(.system(size: 28, weight: .bold)).foregroundStyle(Color.encre)
                        Text("personnes").font(.system(size: 12)).foregroundStyle(Color.gris)
                    }
                }
                .frame(width: 104, height: 104)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(n) personnes sur \(Objectif.cible) aujourd'hui")
                VStack(alignment: .leading, spacing: 6) {
                    Text("OBJECTIF DU JOUR").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.turquoise).tracking(0.5)
                    Text(reste == 0 ? "Objectif atteint" : "Encore \(reste) personne\(reste > 1 ? "s" : "")")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Color.encre)
                    Text(reste == 0 ? "Tu peux continuer si tu veux" : "Touche l'arbre pour ajouter quelqu'un")
                        .font(.system(size: 14)).foregroundStyle(Color.gris)
                }
                Spacer(minLength: 0)
            }
            VStack(spacing: 8) {
                HStack {
                    Label("\(model.serie) jour\(model.serie > 1 ? "s" : "") d'affilée", systemImage: "flame.fill")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.corailTexte)
                    Spacer()
                    Text("Record : \(model.record)").font(.system(size: 13)).foregroundStyle(Color.gris)
                }
                semaine
            }
        }
        .padding(20)
        .carteVerre(28)
    }

    private var semaine: some View {
        let cal = model.calendrier
        let aujourdhui = cal.startOfDay(for: Date())
        let lundi = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: aujourdhui)) ?? aujourdhui
        let lettres = ["L", "M", "M", "J", "V", "S", "D"]
        return HStack {
            ForEach(0..<7, id: \.self) { i in
                let jour = cal.date(byAdding: .day, value: i, to: lundi)!
                let fait = model.ajouts(le: jour) >= Objectif.cible
                let estAujourdhui = cal.isDate(jour, inSameDayAs: aujourdhui)
                VStack(spacing: 4) {
                    ZStack {
                        Circle().fill(fait ? Color.corail : (estAujourdhui ? Color.white.opacity(0.6) : Color.black.opacity(0.07)))
                        if estAujourdhui && !fait { Circle().stroke(Color.corail, lineWidth: 2) }
                    }
                    .frame(width: 28, height: 28)
                    Text(lettres[i]).font(.system(size: 12)).foregroundStyle(Color.gris)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var chiffres: some View {
        HStack(spacing: 10) {
            chiffre("\(model.famille.personnes.count)", "personnes", .turquoise)
            chiffre("\(model.famille.nombreGenerations)", "générations", .violetTexte)
            chiffre("\(model.listeManques.count)", "questions en attente", .corailTexte)
        }
    }

    private func chiffre(_ valeur: String, _ titre: String, _ couleur: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(valeur).font(.system(size: 24, weight: .bold)).foregroundStyle(couleur)
            Text(titre).font(.system(size: 13)).foregroundStyle(Color.gris).lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 14)
        .carteVerre(22)
    }

    private func suggestion(_ m: Manque) -> some View {
        Button { model.completer(m) } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.violet))
                VStack(alignment: .leading, spacing: 4) {
                    Text("À compléter").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.violetTexte)
                    Text(model.suggestion(m)).font(.system(size: 15)).foregroundStyle(Color.encre)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
        .carteVerre(24)
    }
}
