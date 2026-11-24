# iOS ATT proof, 2026-11-24

Simulator, debug build with the `prd` Doppler config, fresh install unless noted. iPadOS 27.2 simulator runtime would
not download on this Mac, so the iPad runs use iPadOS 27.0 (newest iPad runtime here). iPhone: iPhone 17 Pro, iOS 27.0.

| File | Build | What it shows |
| --- | --- | --- |
| before-master-ipad-portrait.* | master dd99b2729 (379 logic) | Prompt over the sign-in screen, about 3 s after launch, first request from Flutter. |
| att-ipad-portrait.* | final PR build | Prompt on launch, one request from the scene activation. |
| att-ipad-portrait-allow.mp4 | PR build before the last native commit | Prompt, then "Allow". |
| att-ipad-landscape.* | PR build before the last native commit | Prompt in landscape, then "Ask App Not to Track". |
| att-iphone.* | PR build before the last native commit | iPhone: prompt, then "Ask App Not to Track" (cut: first 25 s and last 40 s). |
| att-ipad-no-prompt-after-answer.* | final PR build | Relaunch after the answer: no prompt, no request. |

The last native commit (ac3e2ffb1) only moves the repeat-request guard reset from activation to deactivation. It does
not change the first request on launch.
