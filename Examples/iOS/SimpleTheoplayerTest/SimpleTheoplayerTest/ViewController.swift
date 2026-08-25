import UIKit
import THEOplayerSDK

/// Standalone THEOplayer validation harness — no New Relic code involved at all.
///
/// Exercises every event/attribute the future `NRTrackerTHEOplayer` will need to consume (see the iOS
/// THEOplayer CDD, Confluence page 5972984436, §10/§11), and logs every one of them on screen so nothing
/// about THEOplayer's real runtime behavior is a surprise once the actual tracker gets written.
///
/// NOTE on API surface: several THEOplayer call shapes below (source construction, exact `addAsSubview`
/// signature, view-attachment/frame timing) are written from documented API descriptions rather than the
/// SDK's actual headers, since those weren't directly available while writing this. Expect to need a
/// couple of quick signature fixes once this actually builds against the real pod (see Task #6) — that's
/// expected for a first integration pass, not a sign anything here was guessed carelessly.
final class ViewController: UIViewController {

    // MARK: - THEOplayer

    private var theoplayer: THEOplayer?
    private var listeners: [Any] = [] // holds every listener token returned by addEventListener, for symmetric teardown

    // MARK: - UI

    private let playerContainer = UIView()
    private let eventLog = EventLogView()

    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let rateLabel = UILabel()
    private let mutedLabel = UILabel()
    private let renditionLabel = UILabel()
    private let droppedFramesLabel = UILabel()
    private let renderedFpsLabel = UILabel()

    private var rateIndex = 1
    private let rateSteps: [Float] = [0.5, 1.0, 1.5, 2.0]

    private let testSources: [(title: String, url: String)] = [
        ("VOD (multi-rendition)", "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"),
        // bitdash-a.akamaihd.net's old demo streams are dead (confirmed via a real CONTENT_ERROR:
        // "AVURLAsset failed to load variants" / "Something is wrong with the network" — Akamai retired
        // that HD network years ago). Apple's own bipbop gear1 stream has no variant playlist (a single
        // rendition only), so it's a real single-rendition source rather than an ABR ladder with one rung.
        ("VOD (single rendition)", "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8"),
        // cdn3.viblast.com's demo live stream is dead (no response at all), and the next candidate tried —
        // Akamai's cph-p2p-msl.akamaized.net test stream — turned out to be a half-dead trap: its master
        // manifest still returns 200, but the variant playlist it points to 404s server-side (confirmed via
        // curl), which is exactly what THEOplayer's real "AVURLAsset failed to load variants" error was
        // reporting. Unified Streaming's own public demo live stream is the replacement — confirmed via
        // curl that both the master manifest AND its actual variant sub-manifests resolve.
        ("Live", "https://demo.unified-streaming.com/k8s/live/scte35.isml/.m3u8"),
        ("Broken URL (expect ERROR)", "https://example.invalid/does-not-exist.m3u8"),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildUI()
        // Force Auto Layout to resolve playerContainer's real frame before attaching THEOplayer's
        // internal render view — addAsSubview(of:) sizes itself off the container's frame at call time,
        // and at viewDidLoad that frame is still CGRect.zero (constraints haven't run yet), which produces
        // a 0x0 video surface: audio/events keep working since they don't depend on view size, but nothing
        // ever renders.
        view.layoutIfNeeded()
        setupPlayer()
    }

    deinit {
        removeAllListeners()
    }

    // MARK: - UI construction

    private func buildUI() {
        let sourceButtonsStack = UIStackView()
        sourceButtonsStack.axis = .horizontal
        sourceButtonsStack.distribution = .fillEqually
        sourceButtonsStack.spacing = 4
        for (index, source) in testSources.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(source.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 11)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            button.tag = index
            button.addTarget(self, action: #selector(sourceButtonTapped(_:)), for: .touchUpInside)
            sourceButtonsStack.addArrangedSubview(button)
        }

        playerContainer.backgroundColor = .black

        let transportBar = UIStackView()
        transportBar.axis = .horizontal
        transportBar.distribution = .fillEqually
        transportBar.spacing = 4

        let playPauseButton = UIButton(type: .system)
        playPauseButton.setTitle("Play/Pause", for: .normal)
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)

