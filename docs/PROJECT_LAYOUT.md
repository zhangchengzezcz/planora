# Project Layout

## Maintained Files

- `planora/`: Native Apple app source, assets and onboarding source.
- `planora.xcodeproj/`: Xcode targets and build configuration.
- `planoraTests/`: Maintained regression tests, not disposable test exports.
- `Vendor/`: Required vendored dependencies, including Sparkle.
- `Planora Full.icon/` and `Planora Icons/`: Editable app icons and reference previews. Keep paths stable because Xcode references them.
- `web-demo/`: Maintained browser demo source and lockfile.
- `planora for android/`: Separate Android repository. Do not reorganize its source from the Apple project.
- `scripts/`: Build, signing, packaging and release checks.
- `updates/`: Update feed, release notes and DMG resources. Publish only the app archives and checksums as Release assets, not Markdown documents.
- `docs/`: Developer guidance, including `MAC_GLASS_CONTROLS.md`.

## Generated Files

Keep native build products outside this checkout, using an explicit Xcode `-derivedDataPath`. Web `node_modules/`, Android `build/`, `.gradle/`, `.kotlin/`, coverage `*.profraw` and exported UI probe apps are generated, not source.

Before cleanup, check that no build or development server owns the directory. Prefer moving identified disposable files to the Trash. Never remove installed apps, app user data, editable animation/icon sources, or the retained V2 entrance video as part of build cleanup.

Reinstall web dependencies from `web-demo/pnpm-lock.yaml` with `pnpm install --frozen-lockfile`; Android rebuilds generated outputs through its Gradle wrapper. Runtime user data is separate from this repository; see the README uninstall instructions.
