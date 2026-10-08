import Image from "next/image";
import { QrButton } from "@/components/ui/qr-button";
import { APP_STORE_URL, PLAY_STORE_URL } from "@/lib/site-config";

function PlayStoreIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" className="w-5 h-5 flex-shrink-0">
      {/* Google Play kite shape: concave notch on left creates the 4-quadrant look */}
      <polygon points="4,3.5 13,8.5 20.5,12 13,15.5 4,20.5 6,12" />
    </svg>
  );
}


function AppStoreIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true" className="w-5 h-5 flex-shrink-0">
      <path d="M16.37 1.43c0 1.14-.46 2.2-1.2 2.98-.8.85-2.1 1.5-3.14 1.42-.13-1.1.4-2.24 1.15-3 .83-.86 2.2-1.5 3.19-1.4zM20.5 17.1c-.55 1.27-.82 1.84-1.52 2.96-.98 1.57-2.37 3.52-4.08 3.54-1.52.02-1.91-.99-3.97-.98-2.06.01-2.49 1-4.01.99-1.71-.02-3.02-1.78-4-3.35C-.1 15.9-.4 10.7 1.3 8.1c1.2-1.85 3.1-2.93 4.88-2.93 1.81 0 2.95.99 4.45.99 1.45 0 2.34-.99 4.44-.99 1.58 0 3.26.86 4.46 2.35-3.92 2.15-3.28 7.75.97 9.58z" />
    </svg>
  );
}

export function Hero() {
  return (
    <div className="flex flex-col justify-center items-center h-[94vh] animate-up pb-2 px-8">
      <Image
        src="/assets/ios.png"
        alt="Prism Wallpapers app icon"
        width={96}
        height={96}
        className="shadow-xl shadow-base/40 squircle pointer-events-none"
        priority
      />

      <h1 className="mt-12 w-full max-w-xl text-center text-balance leading-[90%] text-6xl sm:text-7xl font-[1000] text-black tracking-tighter">
        Prism your homescreen
      </h1>

      <div className="flex flex-col sm:flex-row gap-2 mt-14">
        <a
          className="flex items-center text-lg justify-center font-semibold gap-2.5 py-2.5 px-5 rounded-xl sm:rounded-3xl transition-all flex-shrink-0 cursor-pointer mx-0.5 bg-accent hover:bg-accent-dark text-white shadow-lg shadow-accent/40 border-t-2 border-white/40"
          target="_blank"
          rel="noopener noreferrer"
          href={PLAY_STORE_URL}
        >
          <PlayStoreIcon />
          Google Play
        </a>

        <a
          className="flex items-center text-lg justify-center font-semibold gap-2.5 py-2.5 px-5 rounded-xl sm:rounded-3xl transition-all flex-shrink-0 cursor-pointer mx-0.5 bg-accent hover:bg-accent-dark text-white shadow-lg shadow-accent/40 border-t-2 border-white/40"
          target="_blank"
          rel="noopener noreferrer"
          href={APP_STORE_URL}
        >
          <AppStoreIcon />
          App Store
        </a>

        <QrButton
          url={PLAY_STORE_URL}
          className="flex items-center text-lg justify-center font-semibold gap-2.5 py-2.5 px-5 rounded-xl sm:rounded-3xl transition-all flex-shrink-0 cursor-pointer mx-0.5 bg-white/60 hover:bg-white text-black border-t-2 border-white shadow-lg shadow-black/5"
        />
      </div>
    </div>
  );
}
