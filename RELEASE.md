# Release Process

This document describes the automated release process for the NewRelic Video Agent iOS SDK.

## Overview

The release process is fully automated through GitHub Actions workflows:

1. **Version Bump PR** (`ios-release.yml`) - Automatically creates release PRs
2. **Publish to CocoaPods** (`ios-publish.yml`) - Publishes pods when PR is merged

## Quick Start

### Triggering a Release

1. **Make commits following Conventional Commits format:**

   ```bash
   # Feature (minor version bump: 4.1.0 → 4.2.0)
   git commit -m "feat: add new video quality metrics"
   
   # Bug fix (patch version bump: 4.1.0 → 4.1.1)
   git commit -m "fix: resolve memory leak in tracker"
   
   # Breaking change (major version bump: 4.1.0 → 5.0.0)
   git commit -m "feat!: redesign tracking API
   
   BREAKING CHANGE: Tracker initialization method has changed"
   ```

2. **Push to master:**

   ```bash
   git push origin master
   ```

3. **Review the auto-generated PR:**
   - Workflow creates a PR with version bump and changelog
   - Review the changes, changelog, and version number
   - Request reviews if needed

4. **Merge the PR:**
   - Merging triggers automatic publication to CocoaPods
   - GitHub Release is created automatically
   - Release branch is cleaned up automatically

## Detailed Workflow

### Phase 1: Version Bump PR (ios-release.yml)

**Trigger:** Push to `master` branch

**What it does:**

```
1. Extract current version from podspec (e.g., 4.1.0)
2. Run semantic-release in dry-run mode to calculate next version
3. Check if version bump is needed (based on commits since last release)
4. If version bump needed:
   a. Create release branch (release/4.2.0)
   b. Update all podspec versions
   c. Run semantic-release to generate CHANGELOG.md and create git tag
   d. Commit changes to release branch
   e. Push branch and create PR
5. If no version bump needed: Skip (no qualifying commits)
```

**PR Contents:**
- Updated podspec versions
- Updated/generated CHANGELOG.md
- Git tag (created by semantic-release)
- Commit message: `chore(release): update podspec versions to X.X.X`

**Branch:** `release/X.X.X`

**Example PR Title:** `chore(release): 4.2.0`

### Phase 2: Publish to CocoaPods (ios-publish.yml)

**Trigger:** Release PR merged to `master`

**What it does:**

```
1. Extract version from podspec
2. Validate all podspecs
3. Publish NewRelicVideoAgent to CocoaPods
4. Wait for CocoaPods indexing (~5 minutes)
5. Publish NRAVPlayerTracker (depends on NewRelicVideoAgent)
6. Publish NRIMATracker (depends on NewRelicVideoAgent)
7. Create GitHub Release (uses existing tag from semantic-release)
8. Delete release branch
```

**Idempotent:** Can be safely re-run if any step fails

**Outputs:**
- Published pods on CocoaPods
- GitHub Release with installation instructions
- Cleaned up release branch

## Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/) with semantic-release:

| Type | Version Bump | Example |
|------|-------------|---------|
| `feat:` | Minor (4.1.0 → 4.2.0) | `feat: add picture-in-picture support` |
| `fix:` | Patch (4.1.0 → 4.1.1) | `fix: correct bitrate calculation` |
| `feat!:` or `BREAKING CHANGE:` | Major (4.1.0 → 5.0.0) | `feat!: redesign API` |
| `chore:`, `docs:`, `style:`, `refactor:`, `test:`, `ci:` | None | No release |

**Examples:**

```bash
# Feature - Minor bump
git commit -m "feat: add support for AVQueuePlayer"

# Multiple features
git commit -m "feat: add HLS quality tracking

- Track adaptive bitrate changes
- Monitor buffer health
- Report quality metrics"

# Bug fix - Patch bump
git commit -m "fix: prevent crash when player is deallocated"

# Breaking change - Major bump
git commit -m "feat!: change tracker initialization

BREAKING CHANGE: Tracker now requires configuration object instead of individual parameters.

Migration:
- Old: Tracker(url: url, key: key)
- New: Tracker(config: Config(url: url, key: key))"

# No release
git commit -m "docs: update README with new examples"
git commit -m "chore: update dependencies"
```

## Troubleshooting

### CocoaPods Indexing Timeout

**Symptom:** The publish workflow times out waiting for `NewRelicVideoAgent` to be indexed (~10 minutes).

**Why this happens:**
- CocoaPods indexing typically takes 5-10 minutes
- Network issues or high traffic can delay indexing
- The workflow waits up to 10 minutes, then continues anyway

**What to do:**

1. **Wait 5-10 more minutes** for CocoaPods indexing to complete

2. **Re-run the workflow:**
   ```bash
   # Via GitHub CLI
   gh run rerun <RUN_ID>
   
   # Or manually in GitHub Actions UI:
   # Actions → Failed workflow run → Re-run failed jobs
   ```

