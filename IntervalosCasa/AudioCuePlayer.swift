import AVFAudio

final class AudioCuePlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.55
        try? engine.start()
    }

    func play(work: Bool) {
        let notes = work ? [740.0, 980.0] : [520.0]
        notes.enumerated().forEach { index, note in
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.16) { [weak self] in
                self?.tone(frequency: note, duration: 0.13)
            }
        }
    }

    func playFinish() {
        [660.0, 880.0, 1100.0].enumerated().forEach { index, note in
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.16) { [weak self] in
                self?.tone(frequency: note, duration: 0.13)
            }
        }
    }

    private func tone(frequency: Double, duration: Double) {
        let frames = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        for frame in 0..<Int(frames) {
            let position = Double(frame) / sampleRate
            let envelope = min(1, position / 0.012) * min(1, (duration - position) / 0.035)
            samples[frame] = Float(sin(2 * .pi * frequency * position) * 0.45 * max(0, envelope))
        }

        player.scheduleBuffer(buffer)
        if !engine.isRunning { try? engine.start() }
        if !player.isPlaying { player.play() }
    }
}
