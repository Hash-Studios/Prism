import { Github } from "lucide-react";
import { PlayStoreLink } from "@/components/download/apk-release-card";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { TopicLinks } from "@/components/seo/topic-links";
import { seoMetadata } from "@/lib/seo-pages";
import { GITHUB_URL, PLAY_STORE_URL } from "@/lib/site-config";

export const metadata = seoMetadata("open-source-android-wallpaper-app");

const link =
  "font-semibold text-neutral-800 underline decoration-accent underline-offset-4 hover:decoration-current dark:text-accent";
const heading = "text-2xl font-bold tracking-tight text-black sm:text-3xl dark:text-white";
const body = "leading-relaxed text-neutral-600 dark:text-neutral-300";

const facts: Array<[string, React.ReactNode]> = [
  [
    "Licence",
    <>
      <a href={`${GITHUB_URL}/blob/master/LICENSE.txt`} className={link}>
        BSD 3-Clause
      </a>
      , for the source code
    </>,
  ],
  ["Price", "Free to download. Prism Pro is optional."],
  ["Get it", "Google Play, or the APK from GitHub Releases"],
  ["Built with", "Flutter and Dart, with Firebase"],
];

const features = [
  "Browse wallpapers and collections, and search by word, colour or tag.",
  "Save the wallpapers you like as favourites.",
  "Set a wallpaper on the home screen, the lock screen, or both.",
  "Switch the app to a black AMOLED theme.",
];

const repository = [
  "The Flutter app for Android and iOS",
  "Cloud Functions in TypeScript",
  "Firestore security rules",
  "This website",
];