3. **The workflow is idempotent**, so it will:
   - Skip `NewRelicVideoAgent` (already published)
   - Skip indexing wait (already published)
   - Publish `NRAVPlayerTracker` and `NRIMATracker` (now that dependency is indexed)
   - Complete remaining steps

**Manual verification:**
```bash
# Check if the pod is indexed
pod search NewRelicVideoAgent
# Look for your version number in the results
```

### Workflow Idempotency

The publish workflow (`ios-publish.yml`) is **fully idempotent** and safe to re-run at any time.

**What this means:**

| Step | Re-run Behavior |
|------|----------------|
| **Publish NewRelicVideoAgent** | Checks if already published → skips if found |
| **Wait for indexing** | Skips if pod already published |
| **Publish NRAVPlayerTracker** | Checks if already published → skips if found |
| **Publish NRIMATracker** | Checks if already published → skips if found |
| **Create GitHub Release** | Updates existing release (action is idempotent) |
| **Delete release branch** | Checks if exists → skips if already deleted |

**Example scenarios:**

```bash
# Scenario 1: Partial failure during pod publication
First run:  NewRelicVideoAgent published
            Indexing timeout (10 minutes)
            NRAVPlayerTracker failed (dependency not indexed)
            
Re-run:     NewRelicVideoAgent skipped (already published)
            Indexing wait skipped (already published)
            NRAVPlayerTracker published (dependency now indexed)
            NRIMATracker published
            GitHub Release created

# Scenario 2: Network failure during GitHub Release
First run:  All pods published successfully
            GitHub Release creation failed (network error)
            
Re-run:     All pods skipped (already published)
            GitHub Release created

# Scenario 3: Accidental re-run of completed workflow
Re-run:     All steps skipped (already complete)
            Workflow succeeds with "already done" messages
```

### Release Branch Already Exists

**Symptom:** Release workflow shows "Release branch already exists" and stops.

**Why this happens:**
- A previous release attempt created the branch but didn't complete
- The PR was closed without merging

**What to do:**

1. **Check if there's an open PR:**
   ```bash
   gh pr list --head release/<VERSION>
   ```

2. **If PR exists:**
   - Review and merge it to complete the release
   - Or close it if you want to restart:
     ```bash
     gh pr close <PR_NUMBER> --delete-branch
     ```

3. **If no PR exists, delete the branch:**
   ```bash
   git push origin --delete release/<VERSION>
   ```

4. **Re-run the workflow:**
   ```bash
   git commit --allow-empty -m "feat: retry release after branch cleanup"
   git push origin master
   ```

### Tag Already Exists Error

**Symptom:** Workflow fails with `fatal: tag 'vX.X.X' already exists`

**Why this happens:**
- A previous workflow run created the tag but didn't complete
- Manual tag creation

**What to do:**

**Option 1: Use existing tag (recommended)**
```bash
# Check if tag is correct
git show v4.2.0

# If correct, just re-run the workflow
# The idempotent checks will handle it
gh run rerun <RUN_ID>
```

**Option 2: Delete and recreate tag**
```bash
# Only if the tag is incorrect or points to wrong commit
git tag -d v4.2.0
git push origin :refs/tags/v4.2.0

# Re-run workflow
gh run rerun <RUN_ID>
```

### No Release Triggered

**Symptom:** Push to master but no release PR is created.

**Why this happens:**
- No commits with release types (`feat:`, `fix:`, `feat!:`)
- All commits use non-release types (`chore:`, `docs:`, `style:`, etc.)
- Commits contain `[skip ci]` in message

**What to do:**

1. **Check recent commits:**
   ```bash
   git log --oneline -10
   ```

2. **Verify commit types** - ensure you have `feat:` or `fix:`

3. **Check workflow logs:**
   ```bash
   gh run list --workflow=ios-release.yml --limit 5
   gh run view <RUN_ID> --log
   ```

4. **Make a release-worthy commit:**
   ```bash
   git commit --allow-empty -m "feat: trigger release workflow"
   git push origin master
   ```

### Failed Release Retry

To retry a failed release without creating duplicates:

```bash
# 1. Check what's already published
pod search NewRelicVideoAgent | grep <VERSION>
pod search NRAVPlayerTracker | grep <VERSION>
pod search NRIMATracker | grep <VERSION>

# 2. Check if tag exists
git ls-remote --tags origin | grep v<VERSION>

# 3. Check if GitHub Release exists
gh release view v<VERSION>

# 4. Re-run the workflow
# The workflow will automatically skip completed steps
gh run rerun <RUN_ID>

# Or trigger manually if needed
gh workflow run ios-publish.yml
```

### Manual Cleanup (Emergency Only)

**⚠️ Use only as a last resort** - the idempotent workflow should handle most scenarios.

```bash
# Delete git tag
git tag -d v<VERSION>
git push origin :refs/tags/v<VERSION>

# Delete GitHub release
gh release delete v<VERSION> --yes

# Delete release branch
git push origin --delete release/<VERSION>

# Close and delete release PR
gh pr close <PR_NUMBER> --delete-branch
```

