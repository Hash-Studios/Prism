# Daily ships

Prism ships something small every day and posts it.

## Ship clip

Record a short vertical clip (1080x1920, 30 fps, H.264, no audio) of the running app for a social post. The app must already run on the booted iOS Simulator or the connected Android emulator. You need ffmpeg.

```sh
tool/record_clip.sh ios                      # writes prism-ios-<timestamp>.mp4
tool/record_clip.sh android clip.mp4         # Android stops by itself at 3 minutes
tool/record_clip.sh ios clip.mp4 --trim 2-12 # keep seconds 2 to 12
```

Press Ctrl-C to stop the recording. Black bars pad the clip. It is never stretched.

### Morning post

```text
Today I'm shipping <X> in Prism.

<one line on why it matters to users>
```

### Evening post

```text
Shipped: <X>

<attach clip.mp4>

What changed:
- <change 1>
- <change 2>

PR: https://github.com/Hash-Studios/Prism/pull/<number>
```
