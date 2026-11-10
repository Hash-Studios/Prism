# Live walls local QA

Local QA for creator live walls (short looping MP4 wallpapers). Admin seeded fixtures on the `demo-prism` emulators only.
This is not device proof on its own. Run the steps in this order.

The harness uses the same ports as the scheduled release harness. Do not run both at the same time.

Run every command from the repo root.

## Steps

1. Build the functions. Run `cd functions && npm run build`.
2. Check the prerequisites. Run `node tool/live_walls_qa.cjs preflight`.
3. Write the runtime. Run `node tool/live_walls_qa.cjs prepare`.
4. Open shell A. Run `node tool/live_walls_qa.cjs emulators`. Keep it running.
5. Open shell B. Run `node tool/live_walls_qa.cjs serve`. Keep it running.
6. Open shell C. Run `node tool/live_walls_qa.cjs seed`.
7. For Android, forward the ports. Run `node tool/live_walls_qa.cjs reverse-android <serial>`.
8. Push the fixture videos to the device.
   - iOS Simulator: run `node tool/live_walls_qa.cjs media-ios <udid>`.
   - Android: run `node tool/live_walls_qa.cjs media-android <serial>`.
9. Build the app for one user. Use `creator`, `admin` or `viewer`.
   - Android: run `node tool/live_walls_qa.cjs build-apk --user creator`.
   - iOS Simulator: run `node tool/live_walls_qa.cjs build-ios --user creator`.
10. Install the build.
    - Android: run `adb -s <serial> install -r build/app/outputs/flutter-apk/app-debug.apk`.
    - iOS Simulator: run `xcrun simctl install <udid> build/ios/iphonesimulator/Runner.app`.
11. Drive the app with the `verify-prism` skill. Upload one live wall with `live-ok.mp4`.
    Upload `live-landscape.mp4` and `live-long.mp4` too. The device must refuse both.
12. Run `node tool/live_walls_qa.cjs check-live`.
13. Run `node tool/live_walls_qa.cjs evidence`. It prints a JSON summary.

## Fixture videos

- `live-ok.mp4`: 1080x1920, H.264, 6 s, 30 fps. The app must accept it.
- `live-landscape.mp4`: 1920x1080, 2 s. The app must refuse it.
- `live-long.mp4`: 1080x1920, 20 s, 5 fps. The app must refuse it.

The SHA-256 of each file is in `<runtime>/manifest.json`.

## Stop and clean up

1. Press Ctrl-C in shell B (serve).
2. Press Ctrl-C in shell A (emulators).
3. For Android, remove the port forwards. Run `node tool/live_walls_qa.cjs unreverse-android <serial>`.
4. Delete the runtime. Run `rm -rf /tmp/prism-live-walls-qa`.

To start again, stop the emulators first. Then delete the runtime and run `prepare` again.
