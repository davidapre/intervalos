import AVFAudio

enum CueSound: String, CaseIterable, Identifiable {
    case bright = "Agudo"
    case double = "Doble"
    case bell = "Campana"
    case low = "Grave"

    var id: String { rawValue }

    var notes: [(frequency: Double, duration: Double, delay: Double)] {
        switch self {
        case .bright: return [(920, 0.16, 0)]
        case .double: return [(720, 0.12, 0), (980, 0.16, 0.17)]
        case .bell: return [(660, 0.34, 0)]
        case .low: return [(430, 0.22, 0)]
        }
    }
}

@MainActor
final class AudioCuePlayer {
    private var activePlayers: [AVAudioPlayer] = []
    private let sampleRate: UInt32 = 44_100

    func play(_ sound: CueSound) {
        activePlayers.removeAll { !$0.isPlaying }
        for note in sound.notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + note.delay) { [weak self] in
                self?.playTone(frequency: note.frequency, duration: note.duration)
            }
        }
    }

    func playCountdownTick() {
        playTone(frequency: 620, duration: 0.11)
    }

    func playFinish() {
        let finishNotes = [(660.0, 0.13, 0.0), (880.0, 0.13, 0.17), (1100.0, 0.24, 0.34)]
        for note in finishNotes {
            DispatchQueue.main.asyncAfter(deadline: .now() + note.2) { [weak self] in
                self?.playTone(frequency: note.0, duration: note.1)
            }
        }
    }

    private func playTone(frequency: Double, duration: Double) {
        guard let player = try? AVAudioPlayer(data: waveData(frequency: frequency, duration: duration)) else { return }
        player.volume = 0.85
        player.prepareToPlay()
        activePlayers.append(player)
        player.play()
    }

    private func waveData(frequency: Double, duration: Double) -> Data {
        let samples = Int(Double(sampleRate) * duration)
        let dataSize = UInt32(samples * 2)
        var data = Data()

        data.appendASCII("RIFF")
        data.appendLE(UInt32(36) + dataSize)
        data.appendASCII("WAVEfmt ")
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(UInt16(1))
        data.appendLE(sampleRate)
        data.appendLE(sampleRate * 2)
        data.appendLE(UInt16(2))
        data.appendLE(UInt16(16))
        data.appendASCII("data")
        data.appendLE(dataSize)

        for index in 0..<samples {
            let time = Double(index) / Double(sampleRate)
            let attack = min(1, time / 0.012)
            let release = min(1, (duration - time) / 0.045)
            let envelope = max(0, attack * release)
            let value = Int16(sin(2 * .pi * frequency * time) * 25_000 * envelope)
            data.appendLE(value)
        }
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(string.data(using: .ascii)!)
    }

    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
