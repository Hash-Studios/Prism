import Image from "next/image";
import { APP_STORE_URL, GITHUB_URL, PLAY_STORE_URL, TELEGRAM_URL, X_URL } from "@/lib/site-config";
import { cn } from "@/lib/utils";

/** `adaptive` follows the dark colour scheme. Only pages that style their own body for dark mode pass it. */
export function Footer({ adaptive = false }: { adaptive?: boolean }) {
  const year = new Date().getFullYear();

  return (
    <div
      className={cn(
        "w-full rounded-t-4xl sm:rounded-t-[100px] flex flex-col gap-40 items-center justify-center bg-white/60 border-t-4 border-white pt-10 sm:pt-20 px-12 overflow-hidden",
        adaptive && "dark:bg-base-850 dark:border-white/5 [&_h3:not(.select-none)]:dark:text-white [&_h3.select-none]:dark:text-white/5 [&_a]:dark:text-neutral-400 [&_a:hover]:dark:text-white",
      )}
    >
      <div className="flex sm:flex-row flex-col sm:justify-between justify-start sm:gap-0 gap-10 w-full max-w-7xl relative z-10">
        <div className="flex flex-col gap-10">
          <Image
            src="/assets/ios.png"
            alt="Prism Wallpapers icon"
            width={48}
            height={48}
            className="squircle"
          />
          <p className="text-neutral-400">© {year} Hash Studios.</p>
        </div>

        <div className="flex gap-24">
          <div className="flex flex-col gap-2">
            <h3 className="mb-1 text-base font-semibold text-black">Company</h3>
            <a href="/about" className="text-neutral-400 hover:text-black transition-all">About</a>
            <a href="/contact" className="text-neutral-400 hover:text-black transition-all">Contact</a>
            <a href="/docs" className="text-neutral-400 hover:text-black transition-all">Docs</a>
            <a href="/developers" className="text-neutral-400 hover:text-black transition-all">Developers</a>
            <a href="/mcp" className="text-neutral-400 hover:text-black transition-all">MCP</a>
          </div>
          <div className="flex flex-col gap-2">
            <h3 className="mb-1 text-base font-semibold text-black">Socials</h3>
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-neutral-400 hover:text-black transition-all"
            >
              GitHub
            </a>
            <a
              href={TELEGRAM_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-neutral-400 hover:text-black transition-all"
            >
              Telegram
            </a>
            <a
              href={X_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-neutral-400 hover:text-black transition-all"
            >
              X (Twitter)
            </a>
          </div>

          <div className="flex flex-col gap-2">
            <h3 className="mb-1 text-base font-semibold text-black">Legal</h3>
            <a href="/changelog" className="text-neutral-400 hover:text-black transition-all">
              Changelog
            </a>
            <a href="/privacy" className="text-neutral-400 hover:text-black transition-all">
              Privacy
            </a>
            <a href="/terms" className="text-neutral-400 hover:text-black transition-all">
              Terms
            </a>
            <a
              href={PLAY_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-neutral-400 hover:text-black transition-all"
            >
              Play Store
            </a>
            <a
              href={APP_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-neutral-400 hover:text-black transition-all"
            >
              App Store
            </a>
            <a href="/download" className="text-neutral-400 hover:text-black transition-all">Download</a>
          </div>
        </div>
      </div>

      <h3
        className="whitespace-nowrap text-neutral-300/50 -ml-20 sm:-ml-40 font-black select-none"
        style={{
          fontSize: "clamp(5rem, 55vw, 120vw)",
          letterSpacing: "-0.08em",
          lineHeight: "0.5",
        }}
      >
        Prism
      </h3>
    </div>
  );
}