**Important:** Published CocoaPods versions **cannot be deleted**. If you need to fix issues with a published version, you must:
1. Fix the issues
2. Create a new patch version (e.g., 4.1.1)
3. Publish the new version

## Manual Release (Fallback)

If automated workflows fail, you can publish manually:

### 1. Update Versions

```bash
# Update version in all podspecs
VERSION="4.2.0"

# NewRelicVideoAgent.podspec
sed -i '' "s/s.version[[:space:]]*=.*/s.version = '${VERSION}'/" NewRelicVideoAgent.podspec

# NRAVPlayerTracker.podspec
sed -i '' "s/s.version[[:space:]]*=.*/s.version = '${VERSION}'/" NRAVPlayerTracker.podspec

# NRIMATracker.podspec
sed -i '' "s/s.version[[:space:]]*=.*/s.version = '${VERSION}'/" NRIMATracker.podspec
```

### 2. Generate Changelog

```bash
# Run semantic-release locally
npx semantic-release --no-ci
```

### 3. Commit and Tag

```bash
git add .
git commit -m "chore(release): ${VERSION}"
git tag "v${VERSION}"
git push origin master
git push origin "v${VERSION}"
```

### 4. Publish to CocoaPods

```bash
# Authenticate (one-time)
pod trunk register YOUR_EMAIL 'YOUR_NAME'

# Publish each pod
pod trunk push NewRelicVideoAgent.podspec --allow-warnings

# Wait for indexing (~5 minutes)
sleep 300

# Publish dependent pods
pod trunk push NRAVPlayerTracker.podspec --allow-warnings
pod trunk push NRIMATracker.podspec --allow-warnings
```

### 5. Create GitHub Release

```bash
gh release create "v${VERSION}" \
  --title "Release v${VERSION}" \
  --notes "See CHANGELOG.md for details"
```

## Testing Releases

### Test in a Development Project

Create a test project with a Podfile:

```ruby
source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '12.0'

target 'TestApp' do
  use_frameworks!
  
  # Test the new release
  pod 'NewRelicVideoAgent', '~> 4.2.0'
  pod 'NRAVPlayerTracker', '~> 4.2.0'
  pod 'NRIMATracker', '~> 4.2.0'
end
```

```bash
pod install
```

### Verify Installation

```bash
# Check installed version
pod list | grep NewRelicVideoAgent

# Search CocoaPods
pod search NewRelicVideoAgent

# View pod info
pod spec cat NewRelicVideoAgent
```

## Best Practices

### Commit Messages

**Good:**
```bash
feat: add adaptive bitrate tracking
fix: correct timestamp calculation in IMA tracker
feat!: redesign tracker API for better testability
```

**Bad:**
```bash
updated code
fixed bug
changes
WIP
```

### Pull Request Reviews

- Review generated CHANGELOG.md for accuracy
- Verify version bump is correct (major/minor/patch)
- Check that podspec dependencies are correct
- Ensure all CI checks pass before merging

### Version Strategy

- **Patch (X.X.1):** Bug fixes, minor improvements
- **Minor (X.1.0):** New features, backward compatible
- **Major (1.0.0):** Breaking changes, API redesign

### Release Timing

- Avoid releases on Fridays (in case issues arise)
- Allow time for CocoaPods indexing (5-10 minutes)
- Monitor the first few hours after release for issues

## Monitoring

### Check Workflow Status

```bash
# List recent workflow runs
gh run list --workflow=ios-release.yml --limit 10
gh run list --workflow=ios-publish.yml --limit 10

# View specific run
gh run view <RUN_ID>

# Watch live
gh run watch
```

### Check Published Versions

```bash
# Check CocoaPods
pod search NewRelicVideoAgent
pod trunk info NewRelicVideoAgent

# Check GitHub Releases
gh release list

# Check tags
git tag -l
```

## FAQs

**Q: Can I skip the automatic release process?**  
A: Yes, include `[skip ci]` in your commit message to skip workflows.

**Q: Can I trigger a release for a specific version?**  
A: Use the manual workflow dispatch in GitHub Actions UI and specify the version.

**Q: What if I need to unpublish a version?**  
A: CocoaPods doesn't support unpublishing. You must publish a new version with fixes.

**Q: How long does the full release take?**  
A: ~15-20 minutes total:
- Version bump PR: ~2 minutes
- CocoaPods indexing: ~5-10 minutes
- Dependent pod publication: ~3-5 minutes

**Q: Can I release multiple versions in parallel?**  
A: No, wait for one release to complete before starting another.

**Q: What if semantic-release doesn't create a tag?**  
A: This shouldn't happen, but check the workflow logs. Ensure you have qualifying commits (feat/fix).

## Support

- **Workflow issues:** Check GitHub Actions logs
- **CocoaPods issues:** Check [CocoaPods Status](https://status.cocoapods.org/)
- **Semantic-release issues:** Review [semantic-release docs](https://semantic-release.gitbook.io/)

---

**Last Updated:** December 2025