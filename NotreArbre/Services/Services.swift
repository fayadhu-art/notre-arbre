import UIKit
@preconcurrency import Vision
import UserNotifications
import ArbreCore

/// Rappel du soir à 19 h quand l'objectif du jour n'est pas atteint.
enum Rappel {
    static func autoriser() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func planifier(ajoutsAujourdhui n: Int) async {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: ["rappel-aujourdhui", "rappel-demain"])
        let cal = Calendar.current
        let maintenant = Date()
        func programmer(_ id: String, jour: Date, reste: Int) {
            var c = cal.dateComponents([.year, .month, .day], from: jour)
            c.hour = 19
            c.minute = 0
            let contenu = UNMutableNotificationContent()
            contenu.title = "Notre arbre"
            contenu.body = "Il te reste \(reste) personne\(reste > 1 ? "s" : "") pour ton objectif du jour."
            contenu.sound = .default
            centre.add(UNNotificationRequest(identifier: id, content: contenu,
                                             trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
        }
        let reste = Objectif.cible - n
        if reste > 0, let dix9 = cal.date(bySettingHour: 19, minute: 0, second: 0, of: maintenant), dix9 > maintenant {
            programmer("rappel-aujourdhui", jour: maintenant, reste: reste)
        }
        if let demain = cal.date(byAdding: .day, value: 1, to: maintenant) {
            programmer("rappel-demain", jour: demain, reste: Objectif.cible)
        }
    }
}

/// Envoie les questions à un proche par WhatsApp, ou par le menu de partage si WhatsApp n'est pas installé.
enum DemandeProche {
    @MainActor
    static func envoyer(_ message: String) {
        var permis = CharacterSet.urlQueryAllowed
        permis.remove(charactersIn: "&+=?#")
        if let texte = message.addingPercentEncoding(withAllowedCharacters: permis),
           let url = URL(string: "whatsapp://send?text=\(texte)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }
        let partage = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var haut = scene?.keyWindow?.rootViewController
        while let p = haut?.presentedViewController { haut = p }
        haut?.present(partage, animated: true)
    }
}

/// Lit le texte d'une capture d'écran, en français, directement sur l'iPhone (sans internet).
enum LectureCapture {
    static func texte(de image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        return await withCheckedContinuation { c in
            DispatchQueue.global(qos: .userInitiated).async {
                let requete = VNRecognizeTextRequest()
                requete.recognitionLevel = .accurate
                requete.recognitionLanguages = ["fr-FR"]
                requete.usesLanguageCorrection = false
                do {
                    try VNImageRequestHandler(cgImage: cg, options: [:]).perform([requete])
                    let lignes = (requete.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    c.resume(returning: lignes.joined(separator: "\n"))
                } catch {
                    c.resume(returning: "")
                }
            }
        }
    }
}
