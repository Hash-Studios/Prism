import Image from "next/image";
import { PLAY_STORE_URL } from "@/lib/site-config";

export function Header() {
  return (
    <nav className="fixed w-full top-0 z-40 flex items-center justify-between animate-down transition-all duration-200 bg-transparent p-6">
      <div className="w-[140px] flex items-start">
        <a
          className="relative w-12 h-12 squircle overflow-hidden group cursor-pointer block flex-shrink-0"
          href="/"
          aria-label="Prism Wallpapers"
        >
          {/* Default: foreground icon on accent bg */}
          <div className="absolute -inset-1 flex items-center justify-center transition-opacity duration-300 group-hover:opacity-0">
            <Image
              src="/assets/ic_foreground.png"
              alt=""
              fill
              className="object-cover"
              sizes="48px"
            />
          </div>
          {/* Hover: full app icon */}
          <Image
            src="/assets/ios.png"
            alt="Prism Wallpapers"
            fill
            className="object-cover squircle opacity-0 group-hover:opacity-100 transition-opacity duration-300"
            sizes="48px"
          />
        </a>
      </div>

      <a
        className="flex items-center text-base justify-center font-semibold gap-2 py-2.5 px-4 rounded-xl sm:rounded-3xl transition-all flex-shrink-0 cursor-pointer mx-0.5 bg-accent/10 hover:bg-accent/20 text-accent"
        target="_blank"
        rel="noopener noreferrer"
        href={PLAY_STORE_URL}
      >
        Download
      </a>
    </nav>
  );
}
