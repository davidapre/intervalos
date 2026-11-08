import SwiftUI
import AVFAudio

@main
struct IntervalosCasaApp: App {
    init() {
        // Keep Spotify playing, while allowing interval cues through the silent switch.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
