import SwiftUI
import AVFAudio

@main
struct IntervalosCasaApp: App {
    init() {
        // Ambient audio mixes with Spotify, Music and other background audio.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