export default function OpenSourceAppPage() {
  return (
    <>
      <Header surface="light" />

      <main className="min-h-screen bg-neutral-100 pb-24 pt-32 dark:bg-base-900">
        <div className="mx-auto w-full max-w-5xl px-4 sm:px-6 lg:px-8">
          <div className="max-w-3xl">
            <h1 className="text-balance text-4xl font-bold tracking-tight text-black sm:text-5xl dark:text-white">
              An open-source wallpaper app for Android
            </h1>
            <p className="mt-5 text-pretty text-lg leading-relaxed text-neutral-600 dark:text-neutral-300">
              Prism&apos;s code is public on GitHub under the BSD 3-Clause licence. The app is free to download from Google
              Play, and Prism Pro is an optional subscription.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <PlayStoreLink href={PLAY_STORE_URL} />
              <a
                href={GITHUB_URL}
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex min-h-12 items-center justify-center gap-2.5 rounded-2xl border border-neutral-300 bg-white px-5 py-3 text-base font-semibold text-black transition-colors hover:bg-neutral-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent dark:border-white/15 dark:bg-white/5 dark:text-white dark:hover:bg-white/10"
              >
                <Github aria-hidden="true" className="size-5 shrink-0" strokeWidth={1.75} />
                Source on GitHub
              </a>
            </div>
            <p className="mt-4 text-sm text-neutral-600 dark:text-neutral-400">
              No Play Store?{" "}
              <a href="/download" className={link}>
                Download the APK
              </a>
            </p>
          </div>

          <dl className="mt-14 grid gap-px overflow-hidden rounded-3xl border border-neutral-200 bg-neutral-200 sm:grid-cols-2 dark:border-white/10 dark:bg-white/10">
            {facts.map(([term, detail]) => (
              <div key={term} className="bg-white p-5 dark:bg-base-850">
                <dt className="text-sm text-neutral-600 dark:text-neutral-400">{term}</dt>
                <dd className="mt-1 text-base text-black dark:text-white">{detail}</dd>
              </div>
            ))}
          </dl>

          <section aria-labelledby="features-heading" className="mt-20">
            <h2 id="features-heading" className={heading}>
              What you can do in Prism
            </h2>
            <ul className="mt-6 grid max-w-3xl gap-3">
              {features.map((feature) => (
                <li key={feature} className={`flex gap-3 ${body}`}>
                  <span aria-hidden="true" className="mt-2.5 size-1.5 shrink-0 rounded-full bg-accent" />
                  <span>{feature}</span>
                </li>
              ))}
            </ul>
            <p className={`mt-4 max-w-3xl ${body}`}>
              The black theme pairs well with{" "}
              <a href="/amoled-wallpapers" className={link}>
                AMOLED wallpapers
              </a>
              .
            </p>

            <div className="mt-10 flex flex-wrap items-start gap-x-10 gap-y-8">
              <figure className="w-full max-w-[400px] md:w-[400px]">
                <img
                  src="/assets/screenshots/android-set-wallpaper-sheet.webp"
                  width={506}
                  height={315}
                  alt="Prism's set-wallpaper sheet with Home screen, Lock screen and Both"
                  loading="lazy"
                  decoding="async"
                  className="h-auto w-full rounded-[5.6%/9%] shadow-sm ring-1 ring-black/5 dark:ring-white/10"
                />
                <figcaption className="mt-3 text-xs leading-relaxed text-neutral-600 dark:text-neutral-400">
                  Set the home screen, lock screen, or both. Android app capture, October 2026.
                </figcaption>
              </figure>
              <figure className="w-[220px] max-w-full">
                <img
                  src="/assets/screenshots/themes-iphone.jpg"
                  width={440}
                  height={956}
                  alt="Prism's Themes screen, with AMOLED listed under Dark Themes"
                  loading="lazy"
                  decoding="async"
                  className="h-auto w-full rounded-[28px] shadow-sm ring-1 ring-black/5 dark:ring-white/10"
                />
                <figcaption className="mt-3 text-xs leading-relaxed text-neutral-600 dark:text-neutral-400">
                  The Themes screen, captured on iPhone. Android shows the same screen.
                </figcaption>
              </figure>
            </div>
          </section>

          <section aria-labelledby="pro-heading" className="mt-20 max-w-3xl">
            <h2 id="pro-heading" className={heading}>
              Free, with an optional Pro
            </h2>
            <p className={`mt-4 ${body}`}>
              Prism is free to download. After the free plan’s introductory downloads, downloads use Prism Coins, which you can earn in the app.
              Prism Pro is a subscription. It adds premium wallpapers and collections, makes
              downloads and premium filters free, and unlocks auto-rotate on Android.
            </p>
          </section>

          <section aria-labelledby="licence-heading" className="mt-20 max-w-3xl">
            <h2 id="licence-heading" className={heading}>
              What the licence covers
            </h2>
            <p className={`mt-4 ${body}`}>
              The BSD 3-Clause licence covers Prism&apos;s source code. It does not cover the wallpapers in the app. Those
              belong to their creators.
            </p>
          </section>

          <section aria-labelledby="repo-heading" className="mt-20 max-w-3xl">
            <h2 id="repo-heading" className={heading}>
              What is in the repository
            </h2>
            <ul className="mt-6 grid gap-3">
              {repository.map((item) => (
                <li key={item} className={`flex gap-3 ${body}`}>
                  <span aria-hidden="true" className="mt-2.5 size-1.5 shrink-0 rounded-full bg-accent" />
                  <span>{item}</span>
                </li>
              ))}
            </ul>
            <p className={`mt-6 ${body}`}>
              To report a bug or send a change, read the{" "}
              <a href={`${GITHUB_URL}/blob/master/CONTRIBUTING.md`} className={link}>
                contributing guide
              </a>
              . Release notes are on{" "}
              <a href={`${GITHUB_URL}/releases`} className={link}>
                GitHub Releases
              </a>{" "}
              and in the{" "}
              <a href="/changelog" className={link}>
                changelog
              </a>
              .
            </p>
          </section>

          <section aria-labelledby="more-heading" className="mt-20 text-black dark:text-white">
            <h2 id="more-heading" className="text-xl font-bold tracking-tight">
              More from Prism
            </h2>
            <TopicLinks current="open-source-android-wallpaper-app" />
          </section>
        </div>
      </main>

      <div className="dark:bg-base-900">
        <Footer adaptive />
      </div>
    </>
  );
}
