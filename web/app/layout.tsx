import type { Metadata } from "next";
import { Manrope } from "next/font/google";
import "./globals.css";
import { APP_NAME, SITE_URL } from "@/lib/site-config";

const manrope = Manrope({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title:
    "Prism Wallpapers - Premium Android Wallpaper App for Wallpapers, Setups and Collections",
  description:
    "Discover high-quality wallpapers, curated collections, and home screen setups with Prism Wallpapers, a premium wallpaper app for Android. Download on Google Play.",
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
      "Prism Wallpapers - Premium Android Wallpaper App for Wallpapers, Setups and Collections",
    description:
      "Discover high-quality wallpapers, curated collections, and home screen setups with Prism Wallpapers. Built for Android personalization lovers.",
    siteName: APP_NAME,
    images: [
      {
        url: "/assets/screenshots/screen1.jpg",
        width: 390,
        height: 844,
        alt: "Prism Wallpapers app screenshot",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title:
      "Prism Wallpapers - Premium Android Wallpaper App for Wallpapers, Setups and Collections",
    description:
      "Discover high-quality wallpapers, curated collections, and home screen setups with Prism Wallpapers.",
    images: ["/assets/screenshots/screen1.jpg"],
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
