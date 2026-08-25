//
//  NRTrackerTHEOplayer.swift
//  NRTHEOplayerTracker
//
//  Content tracker for THEOplayer (Dolby OptiView Player).
//
//  Written in Swift because THEOplayer's iOS event API (PlayerEventTypes, addEventListener) is built on
//  Swift generics, which cannot bridge to Objective-C under any circumstance — confirmed against the
//  real generated THEOplayerSDK-Swift.h. `@objc(NRTrackerTHEOplayer)` pins this class's Objective-C
//  runtime name so NRVAVideo.m's existing NSClassFromString(@"NRTrackerTHEOplayer") dispatch finds it
//  without any change to that dispatch code — verified end-to-end with a spike before this was written
//  (see Test/iOS/CoreTests/CoreTests/{NRTrackerTHEOplayerSpike.swift, SpikeHarness.m}).
//
import Foundation
import NewRelicVideoCore
import THEOplayerSDK

// Not `final` — the test convention this repo already uses (Test1-7.swift's TestContentTracker
// pattern) subclasses the tracker under test to intercept preSendAction:attributes: as a spy; the
// tests branch does the same for this class.
@objc(NRTrackerTHEOplayer)
public class NRTrackerTHEOplayer: NRVideoTracker {

    // Weak, matching NRTrackerAVPlayer's own playerInstance — the host app owns the player, the tracker
    // only observes it. A strong reference here would keep the entire THEOplayer instance (and its
    // internal view hierarchy) alive for as long as this tracker stays registered, if a host app ever
    // dropped its own player reference without also calling dispose()/releaseTracker.
    weak var player: THEOplayer?
    var listeners: [Any] = []
    private var qualityChangeListener: Any?

    // Defensive, matching NRTrackerAVPlayer's own dealloc: tears down listeners even if the host app
    // released the tracker without calling dispose(). unregisterListeners() is idempotent (confirmed via
    // Test11 calling it directly, and NRTracker's base implementation is a no-op), so this is safe even
    // when dispose() already ran.
    deinit {
        unregisterListeners()
    }

    // Cached QoE snapshot — getRenditionWidth/Height/Bitrate below read these directly, since
    // sendRenditionChange() takes no arguments and NRVideoTracker.getAttributes: reads the current
    // getter values at event-assembly time (confirmed by reading NRVideoTracker.m). Reset on
    // SOURCE_CHANGE so a new source doesn't inherit the previous one's last-known rendition.
    var lastRenditionWidth: Int = 0
    var lastRenditionHeight: Int = 0
    var lastRenditionBandwidth: Int = 0

    public override func setPlayer(_ player: Any) {
        super.setPlayer(player)
        self.player = player as? THEOplayer
        registerListeners()
    }

    public override func registerListeners() {
        super.registerListeners()
        guard let player else { return }

        listeners.append(player.addEventListener(type: PlayerEventTypes.SOURCE_CHANGE) { [weak self] _ in
            self?.handleSourceChange()
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.PLAY) { [weak self] _ in
            self?.handlePlay()
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.PLAYING) { [weak self] _ in
            self?.handlePlaying()
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.PAUSE) { [weak self] _ in
            self?.handlePause()
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.WAITING) { [weak self] _ in
            self?.handleWaiting()
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.SEEKING) { [weak self] _ in
            self?.handleSeeking()
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.SEEKED) { [weak self] _ in
            self?.handleSeeked()
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.ENDED) { [weak self] _ in
            self?.handleEnded()
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.ERROR) { [weak self] event in
            self?.handleError(event)
        })
        listeners.append(player.addEventListener(type: PlayerEventTypes.RATE_CHANGE) { [weak self] _ in
            self?.handleRateChange()
        })

        attachQualityChangeListenerIfNeeded()
    }

    public override func unregisterListeners() {
        super.unregisterListeners()
        listeners.removeAll()
        qualityChangeListener = nil
    }

    // MARK: - QoE (rendition/bitrate/dropped-frames)
    //
    // ACTIVE_QUALITY_CHANGED lives on the active video track, not the player itself (CDD §6.3), and
    // it carries no payload — the handler re-reads MediaTrack.activeQuality after it fires. The video
    // track list is empty until a source has loaded *and its manifest has parsed* — confirmed via real
    // playback + diagnostic logging that videoTracks.count is still 0 at the exact moment SOURCE_CHANGE
    // fires, so the attach attempt in handleSourceChange() below reliably never succeeds. Without a
    // retry, the real listener would never attach for the entire session — every genuine mid-playback
    // ABR switch would go completely undetected, not just the initial pick (handled separately by the
    // proactive read in handleActiveQualityChanged()). handlePlaying() retries the attach, since real
    // frames rendering guarantees tracks are populated by then (confirmed: the fallback read there
    // already relies on this same guarantee).

