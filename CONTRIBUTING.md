# Contributing to Prism
We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## We Develop with Github
We use github to host code, to track issues and feature requests, as well as accept pull requests.

## Secrets policy
Runtime secrets are managed in Doppler (project `prism`). Do not rely on local `.env` syncing.

When introducing a new secret, update all three:

1. Doppler config(s) (`dev` and/or `production`)
2. `.env.example` (reference-only schema)
3. `lib/env/env.dart` (if the app reads it via `String.fromEnvironment`)

## We Use [Github Flow](https://guides.github.com/introduction/flow/index.html), So All Code Changes Happen Through Pull Requests
Pull requests are the best way to propose changes to the codebase (we use [Github Flow](https://guides.github.com/introduction/flow/index.html)). We actively welcome your pull requests:

1. Fork the repo and create your branch from `master`.
2. Set up secrets via Doppler — all runtime secrets (API keys, tokens) are managed through Doppler, not local files. Run `make setup-dev` after getting Doppler access. See [README → Secrets with Doppler](README.md#secrets-with-doppler) and [`docs/development/doppler.md`](docs/development/doppler.md) for details.
3. You also need to create a Firebase project, download the `google-services.json` to `android/app/` (and `GoogleService-Info.plist` to `ios/Runner/`). Then enable Cloud Firestore, and create a schema like this -
```
.
├── notifications
|   └── documentID (AutoID)
|       ├── createdAt - DateTime.now() or timestamp
|       ├── data - Array
|       |     ├── imageUrl - 'Link for notification image'
|       |     ├── url - 'Link for on Tap'
|       |     ├── pageName - 'if no url is given, you can give route name here like /setups, to open a page in-app'
|       |     └── arguments - 'arguments for the page, if pageName is used'
|       ├── modifier - 'all' (We support these modifiers - pro, free, all, leave blank for no user (""), and email where you can write any email, so that the notification will only be available tot that user)
|       └── notification - Array
|             ├── body - 'Notification subtitle'
|             └── title - 'Notification title'
├── setups
|   └── documentID (AutoID)
|       ├── by - 'Designer Name'
|       ├── name - 'Setup Name'
|       ├── email - 'Designer email'
|       ├── desc - 'Setup Description'
|       ├── created_at - DateTime.now() or timestamp
|       ├── userPhoto - 'Link of user profile photo'
|       ├── id - 'Wallpaper ID'
|       ├── instagram - 'Instagram link of user'
|       ├── icon - 'Icon Pack Name'
|       ├── icon_url - 'Play Store Link for Icon Pack'
|       ├── twitter - 'Twitter link of user'
|       ├── wallpaper_provider - 'Prism'
|       ├── wallpaper_thumb - 'Wallpaper Thumbnail URL (preferrable low quality for easy download)'
|       ├── wallpaper_url - 'Link of Wallpaper' (Supports array too, upload setup from in-app to see its example)
|       ├── widget - 'Widget Name'
|       ├── widget_url - 'Play Store Link for Widget'
|       ├── widget2 - 'Widget 2 Name'
|       ├── widget_url2 - 'Play Store Link for Widget 2'
|       ├── image - 'Display Image for the setup'
|       └── review - true
|
└── walls
    └── documentID (AutoID)
        ├── by - 'Designer Name'
        ├── email - 'Designer email'
        ├── desc - 'Wallpaper Description or Copyright info'
        ├── collections - ["name1","name2"]
        ├── userPhoto - 'Link of user profile photo'
        ├── id - 'Wallpaper ID'
        ├── category - 'Community'
        ├── size - 'Wallpaper Size in MB'
        ├── wallpaper_provider - 'Prism'
        ├── wallpaper_thumb - 'Wallpaper Thumbnail URL (preferrable low quality for easy download)'
        ├── wallpaper_url - 'Link of Wallpaper'
        ├── resolution - 'Wallpaper width x Wallpaper height'
        ├── createdAt - DateTime.now() or timestamp
        └── review - true
```
<img src="/demo/2.png">
<img src="/demo/3.png">

All the other needed data, the app will create itself, and there is no need manually write it.

Now we have implemented the following security rules for the Cloud Firestore, but you are free to change it.
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
  	match /tokens/{devtoken}{
    	allow read, write: if true;
    }
    match /walls/{document=**}{
    	allow read: if true;
      allow write: if request.auth.uid != null;
    }
    match /setups/{document=**}{
    	allow read: if true;
      allow write: if request.auth.uid != null;
    }
    match /notifications/{document=**}{
    	allow read, write: if true;
    }
    match /{document=**} {
      allow read, write: if request.auth.uid != null;
    }
  }
}
```
The project also uses composite indexes, which will be automatically created from the links Firebase provides in errors.

Then you need to enable Firebase Remote Config. The app reads remote flags for features like verified users, premium collections, and dynamic categories. Check `lib/core/firestore/` and the app's Remote Config usage for the current parameter names — the exact list evolves with each release.

You also need to turn on Authentication, Cloud Messaging, and Analytics. To set up Authentication, add your debug signing keys in Firebase (see Firebase Console → Project settings → Your apps).

4. Run `make file-gen` after making changes to models, routes, or DI registrations to regenerate `freezed`, `auto_route`, and `injectable` code.
5. If you've added code that should be tested, add tests.
6. If you've changed APIs, update the documentation.
7. Ensure the test suite passes (`make test`).
8. Make sure your code passes linting (`make analyze`) and formatting (`make format-check`).
9. Issue that pull request!

## Any contributions you make will be under the BSD-3 Software License
In short, when you submit code changes, your submissions are understood to be under the same [BSD-3 License](https://choosealicense.com/licenses/bsd-3-clause/) that covers the project. Feel free to contact the maintainers if that's a concern.

## Report bugs using Github's [issues](https://github.com/Hash-Studios/Prism/issues)
We use GitHub issues to track public bugs. Report a bug by [opening a new issue](https://github.com/Hash-Studios/Prism/issues/new); it's that easy!

## Write bug reports with detail, background, and sample code
**Great Bug Reports** tend to have:

- A quick summary and/or background
- Steps to reproduce
  - Be specific!
  - Give sample code if you can.
- What you expected would happen
- What actually happens
- Notes (possibly including why you think this might be happening, or stuff you tried that didn't work)

People *love* thorough bug reports. We're not even kidding.

## Use a Consistent Coding Style

- Run `make format-check` before submitting a PR (checks Dart formatting)
- Run `make analyze` for static analysis — fix all warnings before submitting
- Run `make test` to ensure all unit and widget tests pass
- Run `make env-guard` to verify that `String.fromEnvironment` calls only appear in `lib/env/env.dart`
- Run `make analytics-check` if you've added or changed analytics events (regenerates and validates the analytics schema)

## License
By contributing, you agree that your contributions will be licensed under its BSD-3 License.
