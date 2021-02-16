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

Then you need to create a new repository for storing community wallpapers and remember its name. Then you need to create a new repository for storing community setups and remember its name. Then you need to create a new repository for storing views, and other data and remember its name.

Then you need to get the FCM Server token from Firebase, to push notifications. You can get it from your Firebase project. Open Firebase console, then select your project. Then select Project settings, and in the Cloud Messaging tab, select Server Key. This is the FCM Server Token.

You also need to create a Revenuecat account for purchases regarding Prism Premium. You can follow tutorial [here](https://docs.revenuecat.com/docs/welcome). You can skip it entirely, if you don't need premium option in the app.

And last you need pexels API key, to show wallpapers from their site. Request one [here](https://www.pexels.com/api/).

We are also using 9 images, which are shown to user in onboarding screen. You can put sample image links there, or leave it as it is.
```
const String token = 'github-personal-access-token';
const String gitUserName = 'github-username';
const String repoName = 'wallpapers-repository-name';
const String repoName2 = 'setups-repository-name';
const String repoName3 = 'views-repository-name';
const String apiKey = 'revenuecat-payments-api-key';
String pexelApiKey = 'pexels-api-key';
const String fcmServerToken = 'FCM-server-token';
const String user1Image1 = "";
const String user1Image2 = "";
const String user1Image3 = "";
const String user2Image1 = "";
const String user2Image2 = "";
const String user2Image3 = "";
const String user3Image1 = "";
const String user3Image2 = "";
const String user3Image3 = "";
```
3. You also need to create a Firebase project, download the google-services.json to `android/app/` directory. Then enable Cloud Firestore, and create a schema like this -
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

Then you need to enable Firebase Remote Config, and add these parameters - 
```
Name - bannerTextOn
Description - Top banner text on/off!
Value - true/false

Name - obsoleteVersion
Description - All apps before this version are obsolete!
Value - 2.6.0

Name - latestCategories
Description - Categories for v2.6.3 & above!
Value - [   {     "name": "Community",     "provider": "Prism",     "type": "non-search",     "image": "https://images.pexels.com/photos/3280130/pexels-photo-3280130.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Curated",     "provider": "Pexels",     "type": "non-search",     "image": "https://images.pexels.com/photos/1389460/pexels-photo-1389460.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Popular",     "provider": "WallHaven",     "type": "non-search",     "image": "https://images.pexels.com/photos/3848886/pexels-photo-3848886.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Cyberpunk",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/4904566/pexels-photo-4904566.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Artwork",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/1781710/pexels-photo-1781710.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Nature",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/807598/pexels-photo-807598.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "4K",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/4328961/pexels-photo-4328961.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Minimalism",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/973506/pexels-photo-973506.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Pattern",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/1493226/pexels-photo-1493226.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Blur",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/2888331/pexels-photo-2888331.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Anime",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/1049622/pexels-photo-1049622.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Textures",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/220634/pexels-photo-220634.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Technology",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/1714208/pexels-photo-1714208.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Monochrome",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/301614/pexels-photo-301614.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Fractal",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/5619761/pexels-photo-5619761.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Space",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/1169754/pexels-photo-1169754.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Cars",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/3311574/pexels-photo-3311574.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Animals",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/567540/pexels-photo-567540.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Skyscape",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/66997/pexels-photo-66997.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Neon",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/2917442/pexels-photo-2917442.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Science Fiction",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/4355348/pexels-photo-4355348.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Waves",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/355288/pexels-photo-355288.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Marvel",     "provider": "WallHaven",     "type": "search",     "image": "https://images.pexels.com/photos/4048093/pexels-photo-4048093.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   },   {     "name": "Portrait",     "provider": "Pexels",     "type": "search",     "image": "https://images.pexels.com/photos/3404200/pexels-photo-3404200.jpeg?auto=compress&cs=tinysrgb&dpr=1&h=650&w=940"   }, ]

Name - verifiedUsers
Description - Which users are verified!
Value - ["someuser@gmail.com","someanotheuser@gmail.com",]

Name - bannerURL
Description - Link for the top banner in home
Value - https://t.me/PrismWallpapers

Name - bannerText
Description - Text for the top banner in home
Value - Join us on Telegram

Name - topImageLink
Description - Link for the top banner image in home
Value - https://some.image.link

Name - premiumCollections
Description - Name of the premium collections
Value - ["mesh gradients","dreamy","renders","faces","layers","flow",]

Name - topImageLink
Description - Link for the top banner image in home
Value - https://some.image.link

Name - currentVersion
Description - Current version of the app available to the public
Value - 2.6.4
```
These are demo values, and you can change them whenever you want. We have set the expiry time to be 6 hours, you can change it to whatever you want.
You also need to turn on Authentication, Dynamic Links, Cloud Messaging, Analytics.
And to setup up Authentication, you also need to put your debug signing keys in Firebase, which you can find tutorials on the Internet.

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
