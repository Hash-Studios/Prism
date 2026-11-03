import type { Metadata } from "next";
import { ApkDownloadLink, ApkReleaseDetails, PlayStoreLink } from "@/components/download/apk-release-card";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { APP_NAME, OG_IMAGE, PLAY_STORE_URL, SITE_URL } from "@/lib/site-config";

const title = `Download Prism for Android | ${APP_NAME}`;
const description =
  "Get Prism on Google Play, or download the APK. The APK is the same app, signed by Google Play, with its SHA-256 for checking.";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: "/download" },
  openGraph: { url: `${SITE_URL}/download`, title, description, images: [OG_IMAGE] },
  twitter: { card: "summary", title, description },
};

const steps = [
  "Download the APK on your Android phone.",
  "Open the file from your downloads or notifications.",
  "If Android asks, turn on Install unknown apps for your browser or file app, then go back.",
  "Tap Install. To update later, install the new APK over this one. Your settings stay.",
];

export default function DownloadPage() {
  return (
    <>
      <Header />

      <main className="min-h-screen bg-neutral-100 pt-32 pb-24 dark:bg-base-900">
        <div className="mx-auto w-full max-w-2xl px-4 sm:px-6">
          <h1 className="text-balance text-4xl font-bold tracking-tight text-black sm:text-5xl dark:text-white">
            Get Prism for Android
          </h1>
          <p className="mt-4 max-w-xl text-pretty text-lg leading-relaxed text-neutral-600 dark:text-neutral-300">
            Google Play is the easiest way to install Prism and keep it up to date. No Play Store on your phone? Download
            the APK. It is the same app, signed by Google Play.
          </p>

          <div className="mt-8 flex flex-col gap-3 sm:flex-row">
            <PlayStoreLink href={PLAY_STORE_URL} />
            <ApkDownloadLink />
          </div>

          <div className="mt-12 grid gap-6">
            <ApkReleaseDetails />

            <section aria-labelledby="install-heading" className="px-1">
              <h2 id="install-heading" className="text-lg font-semibold text-black dark:text-white">
                Install the APK
              </h2>
              <ol className="mt-4 grid gap-3">
                {steps.map((step, index) => (
                  <li key={step} className="flex gap-3 leading-relaxed text-neutral-600 dark:text-neutral-300">
                    <span
                      aria-hidden="true"
                      className="mt-0.5 grid size-6 shrink-0 place-items-center rounded-full bg-accent/10 text-sm font-semibold tabular-nums text-accent"
                    >
                      {index + 1}
                    </span>
                    <span>{step}</span>
                  </li>
                ))}
              </ol>
              <p className="mt-4 text-sm leading-relaxed text-neutral-500 dark:text-neutral-400">
                To check the file on a computer, run <code className="font-mono">sha256sum</code> on it and compare the
                result with the SHA-256 above.
              </p>
            </section>

            <section
              aria-labelledby="play-services-heading"
              className="rounded-3xl border border-amber-300/60 bg-amber-50 p-5 sm:p-6 dark:border-amber-300/20 dark:bg-amber-300/10"
            >
              <h2 id="play-services-heading" className="text-lg font-semibold text-black dark:text-white">
                Without Google Play services
              </h2>
              <p className="mt-2 leading-relaxed text-neutral-700 dark:text-neutral-300">
                Sign-in, Prism Premium and notifications need Google Play services. Without them, Prism still opens, and
                you can browse and set wallpapers.
              </p>
            </section>
          </div>
        </div>
      </main>

      <div className="dark:bg-base-900">
        <Footer adaptive />
      </div>
    </>
  );
}