        let seekBackButton = UIButton(type: .system)
        seekBackButton.setTitle("« 10s", for: .normal)
        seekBackButton.addTarget(self, action: #selector(seekBack), for: .touchUpInside)

        let seekForwardButton = UIButton(type: .system)
        seekForwardButton.setTitle("10s »", for: .normal)
        seekForwardButton.addTarget(self, action: #selector(seekForward), for: .touchUpInside)

        let muteButton = UIButton(type: .system)
        muteButton.setTitle("Mute", for: .normal)
        muteButton.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)

        let rateButton = UIButton(type: .system)
        rateButton.setTitle("Rate 1.0x", for: .normal)
        rateButton.addTarget(self, action: #selector(cycleRate(_:)), for: .touchUpInside)
        self.rateButton = rateButton

        [seekBackButton, playPauseButton, seekForwardButton, muteButton, rateButton].forEach {
            transportBar.addArrangedSubview($0)
        }

        let attributeStack = UIStackView()
        attributeStack.axis = .vertical
        attributeStack.spacing = 2
        [currentTimeLabel, durationLabel, rateLabel, mutedLabel, renditionLabel, droppedFramesLabel, renderedFpsLabel].forEach {
            $0.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            attributeStack.addArrangedSubview($0)
        }
        resetAttributeLabels()

        let rootStack = UIStackView(arrangedSubviews: [sourceButtonsStack, playerContainer, transportBar, attributeStack, eventLog])
        rootStack.axis = .vertical
        rootStack.spacing = 8
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            rootStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            rootStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            rootStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            playerContainer.heightAnchor.constraint(equalToConstant: 220),
        ])
    }

    private var rateButton: UIButton?

    private func resetAttributeLabels() {
        currentTimeLabel.text = "currentTime: –"
        durationLabel.text = "duration: –"
        rateLabel.text = "playbackRate: –"
        mutedLabel.text = "muted: –"
        renditionLabel.text = "rendition: –"
        droppedFramesLabel.text = "droppedVideoFrames: –"
        renderedFpsLabel.text = "renderedFramerate: –"
    }

    // MARK: - Player setup

    private func setupPlayer() {
        // License is expected to be picked up automatically from the `THEOplayerLicense` Info.plist key
        // (see Info.plist — placeholder until the real key is supplied).
        //
        // `addAsSubview(of:)` does NOT size itself off the parent view automatically — it inserts an
        // internal wrapper view at whatever frame THEOplayer's own `frame` property currently holds
        // (CGRect.zero by default), and that wrapper has no autoresizing mask relative to its new
        // superview. Confirmed live via lldb view-hierarchy dump: the wrapper (and the AVPlayerLayer
        // nested inside it) stayed 0x0 even after playerContainer itself was correctly laid out, which is
        // why sound/events worked but nothing ever rendered. THEOplayer exposes `frame`/`bounds`/
        // `autoresizingMask` directly (confirmed against the real interface) specifically so the caller
        // can drive this — set frame explicitly and give it a flexible mask so it tracks playerContainer's
        // size going forward (e.g. rotation).
        let player = THEOplayer(with: playerContainer.bounds)
        player.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        player.addAsSubview(of: playerContainer)
        self.theoplayer = player

        registerEventListeners(on: player)
        eventLog.log("THEOplayer initialized (version: \(THEOplayer.version))")
    }

    // MARK: - Event wiring — mirrors the CDD's §10 event mapping table

    private func registerEventListeners(on player: THEOplayer) {
        addListener(player.addEventListener(type: PlayerEventTypes.PLAY) { [weak self] _ in
            self?.eventLog.log("PLAY")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.PLAYING) { [weak self] _ in
            self?.eventLog.log("PLAYING")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.PAUSE) { [weak self] _ in
            self?.eventLog.log("PAUSE")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.SEEKING) { [weak self] _ in
            self?.eventLog.log("SEEKING")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.SEEKED) { [weak self] _ in
            self?.eventLog.log("SEEKED")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.WAITING) { [weak self] _ in
            self?.eventLog.log("WAITING (buffering)")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.ENDED) { [weak self] _ in
            self?.eventLog.log("ENDED")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.SOURCE_CHANGE) { [weak self] _ in
            self?.eventLog.log("SOURCE_CHANGE")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.ERROR) { [weak self] event in
            // Deliberately log everything we can pull off the error, since the exact shape of
            // `errorObject` (code/category/cause) vs. the plain `error` string is one of the CDD's open
            // items (§21 item that this app exists partly to help answer).
            var detail = "ERROR: \(event.error)"
            if let obj = event.errorObject {
                detail += " | code=\(obj.code) category=\(obj.category) name=\(obj.name) message=\(obj.message)"
                if let cause = obj.cause {
                    detail += " | cause: \(cause.name) — \(cause.message)"
                }
            }
            self?.eventLog.log(detail)
        })
        addListener(player.addEventListener(type: PlayerEventTypes.RATE_CHANGE) { [weak self] _ in
            self?.eventLog.log("RATE_CHANGE -> \(player.playbackRate)")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.VOLUME_CHANGE) { [weak self] _ in
            self?.eventLog.log("VOLUME_CHANGE (muted=\(player.muted))")
        })
        addListener(player.addEventListener(type: PlayerEventTypes.TIME_UPDATE) { [weak self] _ in
            self?.refreshAttributePanel()
        })

        // Rendition change lives on the active video track, not the player itself — see CDD §10.
        // VideoTrackList is not Array-like (confirmed against the real interface: count + get(_:)/subscript,
        // no `.first`).
        if let videoTrack = Self.firstVideoTrack(of: player) {
            addListener(videoTrack.addEventListener(type: MediaTrackEventTypes.ACTIVE_QUALITY_CHANGED) { [weak self] _ in
                self?.eventLog.log("ACTIVE_QUALITY_CHANGED")
                self?.refreshAttributePanel()
            })
        } else {
            // videoTracks is likely empty until a source is loaded — re-attempt once SOURCE_CHANGE fires.
            addListener(player.addEventListener(type: PlayerEventTypes.SOURCE_CHANGE) { [weak self] _ in
                guard let self, let player = self.theoplayer, let videoTrack = Self.firstVideoTrack(of: player) else { return }
                self.addListener(videoTrack.addEventListener(type: MediaTrackEventTypes.ACTIVE_QUALITY_CHANGED) { [weak self] _ in
                    self?.eventLog.log("ACTIVE_QUALITY_CHANGED")
                    self?.refreshAttributePanel()
                })
            })
        }
    }

    private static func firstVideoTrack(of player: THEOplayer) -> (any MediaTrack)? {
        // VideoTrackList doesn't narrow get(_:)'s return type below MediaTrackList's own — confirmed
        // against the real interface, it stays `any MediaTrack` even on a VideoTrackList.
        player.videoTracks.count > 0 ? player.videoTracks.get(0) : nil
    }

    private func addListener(_ token: Any) {
        listeners.append(token)
    }

    private func removeAllListeners() {
        // Symmetric teardown per listener type would need the exact `removeEventListener(type:listener:)`
        // call per event; since this harness's lifetime == the app's lifetime, relying on `theoplayer`
        // deallocating is acceptable here — flagging this rather than silently pretending it's done
        // properly, since the real tracker MUST do this correctly (see CDD's "store it to remove it" note).
        listeners.removeAll()
    }

    // MARK: - Attribute panel — mirrors the CDD's §11 attribute mapping table

    private func refreshAttributePanel() {
        guard let player = theoplayer else { return }
        currentTimeLabel.text = "currentTime: \(player.currentTime)"
        durationLabel.text = "duration: \(String(describing: player.duration))" // open item: does this report +Infinity for the Live source?
        rateLabel.text = "playbackRate: \(player.playbackRate)"
        mutedLabel.text = "muted: \(player.muted)"
        renditionLabel.text = "rendition: \(player.videoWidth)x\(player.videoHeight)"
        // `metrics: Any?` is deprecated in this SDK version in favor of `playerMetrics: Metrics` (confirmed
        // against the real compiled interface — a concrete, version-specific finding worth folding back
        // into the CDD, since earlier doc research assumed `metrics` was the name to use).
        droppedFramesLabel.text = "droppedVideoFrames: \(player.playerMetrics.droppedVideoFrames)"
        renderedFpsLabel.text = "renderedFramerate: \(player.playerMetrics.renderedFramerate)"
    }

    // MARK: - Actions

    @objc private func sourceButtonTapped(_ sender: UIButton) {
        let source = testSources[sender.tag]
        eventLog.log("Loading source: \(source.title) — \(source.url)")
        resetAttributeLabels()
        guard let player = theoplayer else { return }
        // `type:` is required (confirmed against the real interface, no default) — all four test sources
        // here are HLS.
        player.source = SourceDescription(source: TypedSource(src: source.url, type: "application/x-mpegurl"))
        player.play()
    }

    @objc private func togglePlayPause() {
        guard let player = theoplayer else { return }
        if player.paused {
            player.play()
        } else {
            player.pause()
        }
    }

    @objc private func seekBack() {
        guard let player = theoplayer else { return }
        player.currentTime = max(0, player.currentTime - 10)
    }

    @objc private func seekForward() {
        guard let player = theoplayer else { return }
        player.currentTime += 10
    }

    @objc private func toggleMute() {
        guard let player = theoplayer else { return }
        player.muted = !player.muted
    }

    @objc private func cycleRate(_ sender: UIButton) {
        guard let player = theoplayer else { return }
        rateIndex = (rateIndex + 1) % rateSteps.count
        let newRate = rateSteps[rateIndex]
        player.playbackRate = Double(newRate)
        sender.setTitle("Rate \(newRate)x", for: .normal)
    }
}
