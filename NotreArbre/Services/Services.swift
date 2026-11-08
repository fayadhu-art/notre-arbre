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

/// Lecture du texte d'un document photographié, en français, sur l'iPhone.
enum LectureDocument {
    static func texte(de image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { return "" }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return try await withCheckedThrowingContinuation { c in
            let requete = VNRecognizeTextRequest { r, erreur in
                if let erreur { c.resume(throwing: erreur); return }
                let lignes = (r.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
                c.resume(returning: lignes.joined(separator: "\n"))
            }
            requete.recognitionLevel = .accurate
            requete.recognitionLanguages = ["fr-FR"]
            requete.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async {
                try? VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([requete])
            }
        }
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
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
