# iOS Release Automation

This repository includes a GitHub Actions workflow to automate the iOS release process for publishing to CocoaPods.

## How It Works

The workflow automatically triggers when you **push a git tag** to the master branch. It extracts the version from the tag and automates **all steps** of the release process:

1. **Extract Version from Git Tag** - Automatically reads version from the pushed tag
2. **Update Version Numbers** - Updates version in all 3 podspec files
3. **Validate Podspecs** - Validates each podspec with `pod lib lint`
4. **Publish to CocoaPods** - Publishes in dependency order (core first, then dependents)
5. **Verify Publication** - Verifies pods are searchable and checks pod info

## Prerequisites

### Add CocoaPods Trunk Token to GitHub Secrets

1. **Get your CocoaPods trunk token:**
   ```bash
   cat ~/.netrc | grep -A 2 trunk.cocoapods.org
   ```
   Look for the password line - that's your token.

   Or get it from: https://trunk.cocoapods.org/

2. **Add to GitHub Secrets:**
   - Go to your repository on GitHub
   - Navigate to: **Settings** → **Secrets and variables** → **Actions**
   - Click **New repository secret**
   - Name: `COCOAPODS_TRUNK_TOKEN`
   - Value: Your CocoaPods trunk token
   - Click **Add secret**

## How to Release

### Option 1: Command Line (Recommended)

Create and push a git tag with the version number:

```bash
# Create a tag with the version number (e.g., 4.0.2)
git tag 4.0.2

# Push the tag to trigger the release workflow
git push origin 4.0.2
```

**That's it!** The workflow will automatically:
- Extract the version from the git tag
- Update version in all 3 podspec files
- Validate all podspecs
- Publish to CocoaPods in correct order
- Verify publication

### Option 2: GitHub UI

1. Go to your repository on GitHub
2. Click on **Releases** (or go to `https://github.com/newrelic/video-agent-iOS/releases`)
3. Click **Create a new release**
4. Click **Choose a tag**
5. Type the version number (e.g., `4.0.2`) and click **Create new tag**
6. Add release title and description (optional)
7. Click **Publish release**

This will create the tag and trigger the release workflow automatically.

### Option 3: Manual Release (Fallback)

If you need to release manually without the workflow:

#### Step 1: Update Version Numbers
```bash
# Update version in all 3 podspec files:
# - NewRelicVideoAgent.podspec
# - NRAVPlayerTracker.podspec
# - NRIMATracker.podspec
# Change: s.version = '4.0.2'
```

#### Step 2: Validate Podspecs
```bash
pod lib lint NewRelicVideoAgent.podspec --allow-warnings
pod lib lint NRAVPlayerTracker.podspec --allow-warnings
pod lib lint NRIMATracker.podspec --allow-warnings
```

#### Step 3: Publish to CocoaPods (In Order)
```bash
# 1. Publish core library first
pod trunk push NewRelicVideoAgent.podspec --allow-warnings

# 2. Wait for core to be indexed (~5 minutes)
pod search NewRelicVideoAgent

# 3. Publish dependent pods
pod trunk push NRAVPlayerTracker.podspec --allow-warnings
pod trunk push NRIMATracker.podspec --allow-warnings
```

#### Step 4: Verify Publication
```bash
# Check if pods are live
pod search NewRelicVideoAgent
pod search NRAVPlayerTracker
pod search NRIMATracker

# Check pod info
pod trunk info NewRelicVideoAgent
```

## What the Workflow Does

### Step 1: Extract Version from Git Tag
When you push a git tag (e.g., `4.0.2`), the workflow automatically extracts the version number from the tag name and uses it for the entire release process.

### Step 2: Update Version Numbers
Automatically updates `s.version = 'X.X.X'` in all 3 podspec files:
- `NewRelicVideoAgent.podspec`
- `NRAVPlayerTracker.podspec`
- `NRIMATracker.podspec`

The version is set to match the git tag you pushed.

### Step 3: Validate Podspecs
Validates each podspec locally:
```bash
pod lib lint NewRelicVideoAgent.podspec --allow-warnings
pod lib lint NRAVPlayerTracker.podspec --allow-warnings
pod lib lint NRIMATracker.podspec --allow-warnings
```

### Step 4: Publish to CocoaPods (In Order)

**Important:** Publishes in dependency order to avoid failures:

1. **First:** Publishes `NewRelicVideoAgent` (core library)
   ```bash
   pod trunk push NewRelicVideoAgent.podspec --allow-warnings
   ```

2. **Wait:** Automatically waits ~5 minutes for CocoaPods to index the core library
   - Uses automated polling to check when indexed
   - Verifies with: `pod search NewRelicVideoAgent`

3. **Then:** Publishes dependent pods
   ```bash
   pod trunk push NRAVPlayerTracker.podspec --allow-warnings
   pod trunk push NRIMATracker.podspec --allow-warnings
   ```

### Step 5: Verify Publication

Verifies all pods are published and searchable:
```bash
pod search NewRelicVideoAgent
pod search NRAVPlayerTracker
pod search NRIMATracker
pod trunk info NewRelicVideoAgent
```

## Monitoring the Release

1. Go to **Actions** tab in your repository
2. Click on the running workflow
3. Watch each step complete in real-time
4. Each step shows detailed output:
   - Version updates
   - Validation results
   - Publication progress
   - Verification output

## Troubleshooting

### Error: COCOAPODS_TRUNK_TOKEN not set
**Solution:** Add your CocoaPods trunk token to GitHub secrets (see Prerequisites above)

### Error: Podspec validation fails
**Solution:**
- Review the validation error in the workflow logs
- Fix the issue in the podspec file locally
- Commit the fix and re-run the workflow with the same version

### Error: Dependent pods can't find NewRelicVideoAgent
**Solution:**
- The workflow automatically waits for indexing
- If it still fails, wait a few more minutes
- Manually verify: `pod search NewRelicVideoAgent`
- Re-run the workflow from GitHub Actions UI

### Error: Version already published
**Solution:**
- CocoaPods doesn't allow republishing the same version
- Increment the version number and try again

## Files

- `.github/workflows/ios-release.yml` - GitHub Actions workflow that automates all steps

## Support

For issues with:
- **GitHub Actions workflow:** Check the Actions logs and this documentation
- **CocoaPods:** Visit https://guides.cocoapods.org/
- **Video Agent:** See main README.md and INSTALLATION.md
