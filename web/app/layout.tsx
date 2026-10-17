import type { Metadata } from "next";
import { Manrope } from "next/font/google";
import "./globals.css";
import { APP_NAME, OG_IMAGE, SITE_URL } from "@/lib/site-config";

const manrope = Manrope({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title:
    "Prism Wallpapers - Premium Wallpaper App for Android and iOS",
  description:
    "Discover high-quality wallpapers and curated collections with Prism Wallpapers, a premium wallpaper app for Android and iOS. Download on Google Play or the App Store.",
  alternates: {
    canonical: "/",
  },
  icons: {
    icon: "/assets/ios.png",
    shortcut: "/assets/ios.png",
    apple: "/assets/ios.png",
  },
  openGraph: {
    type: "website",
    url: SITE_URL,
    title:
      "Prism Wallpapers - Premium Wallpaper App for Android and iOS",
    description:
      "Discover high-quality wallpapers and curated collections with Prism Wallpapers. Built for personalization lovers on Android and iOS.",
    siteName: APP_NAME,
    images: [OG_IMAGE],
  },
  twitter: {
    card: "summary_large_image",
    title:
      "Prism Wallpapers - Premium Wallpaper App for Android and iOS",
    description:
      "Discover high-quality wallpapers and curated collections with Prism Wallpapers.",
    images: [OG_IMAGE.url],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="bg-neutral-100">
      <body className={`${manrope.variable} bg-neutral-100 text-black antialiased min-h-screen overflow-x-hidden`}>
        {children}
      </body>
    </html>
  );
}
