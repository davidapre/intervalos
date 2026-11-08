import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var timer = IntervalTimer()
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if timer.phase == .setup { SetupView(timer: timer) }
            else { ActiveTimerView(timer: timer) }
        }
        .preferredColorScheme(.light)
        .onReceive(tick) { timer.tick(now: $0) }
    }
}

private struct SetupView: View {
    @ObservedObject var timer: IntervalTimer

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                HStack {
                    Label("INTERVALOS", systemImage: "chart.bar.fill")
                        .font(.caption.bold()).tracking(3)
                    Spacer()
                    Button { timer.soundEnabled.toggle() } label: {
                        Image(systemName: timer.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }

                VStack(spacing: 8) {
                    Text("Entrena. Descansa.")
                    Text("Repite.").foregroundStyle(workColor)
                }
                .font(.system(size: 43, weight: .bold, design: .rounded))
                .tracking(-2)
                .multilineTextAlignment(.center)

                Text("Configura tus intervalos y céntrate en moverte. Te avisamos de cada cambio.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 22) {
                    timeEditor("Ejercicio", color: workColor, minutes: $timer.workMinutes, seconds: $timer.workSeconds)
                    Divider()
                    timeEditor("Descanso", color: restColor, minutes: $timer.restMinutes, seconds: $timer.restSeconds)
                    Divider()
                    HStack {
                        Label("Rondas", systemImage: "arrow.clockwise")
                            .fontWeight(.semibold)
                        Spacer()
                        HStack(spacing: 18) {
                            Button { timer.adjustRounds(-1) } label: { Image(systemName: "minus") }
                            Text("\(timer.totalRounds)").font(.system(.body, design: .monospaced).weight(.semibold))
                            Button { timer.adjustRounds(1) } label: { Image(systemName: "plus") }
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: timer.start) {
                        Label("Empezar entrenamiento", systemImage: "play.fill")
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.09, green: 0.13, blue: 0.11))
                    .disabled(timer.workDuration == 0)
                }
                .padding(24)
                .background(.white, in: RoundedRectangle(cornerRadius: 26))
                .shadow(color: .black.opacity(0.08), radius: 28, y: 14)
            }
            .padding(24)
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.92).ignoresSafeArea())
    }

    @ViewBuilder
    private func timeEditor(_ title: String, color: Color, minutes: Binding<Int>, seconds: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) { Circle().fill(color).frame(width: 9); Text(title).fontWeight(.semibold) }
            HStack {
                numberField("MIN", value: minutes)
                Text(":").font(.title2.monospaced()).foregroundStyle(.secondary)
                numberField("SEG", value: seconds)
            }
        }
    }

    private func numberField(_ suffix: String, value: Binding<Int>) -> some View {
        HStack(alignment: .lastTextBaseline) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .font(.title.monospaced())
                .multilineTextAlignment(.center)
            Text(suffix).font(.caption2.bold()).foregroundStyle(.secondary)
        }
        .padding().background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ActiveTimerView: View {
    @ObservedObject var timer: IntervalTimer

    private var background: Color { timer.phase == .rest ? restColor : workColor }
    private var progress: Double { timer.phaseDuration > 0 ? timer.remaining / timer.phaseDuration : 0 }

    var body: some View {
        VStack(spacing: 30) {
            HStack {
                Label("INTERVALOS", systemImage: "chart.bar.fill").font(.caption.bold()).tracking(3)
                Spacer()
                Button { timer.soundEnabled.toggle() } label: {
                    Image(systemName: timer.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }.buttonStyle(.bordered).buttonBorderShape(.circle)
            }

            Spacer()
            HStack(spacing: 18) {
                Text(timer.phaseTitle).font(.caption.bold()).tracking(3)
                Text("RONDA \(timer.currentRound) / \(timer.totalRounds)").font(.caption.monospaced()).opacity(0.7)
            }
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 5)
                Circle().trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(timer.format(timer.remaining))
                    .font(.system(size: 70, weight: .medium, design: .monospaced)).tracking(-6)
            }
            .frame(maxWidth: 330).aspectRatio(1, contentMode: .fit)
            Text(timer.nextLabel).font(.footnote.weight(.semibold)).opacity(0.8)

            HStack(spacing: 24) {
                circleButton("arrow.counterclockwise", action: timer.restart)
                Button(action: timer.togglePause) {
                    Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2).foregroundStyle(.black).frame(width: 76, height: 76).background(.white, in: Circle())
                }.disabled(timer.phase == .finished)
                circleButton("forward.end.fill", action: timer.skip).disabled(timer.phase == .finished)
            }
            Button("Cambiar configuración", action: timer.edit)
                .font(.footnote).foregroundStyle(.white.opacity(0.8)).underline()
            Spacer()
        }
        .padding(24)
        .foregroundStyle(.white)
        .background(background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.35), value: timer.phase)
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 52, height: 52)
                .background(.white.opacity(0.13), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.35)))
        }
    }
}

private let workColor = Color(red: 0.09, green: 0.65, blue: 0.41)
private let restColor = Color(red: 0.16, green: 0.47, blue: 0.85)
