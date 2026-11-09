import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var timer = IntervalTimer()
    @StateObject private var workouts = WorkoutStore()
    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if timer.phase == .setup {
                SetupView(timer: timer, workouts: workouts)
            } else {
                ActiveTimerView(timer: timer)
            }
        }
        .preferredColorScheme(.light)
        .onReceive(tick) { timer.tick(now: $0) }
    }
}

private struct SetupView: View {
    @ObservedObject var timer: IntervalTimer
    @ObservedObject var workouts: WorkoutStore
    @State private var exercisesExpanded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                compactHeader

                if !workouts.plans.isEmpty {
                    savedWorkouts
                }

                VStack(spacing: 20) {
                    TextField("Nombre del entrenamiento", text: $timer.workoutName)
                        .font(.title3.weight(.bold))
                        .textInputAutocapitalization(.sentences)
                        .padding(14)
                        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))

                    HStack(spacing: 12) {
                        compactTimeEditor("Ejercicio", color: workColor, minutes: $timer.workMinutes, seconds: $timer.workSeconds)
                        compactTimeEditor("Descanso", color: restColor, minutes: $timer.restMinutes, seconds: $timer.restSeconds)
                    }

                    Divider()
                    HStack {
                        Label("Rondas", systemImage: "arrow.clockwise").fontWeight(.semibold)
                        Spacer()
                        HStack(spacing: 20) {
                            Button { timer.adjustRounds(-1) } label: { Image(systemName: "minus") }
                            Text("\(timer.totalRounds)").font(.body.monospaced().weight(.semibold))
                            Button { timer.adjustRounds(1) } label: { Image(systemName: "plus") }
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        Label("Tiempo del entrenamiento", systemImage: "clock.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(timer.format(timer.totalWorkoutDuration))
                            .font(.title3.monospaced().weight(.bold))
                            .foregroundStyle(inkColor)
                    }
                    .padding(12)
                    .background(workColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                exercisesExpanded.toggle()
                            }
                        } label: {
                            HStack {
                                Label("Ejercicios de cada ronda", systemImage: "list.number")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("\(timer.totalRounds)")
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Image(systemName: exercisesExpanded ? "chevron.up" : "chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if exercisesExpanded {
                            ForEach(0..<timer.totalRounds, id: \.self) { index in
                                exerciseRow(index: index)
                            }
                        }
                    }

                    Divider()
                    VStack(alignment: .leading, spacing: 13) {
                        Label("Sonidos", systemImage: "speaker.wave.2.fill").fontWeight(.semibold)
                        soundPicker("Ejercicio", selection: $timer.workSound, preview: timer.previewWorkSound)
                        soundPicker("Descanso", selection: $timer.restSound, preview: timer.previewRestSound)
                    }

                    HStack(spacing: 12) {
                        Button {
                            let plan = timer.makePlan()
                            workouts.save(plan)
                            timer.load(plan)
                        } label: {
                            Label("Guardar", systemImage: "bookmark.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)

                        Button(action: timer.start) {
                            Label("Empezar", systemImage: "play.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(inkColor)
                        .disabled(timer.workDuration == 0)
                    }
                }
                .padding(20)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.07), radius: 24, y: 12)
            }
            .padding(20)
        }
        .background(Color(red: 0.96, green: 0.95, blue: 0.92).ignoresSafeArea())
    }

    private var compactHeader: some View {
        HStack {
            HStack(spacing: 0) {
                Text("Intervalos").fontWeight(.heavy)
                Text(" by David").fontWeight(.medium).foregroundStyle(workColor)
            }
            .font(.title2)
            Spacer()
            Button { timer.soundEnabled.toggle() } label: {
                Image(systemName: timer.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    private var savedWorkouts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MIS ENTRENAMIENTOS").font(.caption.bold()).tracking(1.6).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(workouts.plans) { plan in
                        HStack(spacing: 12) {
                            Image(plan.coverExercise.imageName)
                                .resizable().scaledToFit()
                                .frame(width: 76, height: 76)
                                .background(workColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(plan.name).font(.headline).foregroundStyle(inkColor)
                                Text("\(plan.workSeconds)s / \(plan.restSeconds)s")
                                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                                Text("\(plan.rounds) rondas").font(.caption).foregroundStyle(.secondary)
                                Text("\(formatDuration(plan.totalDuration)) tiempo entreno")
                                    .font(.caption.monospaced().weight(.semibold)).foregroundStyle(workColor)
                            }
                            Button { timer.load(plan) } label: {
                                Image(systemName: "arrow.down.circle.fill").font(.title3).foregroundStyle(workColor)
                            }.buttonStyle(.plain)
                            Button { workouts.delete(plan) } label: {
                                Image(systemName: "trash").font(.caption).foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(.white, in: RoundedRectangle(cornerRadius: 19))
                    }
                }
            }
        }
    }

    private func compactTimeEditor(_ title: String, color: Color, minutes: Binding<Int>, seconds: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(title).font(.subheadline.weight(.semibold))
            }
            HStack(spacing: 4) {
                numberField("M", value: minutes)
                Text(":").foregroundStyle(.secondary)
                numberField("S", value: seconds)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func numberField(_ suffix: String, value: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .font(.title3.monospaced())
                .multilineTextAlignment(.center)
            Text(suffix).font(.caption2.bold()).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12).padding(.horizontal, 5)
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }

    private func exerciseRow(index: Int) -> some View {
        let selection = Binding<Exercise>(
            get: { index < timer.roundExercises.count ? timer.roundExercises[index] : .burpees },
            set: { timer.setExercise($0, for: index + 1) }
        )
        return HStack(spacing: 12) {
            Text("\(index + 1)").font(.caption.monospaced().bold()).foregroundStyle(.secondary).frame(width: 22)
            Image(selection.wrappedValue.imageName)
                .resizable().scaledToFit().frame(width: 52, height: 52)
                .background(workColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            Picker("Ronda \(index + 1)", selection: selection) {
                ForEach(Exercise.allCases) { exercise in Text(exercise.rawValue).tag(exercise) }
            }
            .pickerStyle(.menu)
            Spacer()
        }
        .padding(8)
        .background(Color.black.opacity(0.025), in: RoundedRectangle(cornerRadius: 14))
    }

    private func soundPicker(_ title: String, selection: Binding<CueSound>, preview: @escaping () -> Void) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(CueSound.allCases) { sound in Text(sound.rawValue).tag(sound) }
            }
            .labelsHidden()
            Button(action: preview) { Image(systemName: "play.circle.fill").font(.title3) }.buttonStyle(.plain)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ActiveTimerView: View {
    @ObservedObject var timer: IntervalTimer

    private var background: Color {
        if timer.phase == .countdown { return inkColor }
        return timer.phase == .rest ? restColor : workColor
    }
    private var progress: Double { timer.phaseDuration > 0 ? timer.remaining / timer.phaseDuration : 0 }
    private var shownExercise: Exercise { timer.phase == .rest ? timer.nextExercise : timer.currentExercise }
    private var shownTitle: String {
        timer.phase == .rest && timer.currentRound < timer.totalRounds ? "Siguiente: \(shownExercise.rawValue)" : shownExercise.rawValue
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                HStack(spacing: 0) {
                    Text("Intervalos").fontWeight(.heavy)
                    Text(" by David").fontWeight(.medium).opacity(0.75)
                }
                .font(.headline)
                Spacer()
                Button { timer.soundEnabled.toggle() } label: {
                    Image(systemName: timer.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }.buttonStyle(.bordered)
            }

            Spacer(minLength: 4)

            if timer.phase != .countdown && timer.phase != .finished {
                VStack(spacing: 6) {
                    Image(shownExercise.imageName)
                        .resizable().scaledToFit().frame(maxHeight: 150)
                    Text(shownTitle).font(.title3.bold())
                }
            }

            HStack(spacing: 16) {
                Text(timer.phaseTitle).font(.caption.bold()).tracking(2.5)
                if timer.phase != .countdown {
                    Text("RONDA \(timer.currentRound) / \(timer.totalRounds)").font(.caption.monospaced()).opacity(0.72)
                }
            }

            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 5)
                Circle().trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(timer.displayValue)
                    .font(.system(size: timer.phase == .countdown ? 82 : 62, weight: .medium, design: .monospaced))
                    .tracking(timer.phase == .countdown ? -2 : -5)
            }
            .frame(maxWidth: 245).aspectRatio(1, contentMode: .fit)

            Text(timer.nextLabel).font(.footnote.weight(.semibold)).opacity(0.82)

            HStack(spacing: 12) {
                workoutClock(title: "LLEVA", value: timer.formatElapsed(timer.workoutElapsed))
                workoutClock(title: "QUEDA", value: timer.format(timer.workoutRemaining))
            }

            HStack(spacing: 24) {
                circleButton("arrow.counterclockwise", action: timer.restart)
                Button(action: timer.togglePause) {
                    Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2).foregroundStyle(.black).frame(width: 70, height: 70).background(.white, in: Circle())
                }.disabled(timer.phase == .finished || timer.phase == .countdown)
                circleButton("forward.end.fill", action: timer.skip).disabled(timer.phase == .finished)
            }
            Button("Cambiar configuración", action: timer.edit)
                .font(.footnote).foregroundStyle(.white.opacity(0.8)).underline()
            Spacer(minLength: 4)
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.35), value: timer.phase)
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).frame(width: 50, height: 50)
                .background(.white.opacity(0.13), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.35)))
        }
    }

    private func workoutClock(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption2.bold()).tracking(1.4).opacity(0.72)
            Text(value).font(.headline.monospaced().weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
    }
}

private let inkColor = Color(red: 0.09, green: 0.13, blue: 0.11)
private let workColor = Color(red: 0.09, green: 0.65, blue: 0.41)
private let restColor = Color(red: 0.16, green: 0.47, blue: 0.85)
