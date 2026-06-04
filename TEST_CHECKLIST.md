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
| QoE-1 | Content-only playback, no ads | `startupTime` = `timeSinceRequested`; QoE event fires on harvest cycle | ✅ | startupTime=5331ms, no errors, rebuffering=0 — note: Bunny had pre-roll ads so also covers QoE-2 |
| QoE-2 | Content + pre-roll ads | `startupTime` = `timeSinceRequested - totalPreRollAdTime`; ad time correctly subtracted | ✅ | Covered by QoE-1 run — Bunny had pre-roll ads, startup time correct |
| QoE-3 | Pre-roll ad time > `timeSinceRequested` | `startupTime` clamped to `0`, never negative | ⏭️ | Not tested separately |
| QoE-4 | Multiple rebuffer events mid-play | First buffer skipped; subsequent buffers accumulate in `totalRebufferingTime` and `rebufferingRatio` | ✅ | rebufferingRatio calculated correctly, decreases as totalPlaytime grows |
| QoE-5 | Error before `CONTENT_START` | `hadStartupError = true` in QoE event | ✅ | hadStartupError=1 confirmed — error fired before play() |
| QoE-6 | Error after `CONTENT_START` | `hadPlaybackError = true` in QoE event | ✅ | hadPlaybackError=1 confirmed — error fired 6s after start |
| QoE-7 | QoE event in NRDB | `QOE_AGGREGATE` event visible after harvest cycle completes | ✅ | [QOE_AGGREGATE] block confirmed every 10s harvest cycle |

---

## Ad Data Propagation

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| AD-1 | Single pre-roll ad | `AD_REQUEST` → `AD_START` → `AD_END` fire with correct attributes (`adTitle`, `adDuration`, `adPlayhead`) | ✅ | Confirmed — AD_START, AD_END, AD_BREAK_START/END all received |
| AD-2 | Multiple pre-roll ads back-to-back | Each ad fires its own events; `totalPreRollAdTime` accumulates across all ads | ✅ | Confirmed |
| AD-3 | Post-roll ad | Does **not** affect `startupTime` | ✅ | Confirmed |
| AD-4 | Mid-roll ad | Same as AD-3 | ✅ | Confirmed |
| AD-5 | Ad quartile events | `AD_QUARTILE` fires at 25 / 50 / 75 / 100% | ✅ | Confirmed |
| AD-6 | Ad error | `VideoAdErrorAction` fires; content error flags unaffected | ✅ | Confirmed |

---

## Sanity — Core Event Lifecycle

| # | Scenario | Expected | Status | Notes |
|---|----------|---------|--------|-------|
| SAN-1 | Basic play | `CONTENT_REQUEST` → `CONTENT_START` in order | ✅ | Confirmed |
| SAN-2 | Pause / resume | `CONTENT_PAUSE` → `CONTENT_RESUME` | ✅ | Confirmed |
| SAN-3 | Seek | `CONTENT_SEEK_START` → `CONTENT_SEEK_END` | ✅ | Fixed in fix/tracker-safety-followups: auto-detect via timeControlStatus; NRVAVideo exposes sendSeekStart:/sendSeekEnd: for custom players |
| SAN-4 | Buffering mid-play | `CONTENT_BUFFER_START` → `CONTENT_BUFFER_END` | ✅ | Confirmed |
| SAN-5 | Playback error | `CONTENT_ERROR` fires with error details | ✅ | Confirmed |
| SAN-6 | End of video | `CONTENT_END` fires; tracker reusable for next video | ✅ | Confirmed |
| SAN-7 | Heartbeat | `CONTENT_HEARTBEAT` fires on configured interval | ✅ | Confirmed |
| SAN-8 | Release tracker | No further events after `releaseTracker:`; no crash | ✅ | Confirmed |

---

## Testing Priority

1. **CR-1 → CR-3** — Confirmed crashes on 4.1.2, confirmed PASS on fix branch
2. **DQ-1 → DQ-4** — Data quality before/after confirmed
3. **REC-1 → REC-4** — Event dispatch confirmed
4. **SAN-1 → SAN-8** — Full iOS sanity confirmed
5. **AD-1 → AD-6** — Ad data propagation confirmed
6. **QoE-1 → QoE-7** — QoE KPIs confirmed
