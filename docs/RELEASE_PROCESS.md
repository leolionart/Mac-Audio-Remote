# Release Process for Audio Remote

## TL;DR

**ALWAYS use the local `release.sh` script for releases**. Never rely on GitHub Actions workflow alone, as it doesn't sign the ZIP file with EdDSA.

## Why This Matters

Sparkle auto-update uses EdDSA cryptographic signatures to verify updates:

- **Private Key** (stored on your Mac) - Signs the ZIP file during release
- **Public Key** (`SUPublicEDKey` in Info.plist) - Embedded in every app, used by ALL users to verify signatures

When a user checks for updates:
1. Sparkle downloads appcast.xml
2. Sees new version with signature
3. Downloads ZIP file from GitHub
4. **Verifies signature using public key from their installed app**
5. If signature matches → Install
6. If signature doesn't match → "Update Error!"

**All users use the SAME public key** (from their installed app), so ONE correctly signed release works for EVERYONE.

## Current Problem

- ✅ Local `release.sh` script: Creates ZIP + signs with EdDSA
- ❌ GitHub Actions workflow (`.github/workflows/release.yml`): Creates ZIP but **DOES NOT sign**

If GitHub Actions workflow runs automatically on tag push, it will:
1. Build app bundle
2. Create ZIP (unsigned)
3. Upload to GitHub release
4. **Overwrite** the signed ZIP from local script!

Result: Users get "Update Error! The update is improperly signed"

## Correct Release Process

### Step 1: Run Local Release Script

```bash
cd /path/to/Mac-Audio-Remote
bash release.sh
```

This script will:
1. Bump version and build number
2. Ask for release notes
3. Build app bundle
4. Create and **sign** ZIP file with EdDSA
5. Update appcast.xml with signature
6. Commit changes
7. Create Git tag
8. Push to GitHub
9. Create GitHub release
10. Upload **signed** ZIP to release

### Step 2: Verify Signature

After release, verify the ZIP on GitHub has correct signature:

```bash
VERSION="2.2.4"  # Replace with your version

# Download ZIP from GitHub
curl -L -o "/tmp/test-${VERSION}.zip" \
  "https://github.com/leolionart/Mac-Audio-Remote/releases/download/v${VERSION}/AudioRemote-${VERSION}.zip"

# Verify signature matches appcast.xml
SIGNATURE=$(grep -A10 "Version ${VERSION}" appcast.xml | grep "edSignature" | cut -d'"' -f2)
echo "Expected signature: $SIGNATURE"

# Verify with sign_update tool
if [ -f "/tmp/bin/sign_update" ]; then
  /tmp/bin/sign_update --verify "/tmp/test-${VERSION}.zip" "$SIGNATURE"
  echo "✅ Signature verified!"
else
  echo "⚠️  sign_update tool not found, skipping verification"
fi
```

### Step 3: Test Auto-Update

1. Install previous version of app
2. Launch app
3. Go to Settings → Software Update
4. Click "Check for Updates..."
5. Should see update available with "Install Update" button
6. Click install and verify it works

## If GitHub Actions Overwrites the ZIP

If you accidentally let GitHub Actions run and it overwrites the signed ZIP:

```bash
VERSION="2.2.4"  # Replace with your version

# Re-upload the signed ZIP from local
gh release upload "v${VERSION}" \
  ".build/release/AudioRemote-${VERSION}.zip" \
  --clobber

echo "✅ Re-uploaded signed ZIP"
```

## Future: Fix GitHub Actions Workflow

To properly fix this, we need to add EdDSA signing to GitHub Actions workflow:

1. **Export private key**:
   ```bash
   # Find where sign_update stores the key
   # Usually in Keychain or a local file
   ```

2. **Add private key to GitHub Secrets**:
   - Go to GitHub repo → Settings → Secrets and variables → Actions
   - Add new secret: `SPARKLE_EDDSA_PRIVATE_KEY`
   - Paste the private key (base64 encoded)

3. **Update `.github/workflows/release.yml`**:
   Add signing step after "Create ZIP archive":
   ```yaml
   - name: Sign ZIP with EdDSA
     env:
       PRIVATE_KEY: ${{ secrets.SPARKLE_EDDSA_PRIVATE_KEY }}
     run: |
       # Decode private key
       echo "$PRIVATE_KEY" | base64 --decode > /tmp/ed25519_private_key

       # Download sign_update tool
       curl -L -o /tmp/Sparkle.tar.xz \
         https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz
       tar -xf /tmp/Sparkle.tar.xz -C /tmp

       # Sign the ZIP
       VERSION=${GITHUB_REF#refs/tags/v}
       /tmp/bin/sign_update \
         --ed-key-file /tmp/ed25519_private_key \
         AudioRemote-${VERSION}.zip

       # Clean up
       rm /tmp/ed25519_private_key
   ```

**But until this is implemented, ALWAYS use `release.sh` locally!**

## Checklist

Before every release:

- [ ] All changes committed and pushed
- [ ] Tests passing
- [ ] Version bumped in code (if manual)
- [ ] Run `bash release.sh`
- [ ] Enter version number when prompted
- [ ] Enter release notes
- [ ] Wait for script to complete
- [ ] Verify GitHub release created
- [ ] Verify ZIP file uploaded
- [ ] Test auto-update from previous version
- [ ] Announce release

## Troubleshooting

### "Update Error! The update is improperly signed"

**Cause**: ZIP file on GitHub is not signed, or signature doesn't match.

**Fix**:
1. Re-upload signed ZIP from local (see "If GitHub Actions Overwrites the ZIP" above)
2. Or re-run `release.sh` and let it upload the signed ZIP

### "You're up to date" when new version exists

**Cause**: `sparkle:version` in appcast.xml uses version string instead of build number.

**Fix**: Ensure `sparkle:version` uses `CFBundleVersion` (build number):
```xml
<enclosure url="..."
           sparkle:version="12"  <!-- Build number, NOT "2.2.4" -->
           sparkle:shortVersionString="2.2.4"
```

### appcast.xml not updating

**Cause**: GitHub cache or local file not committed.

**Fix**:
1. Check `git status` - appcast.xml should be committed
2. Wait 1-2 minutes for GitHub raw.githubusercontent.com cache to clear
3. Force refresh: `curl -H "Cache-Control: no-cache" https://raw.githubusercontent.com/.../appcast.xml`
