import Image from "next/image";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { NAV_LINKS, PLAY_STORE_URL, TESTFLIGHT_COMING_SOON } from "@/lib/site-config";

export function Header() {
  return (
    <header className="sticky top-0 z-50 border-b border-white/10 bg-base-900/85 backdrop-blur-xl">
      <div className="mx-auto flex w-full max-w-6xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
        <a
          href="#top"
          className="inline-flex items-center gap-2 text-sm font-semibold tracking-wide text-white sm:text-base"
        >
          <Image
            src="/assets/ios.png"
            alt="Prism Wallpapers icon"
            width={28}
            height={28}
            className="rounded-lg border border-white/15"
          />
          Prism Wallpapers
        </a>

        <nav className="hidden items-center gap-6 md:flex" aria-label="Primary navigation">
          {NAV_LINKS.map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="text-sm text-white/70 transition hover:text-white"
            >
              {link.label}
            </a>
          ))}
        </nav>

        <div className="flex items-center gap-3">
          {TESTFLIGHT_COMING_SOON ? <Badge subtle>iPhone coming soon</Badge> : null}
          <Button href={PLAY_STORE_URL} className="hidden sm:inline-flex">
            Get it on Google Play
          </Button>
        </div>
      </div>
    </header>
  );
}
