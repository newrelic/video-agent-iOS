# iOS Release Automation

This repository includes a GitHub Actions workflow to automate the iOS release process for publishing to CocoaPods.

## How It Works

The workflow automatically triggers when you **push a git tag**. It extracts the version from the tag and automates **all steps** of the release process:

1. **Extract Version from Git Tag** - Automatically reads version from the pushed tag
2. **Update Version Numbers** - Updates version in all 3 podspec files
3. **Commit Version Changes** - Commits updated podspecs back to the repository
4. **Validate Podspecs** - Validates each podspec with `pod lib lint`
5. **Publish to CocoaPods** - Publishes in dependency order (core first, then dependents) - **Only when tag is on master branch**
6. **Verify Publication** - Verifies pods are searchable and checks pod info

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

### Ensure Workflow Has Write Permissions

1. Go to: **Settings** → **Actions** → **General** → **Workflow permissions**
2. Select: **Read and write permissions**
3. Click **Save**

This allows the workflow to commit version updates back to your repository.

## Testing the Workflow (Without Publishing)

You can safely test the workflow on non-master branches:

```bash
# From your test branch
git tag 4.0.2-test
git push origin 4.0.2-test
```

**What happens:**
- Extracts version `4.0.2-test`
- Updates all podspecs to `4.0.2-test`
- Commits changes back to your test branch
- Validates all podspecs
- **Does NOT publish to CocoaPods** (tag not on master)

## How to Release to Production

**Important:** Publishing only happens when the tag is on the **master** branch.

### Option 1: Command Line (Recommended)

```bash
# Ensure you're on master and up to date
git checkout master
git pull origin master

# Create and push a tag with the version number
git tag 4.0.2
git push origin 4.0.2
```

**That's it!** The workflow will automatically:
- Extract version `4.0.2` from the tag
- Update version in all 3 podspec files
- Commit the version updates back to master
- Validate all podspecs
- **Publish to CocoaPods** (because tag is on master)
- Verify publication

### Option 2: GitHub UI

1. Go to your repository on GitHub
2. Click on **Releases** (or go to `https://github.com/newrelic/video-agent-iOS/releases`)
3. Click **Draft a new release**
4. **Choose a tag:** Type the version number (e.g., `4.0.2`)
5. **Target:** Select **master** branch **IMPORTANT!**
6. Type the tag name to create it: `4.0.2`
7. Add release title and description (optional)
8. Click **Publish release**

**Note:** When you publish a release via GitHub UI, it creates the tag, which triggers the workflow.

**Important:** Make sure the tag targets **master** branch, otherwise it won't publish to CocoaPods.

## What the Workflow Does

### Step 1: Extract Version from Git Tag
When you push a git tag (e.g., `4.0.2`), the workflow automatically extracts the version number and uses it for the entire release process.

### Step 2: Update Version Numbers
Automatically updates `s.version = 'X.X.X'` in all 3 podspec files:
- `NewRelicVideoAgent.podspec`
- `NRAVPlayerTracker.podspec`
- `NRIMATracker.podspec`

The version is set to match the git tag you pushed.

### Step 3: Commit Version Changes
Commits the updated podspec files back to the repository with message:
```
Update version to X.X.X
```

The commit is authored by `github-actions[bot]` and pushed to the branch where the tag originated.

**How it works:**
1. Finds the branch that contains the tag
2. Fetches latest changes from that branch
3. Rebases the version commit on top of latest changes (ensures clean history)
4. Pushes the commit back to the branch

### Step 4: Check if Tag is on Master
Determines whether the tag is on the master branch to decide if publishing should proceed.

### Step 5: Validate Podspecs
Validates each podspec locally:
```bash
pod lib lint NewRelicVideoAgent.podspec --allow-warnings
pod lib lint NRAVPlayerTracker.podspec --allow-warnings
pod lib lint NRIMATracker.podspec --allow-warnings
```

**This step runs on all branches** (including test branches).

### Step 6: Publish to CocoaPods (In Order)

**Important:** This step **only runs when the tag is on master branch**.

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

### Step 7: Verify Publication

