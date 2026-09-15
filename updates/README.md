# Planora Updates

此目录保存 Planora 的公开版本说明、Mac 软件更新 feed、DMG 安装资源和安装说明。

This directory contains Planora's public release notes, Mac software-update feed, DMG installation resources, and installation guidance.

## Files

- `1.7.2.md` — Planora 1.7.2 release notes
- `1.7.3.md` — Planora 1.7.3 release notes
- `1.7.4.md` — Planora 1.7.4 release notes
- `appcast.xml` — signed Sparkle update feed for Mac
- `INSTALLATION.txt` — bilingual Mac installation and security guide
- `assets/dmg-background.png` — embedded Finder background used by the Mac DMG

## Mac Update System

Planora for Mac uses Sparkle 2.9.6.

Sparkle is used only by the macOS build. iPhone and iPad builds do not include the Sparkle updater.

The Mac update system uses:

- a signed `appcast.xml`;
- Ed25519 signatures for update archives;
- Sparkle 2.9.6 for update discovery, download, verification, installation, and relaunch.

The private Sparkle signing key must never be committed to this repository.

Sparkle update signatures are not a replacement for Apple Developer ID signing or notarization.

## DMG

The Planora Mac DMG contains:

- `planora.app`;
- an `Applications` shortcut;
- an embedded bilingual Finder installation background;
- `INSTALLATION.txt`.

The background must be embedded inside the disk image and must not depend on an absolute path on the development Mac.

Before publication, verify:

1. disk-image integrity;
2. the embedded background;
3. Finder icon view;
4. the Planora application;
5. the Applications shortcut;
6. `INSTALLATION.txt`;
7. application code signing where applicable;
8. SHA-256 checksums.

## Planora 1.7.4

Planora 1.7.4 primarily improves iPhone and iPad compatibility on iOS / iPadOS 26 while preserving the existing iOS / iPadOS 27 and Mac architecture.

Known issue: tapping a date or week area in the Home weekly calendar on iPhone or iPad may cause the interface to become unresponsive and crash.

See `1.7.4.md` for the complete bilingual release notes.
