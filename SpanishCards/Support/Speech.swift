import AVFoundation

/// Reads Spanish out loud with the built-in iOS voice.
enum Speech {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = 0.42
        synthesizer.speak(utterance)
    }
}
