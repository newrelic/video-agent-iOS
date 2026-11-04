# IMA DAI staging verification

How to verify Google IMA Dynamic Ad Insertion tracking end to end in New Relic staging, using the `Examples/iOS/SimplePlayerWithDAI` app. Nothing in this repo contains a token or account ID; fill in the placeholders below.

## Setup

1. In `Examples/iOS/SimplePlayerWithDAI`, create `Config.local.xcconfig` (gitignored):

   ```
   NR_APP_TOKEN = <staging mobile app token>
   ```

   Point the agent at the staging collector with the configuration your environment uses (not set in the sample).
2. `pod install`, open `SimplePlayerWithDAI.xcworkspace`, run on a device or simulator.
3. Tag the run: add the environment variable `NR_TEST_RUN=dai-<YYYY-MM-DD>` to the Run scheme. Every event then carries `testRun`, and the sample adds `scenario` (`vod`, `live`, `bad-key`). The queries below filter on both.
4. Replace `<ACCOUNT_ID>` and `<TEST_RUN>` below. Events can take a few minutes to appear (harvest cycle is 60 s in the sample).

## Scenarios

| # | Scenario | How | Expected |
|---|----------|-----|----------|
| 1 | Preroll + midroll VOD, to the end | "Play VOD", watch fully | Per ad: `AD_REQUEST`, `AD_START`, 3x `AD_QUARTILE` (1, 2, 3), `AD_END`. Per break: one `AD_BREAK_START`, one `AD_BREAK_END`. `adPosition` pre then mid |
| 2 | Skip a skippable ad | Skip an ad that shows a skip button | `AD_END` with `adSkipped = 1`, no quartiles after the skip. The next ad has `adSkipped = 0` |
| 3 | Seek over a midroll | Scrub past a midroll (IMA snaps back) | Break and ads still pair; no ad without an `AD_END` after the stream ends |
| 4 | Background and foreground mid-ad | Home button during an ad, return | Ad completes; no duplicate `AD_START` for the same ad |
| 5 | Stream request failure | "Bad asset key" | `AD_ERROR` in `VideoErrorAction`, `errorDomain = com.newrelic.video.IMA`, `adStreamType = DAI`, non-null `errorCode`/`errorMessage` |
| 6 | Network drop during an ad | Airplane mode mid-ad, restore | Either `AD_ERROR` or recovery; record which. No crash |
| 7 | Live stream ad break | "Play Live", wait for a break | Same sequence as scenario 1; `adPosition` is not trusted for live, see open item below |

Open item to check on device: `adPosition` for DAI is derived from the pod's `timeOffset` (0 = `pre`, negative = `post`, otherwise `mid`). Confirm it for VOD postroll and for live breaks.

## NRQL checks

All queries: `SINCE 1 day ago` unless noted.

**A. Action sequence for one view (run per scenario, pick a `viewId` from query B).**

```sql
FROM VideoAdAction SELECT timestamp, actionName, adQuartile, adBreakId, adPosition, adSkipped
WHERE testRun = '<TEST_RUN>' AND viewId = '<VIEW_ID>' ORDER BY timestamp LIMIT MAX
```

Pass: matches the scenario table, in order.

**B. View ids and counts per scenario.**

```sql
FROM VideoAdAction SELECT count(*), uniqueCount(adBreakId) AS breaks
WHERE testRun = '<TEST_RUN>' FACET scenario, viewId LIMIT MAX
```

**C. Per-scenario pass/fail counts.**

```sql
FROM VideoAdAction SELECT
  filter(count(*), WHERE actionName = 'AD_REQUEST') AS requests,
  filter(count(*), WHERE actionName = 'AD_START') AS starts,
  filter(count(*), WHERE actionName = 'AD_END') AS ends,
  filter(count(*), WHERE actionName = 'AD_BREAK_START') AS breakStarts,
  filter(count(*), WHERE actionName = 'AD_BREAK_END') AS breakEnds
WHERE testRun = '<TEST_RUN>' FACET scenario
```

