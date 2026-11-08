import Foundation
import Speech
import AVFoundation

/// Dictée vocale en français, sur l'iPhone.
@MainActor
@Observable
final class Dictee {
    var texte = ""
    var enCours = false
    var erreur: String?

    private let reconnaisseur = SFSpeechRecognizer(locale: Locale(identifier: "fr-FR"))
    private let moteur = AVAudioEngine()
    private var requete: SFSpeechAudioBufferRecognitionRequest?
    private var tache: SFSpeechRecognitionTask?

    private func autoriser() async -> Bool {
        let statut = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard statut == .authorized else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func demarrer() async {
        guard !enCours else { return }
        erreur = nil
        guard await autoriser() else {
            erreur = "Autorise le micro et la reconnaissance vocale dans Réglages pour répondre à la voix."
            return
        }
        guard let r = reconnaisseur, r.isAvailable else {
            erreur = "La dictée en français n'est pas disponible pour le moment. Écris ta réponse."
            return
        }
        texte = ""
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            req.addsPunctuation = true
            if r.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            requete = req
            let entree = moteur.inputNode
            entree.removeTap(onBus: 0)
            entree.installTap(onBus: 0, bufferSize: 1024, format: entree.outputFormat(forBus: 0), block: Self.prise(req))
            moteur.prepare()
            try moteur.start()
            enCours = true
            tache = r.recognitionTask(with: req, resultHandler: Self.suivi(self))
        } catch {
            erreur = "Impossible de démarrer le micro."
            nettoyer()
        }
    }

    func arreter() {
        requete?.endAudio()
        nettoyer()
    }

    fileprivate func recevoir(_ t: String?, fini: Bool) {
        if let t { texte = t }
        if fini { nettoyer() }
    }

    private func nettoyer() {
        if moteur.isRunning { moteur.stop() }
        moteur.inputNode.removeTap(onBus: 0)
        requete = nil
        tache = nil
        enCours = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // Fermetures hors du fil principal : le micro et la reconnaissance rappellent sur d'autres fils.
    nonisolated private static func prise(_ req: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        { buffer, _ in req.append(buffer) }
    }

    nonisolated private static func suivi(_ d: Dictee) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak d] resultat, erreur in
            let t = resultat?.bestTranscription.formattedString
            let fini = erreur != nil || (resultat?.isFinal ?? false)
            Task { @MainActor in d?.recevoir(t, fini: fini) }
        }
    }
}
