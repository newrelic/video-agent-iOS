# v4.1.4 Release Test Checklist

**Branch:** `test/v4.1.4`
**PR under test:** `fix/tracker-safety-followups` (#208) → `release/25MAY2026`
**Pod under test:** `4.1.2` (before fix) → local path / `4.1.4` (after fix)
**Sample app:** `Examples/iOS/SimplePlayerWithAds`

**Status legend:** `⬜ Pending` · `✅ Pass` · `❌ Fail` · `⚠️ Partial` · `⏭️ Skipped`

> Update this file and commit every time a section is confirmed.
> Each commit = one test section completed. History = full test record.

---

## Crash Regressions
*Confirmed crashes on 4.1.2. Must NOT crash after fix.*
*Root cause: content-only tracker (adEnabled:NO) stores NSNull internally for missing ad tracker. NSNull is truthy so `if (pair.second)` passes, then a message is sent to NSNull → unrecognized selector crash.*

| # | Scenario | Trigger | Status (4.1.2) | Status (fixed) | Notes |
|---|----------|---------|----------------|----------------|-------|
| CR-1 | Content-only tracker → `setUserId:` | Tap CR-1 | ❌ Crash | ✅ Pass | Confirmed crash on 4.1.2, confirmed fix on fix/tracker-safety-followups |
| CR-2 | Content-only tracker → `setGlobalAttribute:value:` | Tap CR-2 | ❌ Crash | ✅ Pass | Confirmed crash on 4.1.2, confirmed fix on fix/tracker-safety-followups |
| CR-3 | Content-only tracker → `setGlobalAttribute:value:action:` | Tap CR-3 | ❌ Crash | ✅ Pass | Confirmed crash on 4.1.2, confirmed fix on fix/tracker-safety-followups |

---

## Data Quality Fixes
*No crash on 4.1.2 — NR iOS Agent underneath handles serialization and coerces types to strings.*
*Our fix improves correctness: NSDate → epoch seconds (queryable), NSURL → dropped (not leaked into events), nil → silent drop.*

| # | Scenario | Before fix (4.1.2) | After fix | Status | Notes |
|---|----------|--------------------|-----------|--------|-------|
| DQ-1 | `setAttribute:` with `NSDate` | Stored as string description `"2026-06-04 16:35:52 +0000"` | Stored as epoch `1780591129.665822` | ✅ | Confirmed before on 4.1.2, confirmed after on fix/tracker-safety-followups |
| DQ-2 | `setAttribute:` with `NSURL` | Stored as string `"https://example.com/stream.m3u8"` | Key absent — dropped with error log | ✅ | Confirmed before on 4.1.2, confirmed after on fix/tracker-safety-followups |
| DQ-3 | `setAttribute:` with `NSDictionary` containing `NSDate` | Inner date as string `"2026-06-04..."` | Inner date as epoch `1780591129.666651` | ✅ | Confirmed before on 4.1.2, confirmed after on fix/tracker-safety-followups |
| DQ-4 | `setAttribute:` with `nil` | Silent no-op — key absent | Silent no-op — key absent | ✅ | Same behaviour both builds — explicit early return after fix |

---

## Record Events
*Does NOT go through the NSNull pair path — uses `contentTracker:` which returns nil safely.*
*nil trackerId path iterates `trackerIds` and calls `contentTracker:` — safe, no NSNull exposure.*
*No crash expected on 4.1.2 or after fix. Testing for correct event dispatch and data quality.*

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| REC-1 | `recordCustomEvent` on specific tracker | Event fires enriched with tracker attributes | ✅ | Fired at runtime after CONTENT_START — contentPlayhead/timeSinceStarted populated |
| REC-2 | `recordCustomEvent` nil trackerId (all trackers) | Event fires on every active tracker | ✅ | APP_FOREGROUND broadcast confirmed in log |
| REC-3 | `recordCustomEvent` with `NSDate` in attributes | Date stored as string on both builds — bypasses setAttribute: sanitization | ✅ | Confirmed same on both builds — known gap, future fix needed |
| REC-4 | `recordEvent:` raw dispatch | Raw event fires without tracker enrichment | ✅ | RAW_CUSTOM_EVENT confirmed in log |

---

## QoE Harvest

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| QoE-1 | Content-only playback, no ads | `startupTime` = `timeSinceRequested`; QoE event fires on harvest cycle | ⬜ | |
| QoE-2 | Content + pre-roll ads | `startupTime` = `timeSinceRequested - totalPreRollAdTime`; ad time correctly subtracted | ⬜ | |
| QoE-3 | Pre-roll ad time > `timeSinceRequested` | `startupTime` clamped to `0`, never negative | ⬜ | |
| QoE-4 | Multiple rebuffer events mid-play | First buffer skipped; subsequent buffers accumulate in `totalRebufferingTime` and `rebufferingRatio` | ⬜ | |
| QoE-5 | Error before `CONTENT_START` | `hadStartupError = true` in QoE event | ⬜ | |
| QoE-6 | Error after `CONTENT_START` | `hadPlaybackError = true` in QoE event | ⬜ | |
| QoE-7 | QoE event in NRDB | `QOE_AGGREGATE` event visible after harvest cycle completes | ⬜ | |

---

## Ad Data Propagation

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| AD-1 | Single pre-roll ad | `AD_REQUEST` → `AD_START` → `AD_END` fire with correct attributes (`adTitle`, `adDuration`, `adPlayhead`) | ⬜ | |
| AD-2 | Multiple pre-roll ads back-to-back | Each ad fires its own events; `totalPreRollAdTime` accumulates across all ads | ⬜ | |
| AD-3 | Post-roll ad | Does **not** affect `startupTime` | ⬜ | |
| AD-4 | Mid-roll ad | Same as AD-3 | ⬜ | |
| AD-5 | Ad quartile events | `AD_QUARTILE` fires at 25 / 50 / 75 / 100% | ⬜ | |
| AD-6 | Ad error | `VideoAdErrorAction` fires; content error flags unaffected | ⬜ | |

---

## Multiple Trackers + Global Attributes

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| MT-1 | Two content trackers registered simultaneously | Both produce independent events with different `trackerId` | ⬜ | |
| MT-2 | `setGlobalAttribute` with two active trackers | Attribute appears on events from both trackers | ⬜ | |
| MT-3 | `setUserId` with content + ad tracker pair | `enduser.id` appears on both `VideoAction` and `VideoAdAction` events | ⬜ | |
| MT-4 | `setAttribute` on tracker A only | Attribute does **not** appear on tracker B events | ⬜ | |
| MT-5 | `setGlobalAttribute` with content + ad pair | Attribute appears on both `VideoAction` and `VideoAdAction` events | ⬜ | |
| MT-6 | Release one tracker, then `setGlobalAttribute` | Only remaining tracker receives attribute; no crash | ⬜ | |

---

## Sanity — Core Event Lifecycle

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| SAN-1 | Basic play | `CONTENT_REQUEST` → `CONTENT_START` in order | ⬜ | |
| SAN-2 | Pause / resume | `CONTENT_PAUSE` → `CONTENT_RESUME` | ⬜ | |
| SAN-3 | Seek | `CONTENT_SEEK_START` → `CONTENT_SEEK_END` | ✅ | Fixed in fix/tracker-safety-followups: NRTrackerAVPlayer now auto-detects seek via timeControlStatus; NRVAVideo exposes sendSeekStart:/sendSeekEnd: for custom players |
| SAN-4 | Buffering mid-play | `CONTENT_BUFFER_START` → `CONTENT_BUFFER_END` | ⬜ | |
| SAN-5 | Playback error | `CONTENT_ERROR` fires with error details | ⬜ | |
| SAN-6 | End of video | `CONTENT_END` fires; tracker reusable for next video | ⬜ | |
| SAN-7 | Heartbeat | `CONTENT_HEARTBEAT` fires on configured interval | ⬜ | |
| SAN-8 | Release tracker | No further events after `releaseTracker:`; no crash | ⬜ | |

---

## tvOS — Sanity

*Run on Apple TV simulator. `harvestCycle=180s`, `liveHarvest=10s`, `batchSize=128KB` — verify auto-detected.*

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| TV-SAN-1 | `isTV` auto-detected | `NRVADeviceInformation.isTV = YES`; TV config applied automatically | ⬜ | |
| TV-SAN-2 | Basic play on Apple TV simulator | `CONTENT_REQUEST` → `CONTENT_START` fires | ⬜ | |
| TV-SAN-3 | Pause / resume | `CONTENT_PAUSE` → `CONTENT_RESUME` | ⬜ | |
| TV-SAN-4 | Buffering mid-play | `CONTENT_BUFFER_START` → `CONTENT_BUFFER_END` | ⬜ | |
| TV-SAN-5 | Heartbeat on TV harvest cycle | Fires on 180s cycle | ⬜ | |
| TV-SAN-6 | Live stream on tvOS | Live harvest cycle is 10s | ⬜ | |
| TV-SAN-7 | `CONTENT_END` | Fires correctly; no residual state | ⬜ | |
| TV-SAN-8 | Unit test suite on tvOS | `xcodebuild test -scheme "tvOS NewRelicVideoCore"` passes 78/78 | ⬜ | |

---

## tvOS — PR-Specific Crash Regressions

*Same NSNull crash path as CR-1/2/3 but must be verified on tvOS simulator explicitly — Bell/DeltaTre hit this on tvOS.*

| # | Scenario | Status (4.1.2) | Status (fixed) | Notes |
|---|----------|----------------|----------------|-------|
| TV-CR-1 | tvOS content-only tracker → `setUserId:` | ⬜ | ⬜ | |
| TV-CR-2 | tvOS content-only tracker → `setGlobalAttribute:value:` | ⬜ | ⬜ | |
| TV-CR-3 | tvOS content-only tracker → `setGlobalAttribute:value:action:` | ⬜ | ⬜ | |
| TV-CR-4 | tvOS `setAttribute:` with `NSDate` | ⬜ | ⬜ | Expect data quality fix, not crash |
| TV-CR-5 | tvOS `setAttribute:` with `NSURL` | ⬜ | ⬜ | Expect data quality fix, not crash |
| TV-CR-6 | tvOS `setGlobalAttribute` across two trackers | ⬜ | ⬜ | |

---

## tvOS — QoE on Apple TV

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| TV-QoE-1 | Content-only playback | `startupTime` correct; QoE fires after 180s harvest | ⬜ | |
| TV-QoE-2 | Content + pre-roll ads | `startupTime` = `timeSinceRequested - totalPreRollAdTime` | ⬜ | |
| TV-QoE-3 | Rebuffering on tvOS | `totalRebufferingTime` and `rebufferingRatio` correct | ⬜ | |
| TV-QoE-4 | `QOE_AGGREGATE` in NRDB | Appears with correct `trackerName` identifying tvOS | ⬜ | |

---

## Testing Priority

1. **CR-1 → CR-3** — Confirmed crashes on 4.1.2 ❌. Now switch to local pod and confirm PASS ⬜
2. **TV-CR-1 → TV-CR-3** — Same on tvOS simulator
3. **DQ-1 → DQ-4** — Confirm data quality improvement after fix (date as epoch, NSURL dropped)
4. **REC-1 → REC-4** — Confirm correct event dispatch
5. **QoE-2, QoE-3** — Pre-roll startup time calculation
6. **TV-SAN-8** — tvOS unit test suite via new shared scheme
7. **AD-1 → AD-6** — Full ad data propagation
8. **MT-1 → MT-6** — Multi-tracker + global attributes
9. **SAN-1 → SAN-8, TV-SAN-1 → TV-SAN-7** — Full sanity sweep on both platforms
