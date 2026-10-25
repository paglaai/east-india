import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioService: ObservableObject {
    @Published private(set) var isSoundCheckPlaying = false
    @Published private(set) var isListeningPlaying = false
    @Published private(set) var playbackFinished = false
    @Published private(set) var playbackError: String?
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var volume: Double = 0.75 {
        didSet {
            player?.volume = Float(min(max(volume, 0), 1))
        }
    }

    private enum PlaybackKind {
        case soundCheck
        case listening
    }

    private var player: AVPlayer?
    private var activeKind: PlaybackKind?
    private var hasStartedListening = false
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var onSoundCheckFinished: (() -> Void)?
    private var onListeningFinished: (() -> Void)?
    private var soundCheckFile: URL?

    func playSoundCheck(completion: @escaping () -> Void) {
        guard !isSoundCheckPlaying, !isListeningPlaying else { return }
        stopPlayback()
        playbackError = nil

        do {
            let toneURL = try Self.makeSoundCheckTone()
            soundCheckFile = toneURL
            let item = AVPlayerItem(url: toneURL)
            activeKind = .soundCheck
            onSoundCheckFinished = completion
            player = AVPlayer(playerItem: item)
            player?.volume = Float(volume)
            observeEnd(of: item)
            isSoundCheckPlaying = true
            player?.play()
        } catch {
            playbackError = "The sound check could not start: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func playListeningAudio(from url: URL, completion: @escaping () -> Void) -> Bool {
        guard !hasStartedListening,
              FileManager.default.fileExists(atPath: url.path),
              !isSoundCheckPlaying,
              !isListeningPlaying else { return false }

        stopPlayback()
        playbackError = nil
        playbackFinished = false
        currentTime = 0

        let assetDuration = AVURLAsset(url: url).duration.seconds
        duration = assetDuration.isFinite && assetDuration > 0 ? assetDuration : 0
        let item = AVPlayerItem(url: url)
        activeKind = .listening
        hasStartedListening = true
        onListeningFinished = completion
        player = AVPlayer(playerItem: item)
        player?.volume = Float(volume)
        observeEnd(of: item)
        observeProgress()
        isListeningPlaying = true
        player?.play()
        return true
    }

    func stopPlayback() {
        player?.pause()
        removeObservers()
        player?.replaceCurrentItem(with: nil)
        player = nil
        activeKind = nil
        isSoundCheckPlaying = false
        isListeningPlaying = false
        onSoundCheckFinished = nil
        onListeningFinished = nil
        currentTime = 0
        removeSoundCheckFile()
    }

    func resetForNewSession() {
        stopPlayback()
        hasStartedListening = false
        playbackFinished = false
        playbackError = nil
        duration = 0
    }

    static func copyAudioToAppSupport(from source: URL) throws -> URL {
        let hasScopedAccess = source.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                source.stopAccessingSecurityScopedResource()
            }
        }

        guard !source.pathExtension.isEmpty else {
            throw AudioImportError.missingFileExtension
        }

        let sourceAsset = AVURLAsset(url: source)
        guard sourceAsset.isPlayable else {
            throw AudioImportError.unplayableAudio
        }

        guard let supportRoot = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AudioImportError.storageUnavailable
        }

        let audioDirectory = supportRoot.appendingPathComponent("EastIndia/ListeningAudio", isDirectory: true)
        try FileManager.default.createDirectory(
            at: audioDirectory,
            withIntermediateDirectories: true
        )

        let destination = audioDirectory
            .appendingPathComponent("listening-\(UUID().uuidString)")
            .appendingPathExtension(source.pathExtension)
        try FileManager.default.copyItem(at: source, to: destination)

        guard AVURLAsset(url: destination).isPlayable else {
            try? FileManager.default.removeItem(at: destination)
            throw AudioImportError.unplayableAudio
        }
        return destination
    }

    private func observeEnd(of item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finishCurrentPlayback()
            }
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.failCurrentPlayback()
            }
        }
    }

    private func observeProgress() {
        guard let player else { return }
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self, time.seconds.isFinite else { return }
                self.currentTime = max(time.seconds, 0)
            }
        }
    }

    private func finishCurrentPlayback() {
        let finishedKind = activeKind
        removeObservers()
        activeKind = nil
        player?.replaceCurrentItem(with: nil)
        player = nil
        removeSoundCheckFile()

        switch finishedKind {
        case .soundCheck:
            isSoundCheckPlaying = false
            let completion = onSoundCheckFinished
            onSoundCheckFinished = nil
            completion?()
        case .listening:
            isListeningPlaying = false
            playbackFinished = true
            currentTime = duration
            let completion = onListeningFinished
            onListeningFinished = nil
            completion?()
        case .none:
            break
        }
    }

    private func failCurrentPlayback() {
        let failedKind = activeKind
        stopPlayback()
        switch failedKind {
        case .some(.soundCheck):
            playbackError = "The test tone could not play. Check the Mac's audio output and try again."
        case .some(.listening):
            playbackError = "The listening audio could not be played. Confirm the file is a supported audio format."
        case .none:
            playbackError = "Audio playback stopped unexpectedly."
        }
    }

    private func removeSoundCheckFile() {
        if let soundCheckFile {
            try? FileManager.default.removeItem(at: soundCheckFile)
            self.soundCheckFile = nil
        }
    }

    private func removeObservers() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
            self.failureObserver = nil
        }
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    private static func makeSoundCheckTone() throws -> URL {
        let sampleRate: UInt32 = 44_100
        let sampleCount = Int(sampleRate / 2)
        let dataSize = UInt32(sampleCount * MemoryLayout<Int16>.size)
        var wav = Data()
        wav.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(36 + dataSize, to: &wav)
        wav.append(contentsOf: "WAVEfmt ".utf8)
        appendLittleEndian(UInt32(16), to: &wav)
        appendLittleEndian(UInt16(1), to: &wav)
        appendLittleEndian(UInt16(1), to: &wav)
        appendLittleEndian(sampleRate, to: &wav)
        appendLittleEndian(sampleRate * 2, to: &wav)
        appendLittleEndian(UInt16(2), to: &wav)
        appendLittleEndian(UInt16(16), to: &wav)
        wav.append(contentsOf: "data".utf8)
        appendLittleEndian(dataSize, to: &wav)

        for sampleIndex in 0..<sampleCount {
            let sample = Int16(
                sin(2 * Double.pi * 880 * Double(sampleIndex) / Double(sampleRate)) * 5_000
            )
            appendLittleEndian(sample, to: &wav)
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("east-india-sound-check-\(UUID().uuidString).wav")
        try wav.write(to: destination, options: .atomic)
        return destination
    }

    private static func appendLittleEndian<Value: FixedWidthInteger>(
        _ value: Value,
        to data: inout Data
    ) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) {
            data.append(contentsOf: $0)
        }
    }
}

private enum AudioImportError: LocalizedError {
    case missingFileExtension
    case unplayableAudio
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .missingFileExtension:
            "Choose an audio file with a file extension."
        case .unplayableAudio:
            "This file is not a playable audio file. Choose a supported MP3, M4A, or WAV file."
        case .storageUnavailable:
            "The app could not access its local audio storage."
        }
    }
}
