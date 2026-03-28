import QRCode from "qrcode";
import { QrCode } from "lucide-react";

interface QrButtonProps {
  url: string;
  className?: string;
}

export async function QrButton({ url, className }: QrButtonProps) {
  const svgString = await QRCode.toString(url, {
    type: "svg",
    width: 180,
    margin: 2,
    color: { dark: "#000000", light: "#ffffff" },
  });

  return (
    <div className="relative inline-block group">
      <button
        type="button"
        className={className}
      >
        <QrCode className="w-5 h-5" />
        Scan QR Code
      </button>

      <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-3 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-50 flex flex-col items-center gap-3 bg-white rounded-2xl shadow-xl p-2 pointer-events-none group-hover:pointer-events-auto">
        <div
          className="w-[160px] h-[160px] [&_svg]:w-full [&_svg]:h-full"
          dangerouslySetInnerHTML={{ __html: svgString }}
        />
      </div>
    </div>
  );
}
