import QRCode from "qrcode";
import { QrDisclosure } from "./qr-disclosure";

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
    <QrDisclosure className={className}>
        <div
          className="w-[160px] h-[160px] [&_svg]:w-full [&_svg]:h-full"
          dangerouslySetInnerHTML={{ __html: svgString }}
        />
    </QrDisclosure>
  );
}
