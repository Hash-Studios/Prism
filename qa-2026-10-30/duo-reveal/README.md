# Duo reveal proof, 2026-10-30

App code: aa757893011d095d629139405163b1ce298925cd.

## Sources and limits

- `ios-before.png`, `ios-folded.png`, `ios-unfolded.png`: reviewed debug app on iPhone Duo Simulator. The Photos picker loads a local 2670 x 1878 fixture with two colored shapes. This is geometry proof, not a real AI result or approved catalog wallpaper.
- `android-before.png`, `android-unfolded.png`, `android-cover-folded.png`: reviewed debug app on Pixel Fold emulator. Real Pexels wallpaper 3244513, by Andy Vu. It is a wide existing wallpaper, not a Duo Studio approval. Emulator hinge closure moved the app to its cover display and preserved preview state.
- `share-card-fixture.png`: production ShareCard renderer using the same local geometry fixture, 1080 x 1920. Not proof of a native share-sheet export.
- `ios-reveal.mp4`: real app Fold/Unfold interaction captured with the device-panel agent-device command. Converted with tool/record_clip.sh settings to 1080 x 1920, 30 fps, 5.03 seconds. The script itself did not capture the video.

The preview is Prism's approved right-side preset, not a claim about Apple's automatic wallpaper crop. All downloads retain the full wide image.

Live AI, successful iOS Photos save and guide, native sharing, iOS hardware fold/system alignment, and Android wallpaper application remain unproven. Fresh devices are signed out. Android's leased emulator disappeared after the set-flow helper timed out; the lease was closed. No auth bypass, deploy, Studio batch, or content approval was performed.
