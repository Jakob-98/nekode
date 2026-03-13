# Release Checklist for Nekode v0.3.0

## One-Time Setup (before first release)

### 1. Create the Homebrew tap repo

Go to https://github.com/new and create `homebrew-nekode` (public repo).

```bash
# Initialize with the Casks directory
git clone git@github.com:jakobserlier/homebrew-nekode.git /tmp/homebrew-nekode
cd /tmp/homebrew-nekode
mkdir Casks
echo "# homebrew-nekode" > README.md
echo "Homebrew tap for [Nekode](https://github.com/jakobserlier/nekode)." >> README.md
echo "" >> README.md
echo '```bash' >> README.md
echo "brew tap jakobserlier/nekode" >> README.md
echo "brew install --cask nekode" >> README.md
echo '```' >> README.md
git add . && git commit -m "Initial tap setup" && git push
```

### 2. Create a GitHub Personal Access Token

1. Go to https://github.com/settings/tokens?type=beta (fine-grained tokens)
2. Create a new token:
   - Name: `nekode-tap-updater`
   - Repository access: Only select repositories > `jakobserlier/homebrew-nekode`
   - Permissions: Contents (Read and write)
3. Copy the token

### 3. Add the token as a repo secret

1. Go to https://github.com/jakobserlier/nekode/settings/secrets/actions
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

Monitor at: https://github.com/jakobserlier/nekode/actions

### 4. Verify the release

```bash
# Check the GitHub Release page
gh release view v0.3.0

# Test Homebrew install (after CI completes)
brew tap jakobserlier/nekode
brew install --cask nekode

# Verify the app launches
open /Applications/Nekode.app

# Verify the hook binary is in the app bundle
ls -la /Applications/Nekode.app/Contents/MacOS/nekode

# Verify opencode plugin version matches the release
grep '"version"' plugins/opencode/package.json
```

### 5. Test the opencode plugin auto-install

```bash
# Verify the bundled plugin is in the app's Resources
ls -la /Applications/Nekode.app/Contents/Resources/opencode-plugin.js

# If opencode is configured (~/.config/opencode/ exists), launch the app
# and verify it auto-installs the plugin
open /Applications/Nekode.app
ls -la ~/.config/opencode/plugins/nekode.js

# Start an opencode session and verify a session file appears
ls ~/.nekode/sessions/

# Verify the session includes source: "opencode"
cat ~/.nekode/sessions/*.json | jq '.source'
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
