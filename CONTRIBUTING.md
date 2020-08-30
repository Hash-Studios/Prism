# Contributing to Prism
We love your input! We want to make contributing to this project as easy and transparent as possible, whether it's:

- Reporting a bug
- Discussing the current state of the code
- Submitting a fix
- Proposing new features
- Becoming a maintainer

## We Develop with Github
We use github to host code, to track issues and feature requests, as well as accept pull requests.

## We Use [Github Flow](https://guides.github.com/introduction/flow/index.html), So All Code Changes Happen Through Pull Requests
Pull requests are the best way to propose changes to the codebase (we use [Github Flow](https://guides.github.com/introduction/flow/index.html)). We actively welcome your pull requests:

1. Fork the repo and create your branch from `master`.
2. You need to create a file called gitkey.dart with the following syntax that stores the Personal Access Token for the GitHub Repository where you want to save your uploaded wallpapers.

[You can follow this tutorial to create token.](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token)
Then you need to create a new repository for storing community wallpapers and remember its name.
You also need to create a Revenuecat account for purchases regarding Prism Premium. You can follow tutorial [here](https://docs.revenuecat.com/docs/welcome). You can skip it entirely, if you don't need premium option in the app.
And last you need pexels API key, to show wallpapers from their site. Request one [here](https://www.pexels.com/api/).
```
const String token = 'github-personal-access-token';
const String gitUserName = 'github-username';
const String repoName = 'wallpapers-repository-name';
const String apiKey = 'revenuecat-payments-api-key';
String pexelApiKey = 'pexels-api-key';
```
3. You also need to create a Firebase project, download the google-services.json to `android/app/` directory. Then enable Cloud Firestore, and create a schema like this -
```
.
├── appConfig
|   └── version
|       ├── currentVersion - '2.4.7'
|       └── versionDesc - 'Version Description separated by ^*^ '
├── setups
|   └── documentID (AutoID)
|       ├── by - 'Designer Name'
|       ├── name - 'Setup Name'
|       ├── email - 'Designer email'
|       ├── desc - 'Setup Description'
|       ├── userPhoto - 'Link of user profile photo'
|       ├── id - 'Wallpaper ID'
|       ├── icon - 'Icon Pack Name'
|       ├── icon_url - 'Play Store Link for Icon Pack'
|       ├── wallpaper_provider - 'Prism'
|       ├── wallpaper_thumb - 'Wallpaper Thumbnail URL (preferrable low quality for easy download)'
|       ├── wallpaper_url - 'Link of Wallpaper'
|       ├── widget - 'Widget Name'
|       ├── widget_url - 'Play Store Link for Widget'
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

<img src="/demo/1.png">
<img src="/demo/2.png">
<img src="/demo/3.png">

4. If you've added code that should be tested, add tests.
5. If you've changed APIs, update the documentation.
6. Ensure the test suite passes.
7. Make sure your code lints.
8. Issue that pull request!

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
* Use DART formatter

## License
By contributing, you agree that your contributions will be licensed under its BSD-3 License.
