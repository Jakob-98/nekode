# Release Checklist for CatAssistant v0.3.0

## One-Time Setup (before first release)

### 1. Create the Homebrew tap repo

Go to https://github.com/new and create `homebrew-catassistant` (public repo).

```bash
# Initialize with the Casks directory
git clone git@github.com:jakobserlier/homebrew-catassistant.git /tmp/homebrew-catassistant
cd /tmp/homebrew-catassistant
mkdir Casks
echo "# homebrew-catassistant" > README.md
echo "Homebrew tap for [CatAssistant](https://github.com/jakobserlier/catassistant)." >> README.md
echo "" >> README.md
echo '```bash' >> README.md
echo "brew tap jakobserlier/catassistant" >> README.md
echo "brew install --cask catassistant" >> README.md
echo '```' >> README.md
git add . && git commit -m "Initial tap setup" && git push
```

### 2. Create a GitHub Personal Access Token

1. Go to https://github.com/settings/tokens?type=beta (fine-grained tokens)
2. Create a new token:
   - Name: `catassistant-tap-updater`
   - Repository access: Only select repositories > `jakobserlier/homebrew-catassistant`
   - Permissions: Contents (Read and write)
3. Copy the token

### 3. Add the token as a repo secret

1. Go to https://github.com/jakobserlier/catassistant/settings/secrets/actions
2. Click "New repository secret"
3. Name: `TAP_GITHUB_TOKEN`
4. Value: paste the token from step 2
5. Click "Add secret"

## Release Steps

### 1. Merge the branch

```bash
git checkout master
git merge <branch-name>
git push origin master
```

### 2. Tag and push

```bash
git tag v0.3.0
git push origin v0.3.0
```

### 3. Wait for CI

The tag push triggers `.github/workflows/release.yml` which will:
- Build arm64 and x86_64 zips
- Create a GitHub Release with both zips
- Auto-update the Homebrew tap with correct SHA256 hashes

Monitor at: https://github.com/jakobserlier/catassistant/actions

### 4. Verify the release

```bash
# Check the GitHub Release page
gh release view v0.3.0

# Test Homebrew install (after CI completes)
brew tap jakobserlier/catassistant
brew install --cask catassistant

# Verify the app launches
open /Applications/CatAssistant.app

# Verify the hook binary is in the app bundle
ls -la /Applications/CatAssistant.app/Contents/MacOS/cathook

# Verify opencode plugin version matches the release
grep '"version"' plugins/opencode/package.json
```

### 5. Test the opencode plugin auto-install

```bash
# Verify the bundled plugin is in the app's Resources
ls -la /Applications/CatAssistant.app/Contents/Resources/opencode-plugin.js

# If opencode is configured (~/.config/opencode/ exists), launch the app
# and verify it auto-installs the plugin
open /Applications/CatAssistant.app
ls -la ~/.config/opencode/plugins/catassistant.js

# Start an opencode session and verify a session file appears
ls ~/.cat/sessions/

# Verify the session includes source: "opencode"
cat ~/.cat/sessions/*.json | jq '.source'
```

### 6. If anything goes wrong

```bash
# Delete the tag and release to re-do
gh release delete v0.3.0 --yes
git tag -d v0.3.0
git push origin :refs/tags/v0.3.0

# Fix the issue, then re-tag
git tag v0.3.0
git push origin v0.3.0
```
