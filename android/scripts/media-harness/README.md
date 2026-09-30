# Media host harness

Run `android/scripts/test-media-host-api.sh` to compile the production
`PrismMediaHostApiImpl.kt` with cached Kotlin 2.3.0 and invoke its private
`saveMediaInternal` and `writeToPictures` methods. Pass a source file path to
test another revision, or use `android/scripts/test-media-host-api.sh --git
<revision>` to compile that revision directly from Git.

The Android and Pigeon classes here are narrow test doubles for host calls,
streams, files, and MediaStore state. The `BitmapFactory` double only recognizes
the fixture PNG plus simple JPEG/WebP headers and reads PNG dimensions. It does
not prove Android codec behavior, image corruption detection, or device media
scanning. The URL handler simulates status, headers, body failures, and a final
redirect URL; it does not exercise sockets or Android redirect handling.
