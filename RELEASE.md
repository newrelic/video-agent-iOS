# Release Process

This document outlines the automated release process for the iOS Video Agent SDK.

## Overview

The release process is fully automated using GitHub Actions and follows [Conventional Commits](https://www.conventionalcommits.org/) and [Semantic Versioning](https://semver.org/).

The workflow follows a **"stable releases, one-shot PRs"** approach where each release version has exactly one immutable pull request.

## Conventional Commits

The version bump is determined by analyzing commits since the last release:

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat:` | **Minor** (0.X.0) | `feat: add quality analytics tracking` |
| `fix:` | **Patch** (0.0.X) | `fix: resolve memory leak in tracker` |
| `perf:` | **Patch** (0.0.X) | `perf: optimize buffer management` |
| `BREAKING CHANGE:` or `!` | **Major** (X.0.0) | `feat!: redesign tracking API` |
| `docs:`, `style:`, `chore:`, `refactor:`, `test:`, `build:`, `ci:` | **No release** | `docs: update README` |

### Commit Message Format




```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Examples:**

```bash
# Minor version bump (feat)
git commit -m "feat: add support for adaptive bitrate tracking"

# Patch version bump (fix)
git commit -m "fix: prevent crash when video metadata is missing"

# Major version bump (breaking change)
git commit -m "feat!: redesign player tracker initialization

BREAKING CHANGE: PlayerTracker.init() now requires a configuration object"

# No version bump
git commit -m "docs: update installation guide"
git commit -m "chore: update dependencies"
```

## Release Process (Step by Step)

### 1. Make Changes & Commit

```bash
# Make your changes
git add .

# Commit using conventional commits format
git commit -m "feat: add new analytics feature"

# Push to master
git push origin master
```

### 2. Automated Version Bump

The `ios-release.yml` workflow automatically:
- Runs on every push to master
- Analyzes commits since last release
- Calculates next version
- Creates a release PR if needed

**If there are qualifying commits:**
- A PR will be created automatically
- PR title: `chore(release): X.Y.Z`
- PR includes changelog excerpt
- Branch: `release/X.Y.Z`

**If release branch already exists:**
- Workflow shows "Release branch already exists"
- Displays existing PR information (if found)
- Provides cleanup instructions if needed

**If no qualifying commits:**
- Workflow completes with "No release needed" message
- No PR is created

### 3. Review & Merge Release PR

1. Review the release PR:
   - Check the version number is correct
   - Review the CHANGELOG.md changes
   - Verify podspec versions are updated
   
2. Merge the PR to master:
   ```bash
   # Use GitHub UI to merge (recommended)
   # Or use GitHub CLI:
   gh pr merge <PR_NUMBER> --squash
   ```

### 4. Automated Publishing

When the release PR is merged, `ios-publish.yml` automatically:
- Validates all podspecs
- Publishes to CocoaPods (in order: NewRelicVideoAgent → NRAVPlayerTracker → NRIMATracker)
- Creates GitHub Release
- Verifies publication
- Deletes release branch (cleanup)

### 5. Release Complete! 

Users can now install the new version:

```ruby
# In Podfile
pod 'NewRelicVideoAgent', '~> X.Y.Z'
pod 'NRAVPlayerTracker', '~> X.Y.Z'
pod 'NRIMATracker', '~> X.Y.Z'
```

## Manual Release (Emergency)

If you need to manually trigger a release:

### Option 1: Trigger Version Bump Workflow

1. Go to Actions → "Version Bump PR"
2. Click "Run workflow"
3. Select branch: `master`
4. Click "Run workflow"

### Option 2: Manually Create Release PR

```bash
# 1. Determine next version
NEXT_VERSION="4.2.0"  # Replace with actual version

# 2. Create release branch
git checkout master
git pull origin master
git checkout -b "release/${NEXT_VERSION}"

# 3. Update podspec versions
sed -i '' "s/s.version[[:space:]]*=.*/s.version = '${NEXT_VERSION}'/" NewRelicVideoAgent.podspec
sed -i '' "s/s.version[[:space:]]*=.*/s.version = '${NEXT_VERSION}'/" NRAVPlayerTracker.podspec
sed -i '' "s/s.version[[:space:]]*=.*/s.version = '${NEXT_VERSION}'/" NRIMATracker.podspec

# 4. Generate changelog
npx semantic-release --no-ci

# 5. Commit changes
git add NewRelicVideoAgent.podspec NRAVPlayerTracker.podspec NRIMATracker.podspec CHANGELOG.md
git commit -m "chore(release): ${NEXT_VERSION}" -m "[skip ci]"

# 6. Push and create PR
git push origin "release/${NEXT_VERSION}"
gh pr create --base master --head "release/${NEXT_VERSION}" \
  --title "chore(release): ${NEXT_VERSION}"
```

### Option 3: Manual Publish (Bypass Automation)

1. Go to Actions → "Publish to CocoaPods"
2. Click "Run workflow"
3. Enter version (or leave blank to auto-detect)
4. Click "Run workflow"

## Retry Failed Release

If a release workflow failed and you need to retry:

### If Release Branch Already Exists:

```bash
# 1. Delete the release branch
git push origin --delete release/X.Y.Z

# 2. Close the PR (if it exists)
gh pr close <PR_NUMBER>

# 3. Re-trigger the workflow
# Either push a new commit to master, or manually trigger via GitHub Actions UI
```

The workflow will then create a fresh release branch and PR.

## Prerequisites

### GitHub Secrets

Ensure the following secret is configured in repository settings:

- `COCOAPODS_TRUNK_TOKEN` - Your CocoaPods trunk authentication token

To get your CocoaPods token:




```bash
pod trunk me
# Copy the token and add it to GitHub Secrets
```

## Troubleshooting

### "No new version to release"

**Cause:** No commits with `feat:`, `fix:`, or `BREAKING CHANGE:` since last release.

**Solution:** Make commits using conventional commit format.

### Release PR not created

**Possible causes:**
1. Last commit message contains `[skip ci]`
2. No qualifying commits since last release
3. Calculated version matches current version
4. Release branch already exists for this version

**Solution:** 
- Check workflow logs in GitHub Actions
- If branch exists, check if PR was already created
- Delete branch and re-run if needed

### "Release branch already exists"

**Cause:** A release branch for this version was already created.

**Solution:**
1. Check if a PR exists for this branch (workflow will show PR info)
2. If PR exists: Review and merge it
3. If no PR exists: Either create PR manually or delete branch and re-run:
   ```bash
   git push origin --delete release/X.Y.Z
   ```

### CocoaPods publish failed

**Possible causes:**
1. `COCOAPODS_TRUNK_TOKEN` secret not set or invalid
2. Podspec validation errors
3. Version already published

**Solution:** 
1. Verify secret is set correctly
2. Run `pod lib lint` locally to validate podspecs
3. Check CocoaPods for existing version

### Tag already exists error

**Cause:** Git tag `vX.Y.Z` already exists from a previous release.

**Solution:**
```bash
# Delete the tag locally and remotely
git tag -d vX.Y.Z
git push origin :refs/tags/vX.Y.Z

# Re-run the workflow
```

### Dependent pods fail to publish

**Cause:** `NewRelicVideoAgent` not yet indexed by CocoaPods.

**Solution:** The workflow waits up to 10 minutes for indexing. If it still fails:
1. Wait 5-10 more minutes
2. Manually trigger "Publish to CocoaPods" workflow
3. Or manually publish: `pod trunk push NRAVPlayerTracker.podspec --allow-warnings`

## Version History

All releases are documented in:
- `CHANGELOG.md` - Detailed changelog with commit links
- GitHub Releases - Release notes and installation instructions
- Git tags - Format: `vX.Y.Z` (e.g., `v4.1.0`)


## Workflow Philosophy

This release process follows the **"stable releases, one-shot PRs"** approach:

### Key Principles:

1. **One Branch = One PR**
   - Each release version has exactly one release branch
   - Each release branch has exactly one pull request
   - No force pushes or branch overwrites
   - **Note:** For normal development workflow, feature branches should be developed separately and merged to master via individual PRs before release automation triggers


2. **Immutable History**
   - Once a release branch is created, it's preserved
   - PR and commit history remain intact
   - Force pushes are avoided

3. **Idempotent Operations**
   - Re-running workflows is safe
   - Branch existence checks prevent duplicates
   - PR existence checks prevent errors

## Best Practices

1. **Always use conventional commits** for commits that should trigger releases
2. **Review release PRs carefully** before merging
3. **Test locally** before pushing to master:
   ```bash
   pod lib lint NewRelicVideoAgent.podspec --allow-warnings
   ```
4. **Use `[skip ci]`** in commit messages for non-release changes (docs, formatting)
5. **Monitor workflow runs** in GitHub Actions after merging
6. **Verify publication** on CocoaPods after release
7. **Don't manually modify release branches** - they're auto-generated
8. **Delete and retry** if you need to recreate a release (don't force push)

## Support

For issues with the release process:
1. Check GitHub Actions workflow logs
2. Review this documentation
3. Check [semantic-release documentation](https://semantic-release.gitbook.io/)
4. Contact the maintainers