    private func firstVideoTrack() -> (any MediaTrack)? {
        guard let player, player.videoTracks.count > 0 else { return nil }
        return player.videoTracks.get(0)
    }

    private func attachQualityChangeListenerIfNeeded() {
        guard qualityChangeListener == nil, let track = firstVideoTrack() else { return }
        let listener = track.addEventListener(type: MediaTrackEventTypes.ACTIVE_QUALITY_CHANGED) { [weak self] _ in
            self?.handleActiveQualityChanged()
        }
        qualityChangeListener = listener
        listeners.append(listener)
    }

    func handleActiveQualityChanged() {
        let droppedFrames = player?.playerMetrics.droppedVideoFrames
        if let track = firstVideoTrack(), let quality = track.activeQuality as? VideoQuality {
            handleActiveQualityChanged(width: quality.width, height: quality.height, bandwidth: quality.bandwidth, droppedFrames: droppedFrames)
        } else if let player, player.videoWidth > 0, player.videoHeight > 0 {
            // Confirmed against real playback: a true single-rendition HLS source (a plain media playlist,
            // no master/variant playlist) never populates a video track's activeQuality — there's no ABR
            // ladder for THEOplayer to describe — so the branch above never fires even once, and rendition
            // data would silently stay 0 for the entire session. Fall back to videoWidth/videoHeight (the
            // actual decoded frame size, confirmed non-zero here even when activeQuality is nil) so
            // dimensions are still reported; bandwidth has no equivalent fallback (there's no encoded-rate
            // signal without a quality descriptor), so it's left at its last cached value.
            handleActiveQualityChanged(width: player.videoWidth, height: player.videoHeight, bandwidth: lastRenditionBandwidth, droppedFrames: droppedFrames)
        }
    }

    // Split from handleActiveQualityChanged() so the tests branch can drive the actual shift-direction
    // math and attribute/getter caching with synthetic data — real playback with a real multi-rendition
    // stream isn't available in an automated test (needs a real license + real network).
    func handleActiveQualityChanged(width: Int, height: Int, bandwidth: Int, droppedFrames: Int?) {
        let previousArea = lastRenditionWidth * lastRenditionHeight
        let newArea = width * height
        let shift = newArea >= previousArea ? "up" : "down"

        lastRenditionWidth = width
        lastRenditionHeight = height
        lastRenditionBandwidth = bandwidth

        setAttribute("renditionChangeShift", value: shift as NSString)
        if let droppedFrames {
            setAttribute("droppedVideoFrames", value: NSNumber(value: droppedFrames))
        }
        sendRenditionChange()
    }

    // MARK: - QoE attribute getters (CDD §6.4)

    public override func getRenditionWidth() -> NSNumber {
        NSNumber(value: lastRenditionWidth)
    }

    public override func getRenditionHeight() -> NSNumber {
        NSNumber(value: lastRenditionHeight)
    }

    public override func getBitrate() -> NSNumber {
        NSNumber(value: lastRenditionBandwidth)
    }

    public override func getRenditionBitrate() -> NSNumber {
        NSNumber(value: lastRenditionBandwidth)
    }

    public override func getFps() -> NSNumber {
        // Measured, not encoded — unlike Android, which reads the encoded target framerate off
        // VideoQuality.getFrameRate(). iOS has no confirmed encoded-framerate field; playerMetrics's
        // renderedFramerate is the actual measured rendered fps instead (CDD §6.4).
        NSNumber(value: player?.playerMetrics.renderedFramerate ?? 0)
    }

    // MARK: - Event handlers
    //
    // Each handler is a small, directly-callable method (not just an inline closure body) so the
    // tests branch can drive these exact code paths without needing a real THEOplayer instance —
    // every condition here mirrors the CDD's §6.3 event-mapping table. `send*` on NRVideoTracker
    // already internally guards via NRTrackerState's `go*` methods (confirmed by reading
    // NRVideoTracker.m), so no separate state-machine bookkeeping is needed here.

