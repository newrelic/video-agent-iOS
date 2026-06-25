## Unreleased

### Features

* **NRMediaTailorTracker** — new module. AWS MediaTailor server-side ad-insertion tracker for AVPlayer, in parity with `NRIMATracker`. Detects ads inside an HLS stream, polls the MediaTailor `/v1/tracking/<sessionId>` endpoint with proper `NextToken` round-trip (fixing the Android module's biggest deviation from the AWS contract), and emits `AD_BREAK_START` / `AD_REQUEST` / `AD_START` / `AD_QUARTILE` / `AD_END` / `AD_BREAK_END` / `AD_SKIP` / `AD_PAUSE` / `AD_RESUME` / `AD_ERROR`. iOS 12 + tvOS 12. HLS-only in v1; ships with an `MTManifestParser` protocol seam so customers using third-party DASH players (THEOplayer, Bitmovin, Shaka) can plug in their own parser.

  Fixes 14 of 15 documented bugs from the Android reference module: NextToken round-trip (B1), wall-clock cache-bust dropped (A1), `creativeId` used as primary identity (B2), GET-not-POST for Android parity (B3), manifest-marker primary tracking-URL discovery (B4), no-fill empty avails handled correctly (A2), pod-mismatch keeps manifest pod geometry (A3), live de-dupe via compound `(availId, adProgramDateTime)` key (A4), configurable playhead poll interval (A5), oversize-pod clamp-not-reject (A6), silent avail-start fallback with warning (A8), `relativeToAdStartMs` tracking-event semantics (B5), new `AD_ERROR` event vocabulary (B6), live `adProgramDateTime` / `availProgramDateTime` always emitted (B7). DASH multi-period detection (A7) deferred behind the adapter seam.

## [4.2.0](https://github.com/newrelic/video-agent-iOS/compare/v4.1.4...v4.2.0) (2026-06-10)

### Features

* enable QoE by default with interval multiplier 2 ([bb8f02f](https://github.com/newrelic/video-agent-iOS/commit/bb8f02fb238c76880f93346ddb7136d6a899717a))

## [4.1.4](https://github.com/newrelic/video-agent-iOS/compare/v4.1.3...v4.1.4) (2026-06-05)

### Bug Fixes

* expose sendSeekStart/sendSeekEnd on NRVAVideo; auto-detect seek in AVPlayerTracker ([34493b4](https://github.com/newrelic/video-agent-iOS/commit/34493b4999968ff4e726c3f3ba3d266ff6d3f4e2))
* NRTrackerPair must not leak NSNull sentinel to callers ([82ef94f](https://github.com/newrelic/video-agent-iOS/commit/82ef94fcbd4f432dedf2dabbc523a19fe8134d34))
* partial container sanitization, nil guard, and dead code removal ([6aac79f](https://github.com/newrelic/video-agent-iOS/commit/6aac79f7ef52d648a4f3c0636ed97d5b01edc314))
* read totalPreRollAdTime from CONTENT_START attributes ([d565378](https://github.com/newrelic/video-agent-iOS/commit/d565378286af59e2d7109566bc0081ea31872246))
* sanitize attribute values at setAttribute storage boundary ([7d07298](https://github.com/newrelic/video-agent-iOS/commit/7d072980d1e6b4a85339c864ea8245194a38f688))

## [4.1.3](https://github.com/newrelic/video-agent-iOS/compare/v4.1.2...v4.1.3) (2026-05-20)

### Bug Fixes

* republish umbrella to CocoaPods trunk via 4.1.3 ([a1c154b](https://github.com/newrelic/video-agent-iOS/commit/a1c154ba5d369464a76445a290f0c979f777f5d4))

## [4.1.2](https://github.com/newrelic/video-agent-iOS/compare/v4.1.2-rc.1...v4.1.2) (2026-05-20)

## [4.1.1](https://github.com/newrelic/video-agent-iOS/compare/v4.1.0...v4.1.1) (2026-04-22)

### Bug Fixes

* Add obfuscation rules support ([2734ca7](https://github.com/newrelic/video-agent-iOS/commit/2734ca737f05f342b401ea89eeb29fe93ae122d3))
* New Bitrate Metrics Added ([61cc6d1](https://github.com/newrelic/video-agent-iOS/commit/61cc6d1bbf15417f0545a66300fc0806eb2254a1))

## [4.1.0](https://github.com/newrelic/video-agent-iOS/compare/v4.0.5...v4.1.0) (2026-03-31)

### Features

* add QoE aggregation system and fix critical   timing/playtime bugs ([aa761f8](https://github.com/newrelic/video-agent-iOS/commit/aa761f802b0d5b228685c105a7d85cb37fc51df5))

### Bug Fixes

* improve error handling and retry logic in CocoaPods publish workflow ([00e4e46](https://github.com/newrelic/video-agent-iOS/commit/00e4e462fd68e738288d92d20f239ac9b01639b3))

## [4.0.5](https://github.com/newrelic/video-agent-iOS/compare/v4.0.4...v4.0.5) (2026-02-17)

### Bug Fixes

* sync develop branch tracker fixes ([34b8ae7](https://github.com/newrelic/video-agent-iOS/commit/34b8ae7fef35607a6d8501853a6a5a272e29dd19))
## [4.0.4](https://github.com/newrelic/video-agent-iOS/compare/v4.0.3...v4.0.4) (2026-02-02)

### Bug Fixes

* staging token issue ([04956d5](https://github.com/newrelic/video-agent-iOS/commit/04956d543e50ca1e170b8454e7cd40f486fd67f9))
## [4.0.3](https://github.com/newrelic/video-agent-iOS/compare/v4.0.2...v4.0.3) (2026-01-20)

### Bug Fixes

* Remove pricing context in readme ([4b64afb](https://github.com/newrelic/video-agent-iOS/commit/4b64afb4d6076866e3bcc5236172052ec189f607))
## [4.0.2](https://github.com/newrelic/video-agent-iOS/compare/v4.0.1...v4.0.2) (2026-01-12)

### Bug Fixes

* attribute naming ([0b90490](https://github.com/newrelic/video-agent-iOS/commit/0b90490e4512b6e66509d0906b46cfdbedc21959))