Verifies all pods are published and searchable:
```bash
pod search NewRelicVideoAgent
pod search NRAVPlayerTracker
pod search NRIMATracker
pod trunk info NewRelicVideoAgent
```

**This step runs on all branches** for verification purposes.

## Monitoring the Release

### Via GitHub Actions UI

1. Go to **Actions** tab in your repository
2. Click on the running workflow
3. Watch each step complete in real-time
4. Each step shows detailed output:
   - Version extraction
   - Version updates in podspecs
   - Commit and push status
   - Branch detection (master or not)
   - Validation results
   - Publication progress (if on master)
   - Verification output

### Via Command Line

```bash
# Watch the workflow in real-time
gh run watch

# List recent workflow runs
gh run list --workflow=ios-release.yml --limit 5
```

## Workflow Triggers

The workflow runs **ONLY** when:
- You push a git tag (from any branch)

The workflow **DOES NOT** run on:
- Regular commits to branches
- Pull requests
- Merges without tags

**Note:** Creating a GitHub Release via UI creates a tag, which triggers the workflow. You will only see **one workflow run** (not duplicates).

## Publishing Rules

Publishing to CocoaPods happens **ONLY** when:
- Tag is on **master** branch

For non-master branches:
- Version updates
- Commits changes
- Validates podspecs
- **Does NOT publish to CocoaPods**

## Troubleshooting

### Error: COCOAPODS_TRUNK_TOKEN not set
**Solution:** Add your CocoaPods trunk token to GitHub secrets (see Prerequisites above)

### Error: Podspec validation fails
**Solution:**
- Review the validation error in the workflow logs
- Fix the issue in the podspec file locally
- Commit the fix and push a new tag

### Error: Permission denied when pushing commit
**Solution:**
- Ensure workflow has write permissions (see Prerequisites)
- Go to: Settings → Actions → General → Workflow permissions
- Select "Read and write permissions"

### Error: Could not rebase
**Solution:**
- This happens if there are conflicting changes
- The workflow will show a warning and skip the push
- Manually resolve conflicts and push the version updates

### Error: Dependent pods can't find NewRelicVideoAgent
**Solution:**
- The workflow automatically waits for indexing
- If it still fails, wait a few more minutes
- Manually verify: `pod search NewRelicVideoAgent`
- Re-run the workflow from GitHub Actions UI

### Error: Version already published
**Solution:**
- CocoaPods doesn't allow republishing the same version
- Increment the version number and push a new tag

### Testing didn't publish (expected)
**This is normal!** If you pushed a tag from a non-master branch:
- The workflow validates but doesn't publish (by design)
- Check workflow logs for "Tag is NOT on master branch" message
- Check workflow logs for "TEST RUN - NO PODS WERE PUBLISHED" message
- To actually publish, push a tag from the master branch

### Workflow triggered twice
**This should NOT happen anymore.** The workflow only triggers on tag pushes, not on GitHub Release creation separately. If you see two runs, it may be from:
- Pushing the same tag twice
- Creating a release and manually pushing a tag with the same name

## Files

- `.github/workflows/ios-release.yml` - GitHub Actions workflow that automates all steps
- `RELEASE.md` - This documentation file

## Example Workflow

### Testing on a Feature Branch
```bash
# From your feature branch
git checkout feature/my-changes
git tag 4.0.2-test
git push origin 4.0.2-test

# Result:
# - Workflow run
# - Validates but doesn't publish
# - Version commit pushed to feature/my-changes
```

### Production Release from Master
```bash
# From master branch
git checkout master
git pull origin master
git tag 4.0.2
git push origin 4.0.2

# Result:
# - Workflow run
# - Validates AND publishes to CocoaPods
# - Version commit pushed to master
```

### Production Release via GitHub UI
1. Go to Releases → Draft a new release
2. Choose tag: `4.0.2`
3. **Target: master** Important!
4. Publish release

**Result:**
- Workflow run (triggered by tag creation)
- Validates AND publishes to CocoaPods
- Version commit pushed to master

## Support

For issues with:
- **GitHub Actions workflow:** Check the Actions logs and this documentation
- **CocoaPods:** Visit https://guides.cocoapods.org/
- **Video Agent:** See main README.md and INSTALLATION.md
