# Release Process

This document describes the automated release process for the New Relic Video Agent iOS SDK using semantic-release and GitHub Actions.

## Overview

The release process is fully automated and consists of two workflows:

1. **Version Bump Workflow** - Analyzes commits, calculates next version, and creates a PR
2. **Publish Workflow** - Publishes to CocoaPods and creates a GitHub release

## Prerequisites

### 1. CocoaPods Setup

Ensure you have access to publish pods to CocoaPods trunk:

```bash
# Register with CocoaPods (one-time setup)
pod trunk register YOUR_EMAIL 'YOUR_NAME' --description='MacBook Pro'

# Verify registration
pod trunk me
```

### 2. GitHub Secrets Configuration

Add the following secret to your GitHub repository:

- **`COCOAPODS_TRUNK_TOKEN`**: Your CocoaPods trunk authentication token

To get your token:
```bash
# View your CocoaPods trunk token
cat ~/.netrc | grep -A 2 trunk.cocoapods.org
```

Or generate a new one:
```bash
pod trunk register YOUR_EMAIL 'YOUR_NAME' --description='GitHub Actions'
```

### 3. Install Dependencies

Install semantic-release and related packages:

```bash
npm install
```

## Conventional Commits

This project uses [Conventional Commits](https://www.conventionalcommits.org/) to determine version bumps:

### Commit Types

| Type | Description | Version Bump | Example |
|------|-------------|--------------|---------|
| `feat:` | New feature | Minor (0.1.0 → 0.2.0) | `feat: add video quality analytics` |
| `fix:` | Bug fix | Patch (0.1.0 → 0.1.1) | `fix: resolve memory leak in tracker` |
| `perf:` | Performance improvement | Patch (0.1.0 → 0.1.1) | `perf: optimize video event processing` |
| `BREAKING CHANGE:` | Breaking change | Major (0.1.0 → 1.0.0) | See below |
| `docs:` | Documentation | No release | `docs: update installation guide` |
| `chore:` | Maintenance | No release | `chore: update dependencies` |
| `refactor:` | Code refactoring | No release | `refactor: restructure tracker module` |
| `test:` | Tests | No release | `test: add unit tests for IMA tracker` |

### Breaking Changes

For major version bumps, include `BREAKING CHANGE:` in the commit body or footer:

```bash
git commit -m "feat!: redesign tracking API

BREAKING CHANGE: The tracking initialization method has been changed from initWithConfig: to configure:options:"
```

Or use the `!` syntax:
```bash
git commit -m "feat!: remove deprecated methods"
```

## Release Workflow

### Step 1: Development and Commits

Make changes and commit using conventional commit format:

```bash
# Feature commit
git commit -m "feat: add support for 4K video tracking"

# Bug fix commit
git commit -m "fix: correct timestamp calculation in playback events"

# Documentation update (no release)
git commit -m "docs: add troubleshooting section"

# Push to master
git push origin master
```

### Step 2: Automatic Version Bump PR

When you push to `master`, the **Version Bump Workflow** automatically:

1. Extracts current version from `NewRelicVideoAgent.podspec`
2. Analyzes commits since last release using semantic-release
3. Calculates next version based on conventional commits
4. Creates a new branch: `release/X.Y.Z`
5. Updates all podspec files with new version
6. Generates/updates `CHANGELOG.md`
7. Creates a Pull Request with:
   - Version change summary
   - List of updated files
   - Link to changelog

**Example PR Title**: `chore(release): 4.0.2`

### Step 3: Review and Merge

1. Review the version bump PR
2. Check the changes in podspec files
3. Review the generated changelog
4. Merge the PR to `master`

### Step 4: Automatic Publication

When the version bump PR is merged, the **Publish Workflow** automatically:

1. Validates all podspec files
2. Publishes `NewRelicVideoAgent` to CocoaPods
3. Waits for CocoaPods to index the core library (~5 minutes)
4. Publishes `NRAVPlayerTracker` (depends on NewRelicVideoAgent)
5. Publishes `NRIMATracker` (depends on NewRelicVideoAgent)
6. Creates a git tag with the version number
7. Creates a GitHub Release with installation instructions
8. Verifies all pods are published and searchable

## Workflows

### Version Bump Workflow (`.github/workflows/version-bump.yml`)

**Triggers:**
- Push to `master` branch
- Manual dispatch via GitHub UI

**Requirements:**
- Conventional commit messages
- At least one commit that triggers a version bump

**Output:**
- Pull Request with version updates
- Updated podspec files
- Generated/updated CHANGELOG.md

### Publish Workflow (`.github/workflows/publish-cocoapods.yml`)

**Triggers:**
- When version bump PR is merged (automatic)
- Manual dispatch via GitHub UI

**Requirements:**
- `COCOAPODS_TRUNK_TOKEN` secret configured
- Valid podspec files
- Merged version bump PR with `release` label

**Output:**
- Published CocoaPods pods
- Git tag (e.g., `4.0.2`)
- GitHub Release

## Manual Release

If you need to trigger a release manually:

### 1. Manual Version Bump

Go to **Actions** → **Version Bump PR** → **Run workflow**

### 2. Manual Publish

Go to **Actions** → **Publish to CocoaPods** → **Run workflow**

Optionally specify a version (otherwise it reads from podspec):
```
Version: 4.0.2
```

## Version Tag Format

This project uses **plain version numbers** without the "v" prefix:

- Correct: `4.0.2`, `4.1.0`, `5.0.0`
- Incorrect: `v4.0.2`, `v4.1.0`

## Skipping CI

To skip the workflow execution, include `[skip ci]` in your commit message:

```bash
git commit -m "docs: update README [skip ci]"
```

This is automatically added to release commits to prevent recursive workflow triggers.

## Pod Publishing Order

The pods are published in the following order to respect dependencies:

1. **NewRelicVideoAgent** (core library, no dependencies)
2. **NRAVPlayerTracker** (depends on NewRelicVideoAgent)
3. **NRIMATracker** (depends on NewRelicVideoAgent)

The workflow includes a 5-minute wait after publishing `NewRelicVideoAgent` to ensure CocoaPods has indexed it before publishing dependent pods.

## Version Sources

The version number comes from **podspec files**, specifically `NewRelicVideoAgent.podspec`:

```ruby
s.version          = '4.0.1'
```

This is the single source of truth. The workflow:
1. Reads current version from podspec
2. Calculates next version using semantic-release
3. Updates all podspec files
4. Creates git tag with the version number

## Troubleshooting

### No PR Created After Push

**Possible reasons:**
- No commits that trigger a version bump (e.g., only `docs:` or `chore:` commits)
- Commit message contains `[skip ci]`
- All commits are already included in a previous release

**Solution:**
Check the workflow logs in GitHub Actions to see semantic-release output.

### Publication Fails

**Possible reasons:**
- `COCOAPODS_TRUNK_TOKEN` not set or invalid
- Podspec validation errors
- Version already published to CocoaPods
- Network issues with CocoaPods trunk

**Solution:**
1. Verify token: `pod trunk me`
2. Validate podspecs locally: `pod lib lint *.podspec --allow-warnings`
3. Check CocoaPods status: https://status.cocoapods.org/

### Dependent Pods Fail to Publish

**Possible reason:**
- `NewRelicVideoAgent` not fully indexed by CocoaPods yet

**Solution:**
- Workflow waits 5 minutes automatically
- If it still fails, re-run the workflow after 10-15 minutes
- Or manually publish: `pod trunk push NRAVPlayerTracker.podspec --allow-warnings`

### Tag Already Exists

**Possible reason:**
- Manual tag creation or previous failed release

**Solution:**
- Delete the tag: `git push --delete origin 4.0.2`
- Re-run the publish workflow

## Testing

### Test Semantic Release Locally

```bash
# Dry run to see what version would be released
npm run semantic-release:dry-run
```

### Test Podspec Validation

```bash
# Validate individual podspecs
pod lib lint NewRelicVideoAgent.podspec --allow-warnings
pod lib lint NRAVPlayerTracker.podspec --allow-warnings
pod lib lint NRIMATracker.podspec --allow-warnings

# Validate all at once
pod lib lint *.podspec --allow-warnings
```

## Configuration Files

### `.releaserc.js`

Semantic-release configuration:
- Defines branches to release from (`master`)
- Configures commit analyzer rules
- Sets up changelog generation
- Defines podspec update commands
- Configures git and GitHub plugins

### `package.json`

Contains semantic-release dependencies and scripts.

## Examples

### Example 1: Feature Release (Minor Version)

```bash
# Make changes
git commit -m "feat: add picture-in-picture tracking support"
git push origin master

# Workflow creates PR: "chore(release): 4.1.0"
# Review and merge PR
# Workflow publishes version 4.1.0 to CocoaPods
```

### Example 2: Bug Fix Release (Patch Version)

```bash
# Fix a bug
git commit -m "fix: resolve crash on background playback"
git push origin master

# Workflow creates PR: "chore(release): 4.0.2"
# Review and merge PR
# Workflow publishes version 4.0.2 to CocoaPods
```

### Example 3: Breaking Change (Major Version)

```bash
# Major API change
git commit -m "feat!: redesign tracker initialization

BREAKING CHANGE: Changed initialization from NRVideoAgent.start() to NRVideoAgent.configure()"
git push origin master

# Workflow creates PR: "chore(release): 5.0.0"
# Review and merge PR
# Workflow publishes version 5.0.0 to CocoaPods
```

### Example 4: Multiple Commits

```bash
git commit -m "feat: add HDR video support"
git commit -m "fix: improve buffering detection"
git commit -m "docs: update API documentation"
git push origin master

# Semantic-release analyzes all commits
# feat + fix = Minor version bump
# Workflow creates PR: "chore(release): 4.1.0"
```

## Support

For issues or questions:
1. Check workflow logs in GitHub Actions
2. Review this documentation
3. Contact the iOS SDK team

## References

- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Release](https://semantic-release.gitbook.io/)
- [CocoaPods Trunk](https://guides.cocoapods.org/making/getting-setup-with-trunk)