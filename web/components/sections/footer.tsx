import Image from "next/image";
import { GITHUB_URL, PLAY_STORE_URL } from "@/lib/site-config";

const PRIVACY_POLICY_URL = `${GITHUB_URL}/blob/master/PRIVACY.md`;

export function Footer() {
  const year = new Date().getFullYear();

  return (
    <div className="w-full rounded-t-4xl sm:rounded-t-[100px] flex flex-col gap-40 items-center justify-center bg-white/60 border-t-4 border-white pt-10 sm:pt-20 px-12 overflow-hidden">
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
            <h3 className="mb-1 text-base font-semibold text-black">Socials</h3>
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-neutral-400 hover:text-black transition-all"
            >
              GitHub
            </a>
          </div>

          <div className="flex flex-col gap-2">
            <h3 className="mb-1 text-base font-semibold text-black">Legal</h3>
            <a
              href={PRIVACY_POLICY_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-neutral-400 hover:text-black transition-all"
            >
              Privacy
            </a>
            <a
              href={PLAY_STORE_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="text-neutral-400 hover:text-black transition-all"
            >
              Play Store
            </a>
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
