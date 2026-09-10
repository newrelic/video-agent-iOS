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
    // Teardown closures, not raw tokens — removeEventListener needs the original `type` alongside the
    // token addEventListener returns, and discarding the type (keeping only `[Any]` tokens, as this used
    // to) meant unregisterListeners() could only ever clear its own bookkeeping array, never actually
    // tell THEOplayer to stop invoking the closure. See addListener(on:type:handler:) below.
    var listeners: [() -> Void] = []
    private var qualityChangeListener: Any?
    // Separate from `listeners` (rather than just appended into it) so handleSourceChange() below can
    // tear down and re-attach *just* the per-track quality listener on a mid-session source change,
    // without touching the player-level listeners that stay registered for the tracker's whole lifetime.
    private var qualityChangeTeardown: (() -> Void)?

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

        addListener(on: player, type: PlayerEventTypes.SOURCE_CHANGE) { [weak self] _ in
            self?.handleSourceChange()
        }
        addListener(on: player, type: PlayerEventTypes.PLAY) { [weak self] _ in
            self?.handlePlay()
        }
        addListener(on: player, type: PlayerEventTypes.PLAYING) { [weak self] _ in
            self?.handlePlaying()
        }
        addListener(on: player, type: PlayerEventTypes.PAUSE) { [weak self] _ in
            self?.handlePause()
        }
        addListener(on: player, type: PlayerEventTypes.WAITING) { [weak self] _ in
            self?.handleWaiting()
        }
        addListener(on: player, type: PlayerEventTypes.SEEKING) { [weak self] _ in
            self?.handleSeeking()
        }
        addListener(on: player, type: PlayerEventTypes.SEEKED) { [weak self] _ in
            self?.handleSeeked()
        }
        addListener(on: player, type: PlayerEventTypes.ENDED) { [weak self] _ in
            self?.handleEnded()
        }
        addListener(on: player, type: PlayerEventTypes.ERROR) { [weak self] event in
            self?.handleError(event)
        }
        addListener(on: player, type: PlayerEventTypes.RATE_CHANGE) { [weak self] _ in
            self?.handleRateChange()
        }

        attachQualityChangeListenerIfNeeded()
    }

    public override func unregisterListeners() {
        super.unregisterListeners()
        listeners.forEach { $0() }
        listeners.removeAll()
        qualityChangeTeardown?()
        qualityChangeTeardown = nil
        qualityChangeListener = nil
    }

    // Registers a THEOplayer event listener and stores a matching teardown closure in `listeners`,
    // instead of just the opaque token addEventListener returns — removeEventListener needs both the
    // token and its original `type` (E is generic, and THEOplayer doesn't expose a type-erased removal),
    // so keeping only tokens meant unregisterListeners() below could never actually call
    // player.removeEventListener at all. [weak player] avoids extending the player's lifetime just to
    // tear down its own listener.
    private func addListener<E: EventProtocol>(on player: THEOplayer, type: EventType<E>, handler: @escaping (E) -> Void) {
        let token = player.addEventListener(type: type, listener: handler)
        listeners.append { [weak player] in player?.removeEventListener(type: type, listener: token) }
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
        let token = track.addEventListener(type: MediaTrackEventTypes.ACTIVE_QUALITY_CHANGED) { [weak self] _ in
            self?.handleActiveQualityChanged()
        }
        qualityChangeListener = token
        // MediaTrack (unlike THEOplayer itself) isn't passed into the shared addListener helper here —
        // removeEventListener needs `track`, not `player`, as the receiver. Track : AnyObject (confirmed
        // against the real THEOplayerSDK.swiftinterface), so [weak track] is valid the same way
        // [weak player] is above. Kept in qualityChangeTeardown, not appended to `listeners`, so
        // handleSourceChange() can detach just this one on a mid-session source change.
        qualityChangeTeardown = { [weak track] in track?.removeEventListener(type: MediaTrackEventTypes.ACTIVE_QUALITY_CHANGED, listener: token) }
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
        // Matches NRTrackerAVPlayer.m's checkRenditionChange: the very first rendition observation only
        // seeds the cache and does NOT call sendRenditionChange(). NRQoEAggregator.m's
        // handleStartWithAttributes: seeds its own "current rendition" from CONTENT_START's attributes
        // instead (its own comment explains checkRenditionChange does the same on Android/AVPlayer) —
        // so treating the initial pick here as a "shift" would double-count it, permanently inflating
        // totalSwitchUps by 1 on every single session (confirmed: sendRenditionChange() has no state
        // guard of its own, and handleRenditionChangeWithAttributes: unconditionally increments on any
        // shift="up"/"down", including one that fires before CONTENT_START).
        guard lastRenditionWidth > 0, lastRenditionHeight > 0 else {
            lastRenditionWidth = width
            lastRenditionHeight = height
            lastRenditionBandwidth = bandwidth
            return
        }

        let previousArea = lastRenditionWidth * lastRenditionHeight
        let newArea = width * height
        let shift = newArea >= previousArea ? "up" : "down"

        lastRenditionWidth = width
        lastRenditionHeight = height
        lastRenditionBandwidth = bandwidth

        // THEOplayer can emit ACTIVE_QUALITY_CHANGED again for the same resolution (confirmed possible
        // per real playback observation, not just theoretical). Only a real area change is a rendition
        // "shift" worth reporting — without this, sendRenditionChange() would fire (and
        // totalSwitchUps/totalSwitchDowns would increment) on every repeat callback for the same quality.
        guard newArea != previousArea else { return }

        // "shift", not "renditionChangeShift" — NRQoEAggregator.m's handleRenditionChangeWithAttributes:
        // reads attributes[@"shift"] to compute totalSwitchUps/totalSwitchDowns (confirmed by reading
        // NRTrackerAVPlayer.m's own getAttributes: override, which injects exactly this key, scoped to
        // just the CONTENT_RENDITION_CHANGE event). Scoped via forAction: for the same reason — a plain
        // setAttribute(key:value:) applies globally to every subsequent event, not just this one, which
        // is why the earlier version of this line leaked "renditionChangeShift" onto unrelated events
        // (PAUSE, ERROR, HEARTBEAT) in real NRDB data.
        setAttribute("shift", value: shift as NSString, forAction: "CONTENT_RENDITION_CHANGE")
        // Same leak "shift" used to have, same fix: scoped via forAction:, or this snapshot sticks
        // around as a stale value on every subsequent event (PAUSE, ERROR, HEARTBEAT, ...) instead of
        // just the CONTENT_RENDITION_CHANGE it was actually measured for.
        if let droppedFrames {
            setAttribute("droppedVideoFrames", value: NSNumber(value: droppedFrames), forAction: "CONTENT_RENDITION_CHANGE")
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

    // lastRenditionBandwidth is VideoQuality.bandwidth (confirmed against the real THEOplayerSDK
    // interface) — a manifest/ABR-ladder-advertised value, not a measured throughput. It genuinely
    // belongs on getRenditionBitrate() (the current rendition's bitrate) and getManifestBitrate() (the
    // manifest-advertised bitrate) — those are the same real number for an ABR stream. getBitrate() is
    // deliberately left unoverridden here (falling through to NRVideoTracker's own NSNull default,
    // same as getMeasuredBitrate()/getDownloadBitrate() below): its doc comment specifically means a
    // *measured* average, and iOS THEOplayer's public SDK has no measured-throughput signal at all
    // (confirmed against the real interface — Metrics only exposes droppedVideoFrames/renderedFramerate,
    // and the one bandwidth-shaped field beyond VideoQuality is gated behind @_spi(Core), not usable by
    // a normal consumer). Reporting the manifest value under contentBitrate's measured-throughput label
    // would be actively misleading, not just incomplete.
    public override func getRenditionBitrate() -> NSNumber {
        NSNumber(value: lastRenditionBandwidth)
    }

    public override func getManifestBitrate() -> NSNumber {
        NSNumber(value: lastRenditionBandwidth)
    }

    // getMeasuredBitrate() (-> contentSegmentDownloadBitrate) and getDownloadBitrate() (->
    // contentNetworkDownloadBitrate) are also deliberately left unoverridden — no real measured-
    // throughput or download-rate signal exists on iOS THEOplayer's public SDK to give them (same
    // platform-limitation class as contentNetworkDownloadBitrate being Android-only per the CDD).

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
        // Actually detach the previous source's track listener, not just forget our own token for it —
        // otherwise a mid-session source change left the old ACTIVE_QUALITY_CHANGED listener attached to
        // the old track forever (same underlying bug as unregisterListeners(), just triggered by a
        // source change instead of teardown).
        qualityChangeTeardown?()
        qualityChangeTeardown = nil
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
        // Scoped to CONTENT_ERROR only, same mechanism as CONTENT_RENDITION_CHANGE's "shift" — these
        // don't apply to any other event, and a plain setAttribute(key:value:) would otherwise leak them
        // onto every subsequent event regardless of type.
        if let category = handler.category {
            setAttribute("category", value: category as NSString, forAction: "CONTENT_ERROR")
        }
        if let cause = handler.cause {
            setAttribute("cause", value: cause as NSString, forAction: "CONTENT_ERROR")
        }
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
