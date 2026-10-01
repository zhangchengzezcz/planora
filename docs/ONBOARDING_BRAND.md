# Onboarding Brand

`Planora Full.icon` is the source of truth. The first-launch logo uses its actual light/dark Icon Composer renders, not a separate letter mark or a redesigned vector approximation.

Run `bash scripts/export-brand.sh` with Xcode 27 selected after editing the icon. The script updates the two bundled 384px PNGs and the matching web assets. Keep the editable icon project. These PNGs are maintained app resources, not disposable test exports.

`OnboardingBrand.swift` owns the welcome palette and Chinese/English/Japanese copy. Use cool-white and graphite surfaces, semantic text colors and restrained blue-green accents. Do not apply another glass surface over the already-rendered icon. Introduction content scrolls while the primary action remains reachable; completed onboarding should not replay on every launch.

Keep the post-onboarding Entrance Film separate. Updating WelcomeView must not overwrite Entrance timeline, camera, content, anchors, or the retained V2 video.