    func handleSourceChange() {
        if state().isRequested() {
            sendEnd()
        }
        lastRenditionWidth = 0
        lastRenditionHeight = 0
        lastRenditionBandwidth = 0
        qualityChangeListener = nil
        sendRequest()
        attachQualityChangeListenerIfNeeded()
    }

    func handlePlay() {
        if state().isPaused() {
            sendResume()
        }
    }

    func handlePlaying() {
        if !state().isStarted() {
            // Retry the attach here — confirmed via real playback + diagnostic logging that
            // handleSourceChange()'s attempt never succeeds (videoTracks.count is still 0 at that exact
            // moment), so without this retry the real listener never attaches for the whole session and
            // every subsequent genuine ABR switch goes undetected. By PLAYING, real frames are
            // rendering, which guarantees tracks are populated.
            attachQualityChangeListenerIfNeeded()
            // By the time real frames render, THEOplayer must have resolved an initial rendition.
            // Confirmed empirically: without this, a real playback session that never switches
            // renditions reports contentRenditionWidth/Height/Bitrate as 0 for its entire duration. Read
            // it BEFORE sendStart() (not after) so CONTENT_START's own attributes carry the real values
            // too, instead of just every event from CONTENT_RENDITION_CHANGE onward — confirmed via real
            // NRDB/log data that with sendStart() first, CONTENT_START alone still reported all zeros
            // even though every later event was already correct.
            handleActiveQualityChanged()
            sendStart()
        }
        if state().isBuffering() {
            sendBufferEnd()
        }
        if state().isSeeking() {
            sendSeekEnd()
        }
    }

    func handlePause() {
        sendPause()
    }

    func handleWaiting() {
        guard let player else { return }
        handleWaiting(isSeeking: player.seeking)
    }

    // Split from handleWaiting() so the tests branch can exercise the actual guard condition — THEOplayer
    // fires WAITING for both real rebuffers and seeks (CDD §6.3) — without needing a real player.
    func handleWaiting(isSeeking: Bool) {
        guard !isSeeking else { return }
        sendBufferStart()
    }

    func handleSeeking() {
        sendSeekStart()
    }

    func handleSeeked() {
        if state().isBuffering() {
            sendBufferEnd()
        }
        sendSeekEnd()
    }

    func handleEnded() {
        sendEnd()
    }

    func handleError(_ event: ErrorEvent) {
        let handler = NRTheoErrorHandler(error: event.errorObject, fallbackMessage: event.error)
        sendError(handler.asNSError)
    }

    func handleRateChange() {
        // No first-class getter for playback rate exists on NRVideoTracker today (confirmed against
        // the real header — same gap as dropped frames), so it's carried as a custom attribute rather
        // than an override NewRelicVideoCore would never call.
        guard let player else { return }
        setAttribute("contentPlayrate", value: NSNumber(value: player.playbackRate))
    }

    // MARK: - Remaining attribute getters (CDD §6.4)

    public override func getPlayerName() -> String {
        "theoplayer"
    }

    public override func getPlayerVersion() -> String {
        THEOplayer.version
    }

    // Named nrGetSrc(), not getSrc() — see the NS_SWIFT_NAME comment on NRVideoTracker.h's
    // declaration for why. Still overrides the same `getSrc` Objective-C selector.
    public override func nrGetSrc() -> String {
        player?.src ?? ""
    }

    public override func getDuration() -> NSNumber {
        // THEOplayer reports .infinity for live content (confirmed against the real interface — this is
        // the same live-duration signal getIsLive() below checks for). Mirrors NRTrackerAVPlayer's own
        // isnan(duration) guard (NRTrackerAVPlayer.m's getDuration): NSJSONSerialization rejects
        // non-finite NSNumber values outright, and the harvest pipeline drops the *entire* batch on a
        // serialization failure (NRVAOptimizedHttpClient.m), not just the one bad attribute — so an
        // un-guarded live-stream duration would permanently fail to harvest for the whole session, every
        // single retry, since the same non-finite value recurs on every event.
        guard let duration = player?.duration, duration.isFinite else { return 0 }
        return NSNumber(value: duration * 1000)
    }

    public override func getPlayhead() -> NSNumber {
        NSNumber(value: (player?.currentTime ?? 0) * 1000)
    }

    public override func getIsLive() -> NSNumber {
        NSNumber(value: player?.duration == .infinity)
    }

    public override func getIsMuted() -> NSNumber {
        NSNumber(value: player?.muted ?? false)
    }

    public override func getTitle() -> String {
        player?.source?.metadata?.title ?? ""
    }
}
