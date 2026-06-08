# flutter_pixelmatching (vendored)

Local copy of [flutter_pixelmatching](https://pub.dev/packages/flutter_pixelmatching) **1.0.1** with Sure/Android fixes applied:

- `android/build.gradle`: `namespace` and `ndkVersion '26.1.10909125'`
- `lib/src/pixelmatching_client.dart`: reuses native image buffers in `query()` (no re-alloc per frame)

Vendored inside `handpickd_image_compare`. Do not use pub.dev; patch via repo `tool/patch_flutter_pixelmatching.sh` if needed.
