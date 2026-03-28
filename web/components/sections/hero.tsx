import Image from "next/image";
import { QrButton } from "@/components/ui/qr-button";
import { PLAY_STORE_URL } from "@/lib/site-config";

function PlayStoreIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" className="w-5 h-5 flex-shrink-0">
      {/* Google Play kite shape: concave notch on left creates the 4-quadrant look */}
      <polygon points="4,3.5 13,8.5 20.5,12 13,15.5 4,20.5 6,12" />
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
          Download app
        </a>

        <QrButton
          url={PLAY_STORE_URL}
          className="flex items-center text-lg justify-center font-semibold gap-2.5 py-2.5 px-5 rounded-xl sm:rounded-3xl transition-all flex-shrink-0 cursor-pointer mx-0.5 bg-white/60 hover:bg-white text-black border-t-2 border-white shadow-lg shadow-black/5"
        />
      </div>
    </div>
  );
}
