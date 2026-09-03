## [4.4.0](https://github.com/newrelic/video-agent-iOS/compare/v4.3.0...v4.4.0) (2026-09-03)

### Features

* add Swift Package Manager support ([e8114d8](https://github.com/newrelic/video-agent-iOS/commit/e8114d8580d56dea1b9b6ebe5b64cb48a2940482))
* **mediatailor:** public iOS config + NRAdConfig ad-tracker selection ([593bdd2](https://github.com/newrelic/video-agent-iOS/commit/593bdd2a1bf54e06f00de769bacb46bf41f925f2))
* **mediatailor:** self-sufficient ad tracking auto-activation ([9cd80a9](https://github.com/newrelic/video-agent-iOS/commit/9cd80a98134a67f24c354db5aadda82fef487cff))
* **mediatailor:** wire adSegmentPrefix/trackingUrl overrides into sample app ([95aa226](https://github.com/newrelic/video-agent-iOS/commit/95aa226c850f4313e0b9ba1bdd9018753920679d))
* **release:** wire NRMediaTailorTracker into build-xcframeworks.sh ([a09ae95](https://github.com/newrelic/video-agent-iOS/commit/a09ae953e182f54c20c0ad9a64410a2245399aac))
* **release:** wire NRMediaTailorTracker.podspec into ios-publish.yml validate + publish lists ([0385982](https://github.com/newrelic/video-agent-iOS/commit/03859828d15c54057840e8c3ac82059a3393ff96))
* **release:** wire NRMediaTailorTracker.podspec into ios-release.yml version-bump list ([f1be621](https://github.com/newrelic/video-agent-iOS/commit/f1be621103ce6d86305a267efb0f1de42945d9cc))
* wire NRMediaTailorTracker into SPM support ([342d861](https://github.com/newrelic/video-agent-iOS/commit/342d861c9616d79b5403016f266b8f595baf6872)), closes [#217](https://github.com/newrelic/video-agent-iOS/issues/217)

### Bug Fixes

* correct Package.swift comment ([ca47055](https://github.com/newrelic/video-agent-iOS/commit/ca470555acfca4b146f4edd2874e7cb5920871f0))
* **ios-publish:** make retries survive a partial failure ([ff54204](https://github.com/newrelic/video-agent-iOS/commit/ff54204d741db29dbe70cba5abd430267372663a))
* **NRMediaTailorTracker:** bump podspec + getTrackerVersion to 4.3.0 ([825be02](https://github.com/newrelic/video-agent-iOS/commit/825be02306bfa16526452c3d0cb2801417ffe405))
* **NRMediaTailorTracker:** override getTrackerVersion to return @"4.2.0" ([cb74073](https://github.com/newrelic/video-agent-iOS/commit/cb74073ccae4d9512725fd7855407b8b5f553c13))

## [4.3.0](https://github.com/newrelic/video-agent-iOS/compare/v4.2.0...v4.3.0) (2026-08-04)

### New features

* add JP region support ([2acc442](https://github.com/newrelic/video-agent-iOS/commit/2acc4429e3dd71b0b3fec37d999c4f4e01309176))
* Add new QOE attributes ([7b06033](https://github.com/newrelic/video-agent-iOS/commit/7b0603316a802bb366b9507bcbba41da432ed502))

### Bug fixes

* Ad-break time inflating totalPauseTime ([7c41112](https://github.com/newrelic/video-agent-iOS/commit/7c411125965d4ad1e37ef56aa297c7151a7c70c2))
* correct rendition KPIs across views in multi-video sessions ([bd7d6c9](https://github.com/newrelic/video-agent-iOS/commit/bd7d6c9f745434e832945e89ac8a2682eab252d0))
* Multiple Device UUID per viewId ([790c7e6](https://github.com/newrelic/video-agent-iOS/commit/790c7e68fa010099c160922384f56c1aec9e1c4d))

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
