# Mac Software Updates

## DMG

Install `scripts/dmg-requirements.txt` in a dedicated Python virtual environment.
Render the background with `swift scripts/dmg-background.swift /path/background.png`.
Run `dmgbuild -s scripts/dmg-settings.py -D app=/path/planora.app -D guide=/absolute/path/updates/INSTALLATION.txt -D background=/path/background.png "Planora VERSION" /path/Planora-VERSION-macOS.dmg`.
Verify the image with `hdiutil verify`, mount it read-only, and check the Finder
layout and bundled app signature before uploading. `updates/INSTALLATION.txt`
includes the optional, narrowly scoped xattr command; never execute it from an
installer or disable Gatekeeper. The app icon is not modified by these scripts.

Mac uses Sparkle 2.9.6 for update checks, release notes, download progress,
signature validation, installation and relaunch. iPhone has no updater.
The menu entry is Planora > Check for Updates. Settings has Software Update.
Automatic checks are enabled; automatic downloads are opt-in. No system profile
is sent. Sparkle stores its own preferences; they are not included in task backups.

The public key is in `planora/Mac/Info.plist`. The private Ed25519 key is stored
only in the login Keychain under account `com.zhangchengze.planora.mac`.
Never export or commit that key. Keep a secure backup of the signing key before
replacing this Mac. Losing it can break future update trust.

## Publishing

1. Increase both MARKETING_VERSION and CURRENT_PROJECT_VERSION. Sparkle compares
   CURRENT_PROJECT_VERSION, so every release must have a strictly larger build.
2. Build the Mac app. Prefer Developer ID signing and notarization. The archive
   signature is separate from Apple signing; it does not bypass Gatekeeper.
3. Run `bash scripts/prepare-mac-update.sh /path/planora.app /path/notes.md /path/new-output`.
   This creates a ZIP and signed appcast, never uploads or creates a DMG.
4. Upload the ZIP to the matching GitHub Release first. Verify its public URL.
5. Replace this directory's appcast.xml with the generated signed file and
   publish it on main. Never edit the signed XML manually.
6. Verify the public feed and test updating a separate older app copy before
   announcing availability. Never use the user's working app as an install test.

Feed URL: https://raw.githubusercontent.com/zhangchengzezcz/planora/main/updates/appcast.xml

The initial feed intentionally has no downloadable release: the old 1.7.1 DMG
does not contain this updater and must not be offered as a new update. Existing
installations need to install the first updater-enabled release once manually.
New releases must include the signed feed as well as the downloadable archive;
creating a GitHub Release alone does not enable automatic updates.
