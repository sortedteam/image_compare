# Image Compare Lab

Visual tool to test `handpickd_image_compare` with multiple images and option presets.

## Run on device (recommended — OpenCV needs native runtime)

```bash
cd handpickd_image_compare/example
flutter pub get
flutter run
```

## What you can do

1. Upload a **reference** image.
2. Upload one or more **query** images.
3. Tap **Run all combinations** — every preset is compared against every query.
4. View the **result matrix** (preset rows × query columns). Tap a cell for full score breakdown.
