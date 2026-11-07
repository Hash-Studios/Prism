import type { Metadata } from "next";
import { ContentPage } from "@/components/content-page";
import { APP_NAME, CONTACT_EMAIL, GITHUB_URL, SITE_URL, TELEGRAM_URL, X_URL } from "@/lib/site-config";

const title = `Contact | ${APP_NAME}`;
const description = "Contact the Prism Wallpapers team by email, Telegram, GitHub, or X.";

export const metadata: Metadata = { title, description, alternates: { canonical: "/contact", types: { "text/markdown": "/contact.md" } }, openGraph: { url: `${SITE_URL}/contact`, title, description } };

export default function ContactPage() {
  return <ContentPage title="Contact Prism Wallpapers">
    <p>We welcome questions, feedback, bug reports, partnership notes, and ideas that can make Prism better. Choose the channel that fits your request. For account or purchase questions, include the device platform and a clear description, but do not send passwords, authentication codes, or payment details.</p>
    <h2 className="pt-4 text-2xl font-semibold text-black">Reach the team</h2>
    <ul className="list-disc space-y-3 pl-6">
      <li>Email: <a className="text-accent underline" href={`mailto:${CONTACT_EMAIL}`}>{CONTACT_EMAIL}</a> for direct support and business inquiries.</li>
      <li>Telegram: <a className="text-accent underline" href={TELEGRAM_URL}>Prism Wallpapers community</a> for community discussion and updates.</li>
      <li>GitHub: <a className="text-accent underline" href={GITHUB_URL}>Hash-Studios/Prism</a> for source code, technical issues, and contributions.</li>
      <li>X: <a className="text-accent underline" href={X_URL}>@PrismWallpapers</a> for public announcements and product news.</li>
    </ul>
    <p>For a copyright or content concern, identify the relevant content and explain the issue in your message. We review reports and take appropriate action. Developers can also start with the <a className="text-accent underline" href="/docs">API documentation</a> before writing to us about integration questions.</p>
  </ContentPage>;
}