Pass: `requests = starts = ends` (skipped ads still send `AD_END`) and `breakStarts = breakEnds` for completed runs.

**D. Stream type is DAI on every event.**

```sql
FROM VideoAdAction SELECT count(*) WHERE testRun = '<TEST_RUN>' FACET adStreamType
```

Pass: a single row, `DAI`. Any `null` row is a failure.

**E. Ad metadata is populated on `AD_START`.**

```sql
FROM VideoAdAction SELECT
  percentage(count(*), WHERE adDuration IS NOT NULL) AS duration,
  percentage(count(*), WHERE adTitle IS NOT NULL) AS title,
  percentage(count(*), WHERE adCreativeId IS NOT NULL) AS creativeId,
  percentage(count(*), WHERE adPosition IS NOT NULL) AS position
WHERE testRun = '<TEST_RUN>' AND actionName = 'AD_START'
```

Pass: 100 for each. `adTitle` can be legitimately empty for some creatives; check any miss by hand.

**F. Quartile coverage.**

```sql
FROM VideoAdAction SELECT count(*) WHERE testRun = '<TEST_RUN>' AND actionName = 'AD_QUARTILE' FACET adQuartile
```

Pass: values 1, 2, 3 with similar counts. Fewer than `AD_START` is expected for skipped or abandoned ads.

**G. Skipped ads.**

```sql
FROM VideoAdAction SELECT count(*) WHERE testRun = '<TEST_RUN>' AND actionName = 'AD_END' FACET adSkipped
```

**H. Ad errors.**

```sql
FROM VideoErrorAction SELECT count(*) WHERE testRun = '<TEST_RUN>' AND actionName = 'AD_ERROR'
FACET scenario, errorDomain, errorCode, errorMessage, adStreamType
```

Pass for scenario 5: one or more rows with `com.newrelic.video.IMA` and `DAI`.

**I. Break pairing.**

```sql
FROM (FROM VideoAdAction SELECT
        filter(count(*), WHERE actionName = 'AD_BREAK_START') AS s,
        filter(count(*), WHERE actionName = 'AD_BREAK_END') AS e
      WHERE testRun = '<TEST_RUN>' FACET adBreakId LIMIT MAX)
SELECT count(*) AS breaks, filter(count(*), WHERE s != e) AS unpaired
```

Pass: `unpaired = 0` for runs watched to the end. A break abandoned mid-way is legitimately unpaired.

**J. CSAI regression (needs a CSAI sample run, e.g. `SimplePlayerWithAds`).**

```sql
FROM VideoAdAction SELECT count(*) WHERE actionName IN ('AD_START', 'AD_END', 'AD_QUARTILE')
FACET if(adStreamType IS NULL, 'CSAI', adStreamType), actionName SINCE 1 day ago
```

Pass: CSAI rows have no `adStreamType`; DAI rows have `DAI`.

## Dashboard

`dai-verification-dashboard.json` in this folder is a NerdGraph `dashboardCreate` input. It uses account id `0` and the test run `dai-YYYY-MM-DD` as placeholders. Replace both, then create it.

```bash
sed -e 's/"accountIds": \[0\]/"accountIds": [<ACCOUNT_ID>]/' \
    -e 's/dai-YYYY-MM-DD/<TEST_RUN>/' \
    Test/staging/dai-verification-dashboard.json > /tmp/dai-dashboard.json
```

Then in the NerdGraph explorer, run `mutation ($accountId: Int!, $dashboard: DashboardInput!) { dashboardCreate(accountId: $accountId, dashboard: $dashboard) { entityResult { guid name } errors { description } } }` with `accountId` set and `dashboard` set to the contents of `/tmp/dai-dashboard.json`.

Widgets: scenario results table (query C), ad funnel (request, start, Q1, Q2, Q3, end), error breakdown (H), break pairing (I), and a CSAI vs DAI comparison (J).
