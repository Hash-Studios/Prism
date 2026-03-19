import Image from "next/image";
import { APP_NAME, GITHUB_URL, PLAY_STORE_URL } from "@/lib/site-config";

const PRIVACY_POLICY_URL = `${GITHUB_URL}/blob/master/PRIVACY.md`;

export function Footer() {
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-white/10 py-10">
      <div className="mx-auto flex w-full max-w-6xl flex-col gap-6 px-4 sm:px-6 lg:px-8">
        <div className="flex flex-col justify-between gap-5 sm:flex-row sm:items-center">
          <p className="inline-flex items-center gap-2 text-sm font-semibold text-white">
            <Image
              src="/assets/ios.png"
              alt="Prism Wallpapers icon"
              width={24}
              height={24}
              className="rounded-md border border-white/15"
            />
            {APP_NAME}
          </p>
          <nav className="flex flex-wrap items-center gap-5 text-sm text-white/70">
            <a href={PLAY_STORE_URL} className="transition hover:text-white">
              Play Store
            </a>
            <a href={GITHUB_URL} className="transition hover:text-white">
              GitHub
            </a>
            <a href={PRIVACY_POLICY_URL} className="transition hover:text-white">
              Privacy Policy
            </a>
            <a href="#faq" className="transition hover:text-white">
              FAQ
            </a>
          </nav>
        </div>

        <div className="flex flex-col gap-3 border-t border-white/10 pt-5 text-xs text-white/55 sm:flex-row sm:items-center sm:justify-between">
          <p>{APP_NAME} is open source and built for Android personalization lovers.</p>
          <p>Copyright {year} Hash Studios. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
}
