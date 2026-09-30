import type { Metadata } from "next";
import { Section } from "@/components/legal/section";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { APP_NAME, EFFECTIVE_DATE, SITE_URL } from "@/lib/site-config";

const CONTACT_EMAIL = "hash.studios.inc+prism@gmail.com";

const title = `Privacy Policy | ${APP_NAME}`;
const description = `How Hash Studios collects, uses, and protects your information in ${APP_NAME}.`;

export const metadata: Metadata = {
  title,
  description,
  alternates: {
    canonical: "/privacy",
  },
  openGraph: {
    url: `${SITE_URL}/privacy`,
    title,
    description,
  },
  twitter: {
    card: "summary",
    title,
    description,
  },
};

function SubSection({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <div className="mt-4">
      <h3 className="text-base font-semibold text-black">{heading}</h3>
      <div className="mt-2 space-y-2">{children}</div>
    </div>
  );
}

const PROVIDERS: Array<{ name: string; purpose: string; href: string; label: string }> = [
  {
    name: "Google Sign-In / Firebase Auth",
    purpose: "Authentication",
    href: "https://policies.google.com/privacy",
    label: "policies.google.com/privacy",
  },
  {
    name: "Firebase Analytics",
    purpose: "App usage analytics",
    href: "https://firebase.google.com/policies/analytics",
    label: "firebase.google.com/policies/analytics",
  },
  {
    name: "Cloud Firestore",
    purpose: "User data and content storage",
    href: "https://firebase.google.com/support/privacy",
    label: "firebase.google.com/support/privacy",
  },
  {
    name: "Firebase Storage",
    purpose: "Image and file storage",
    href: "https://firebase.google.com/support/privacy",
    label: "firebase.google.com/support/privacy",
  },
  {
    name: "Firebase Remote Config",
    purpose: "Feature flags and configuration",
    href: "https://firebase.google.com/support/privacy",
    label: "firebase.google.com/support/privacy",
  },
  {
    name: "Firebase Cloud Messaging",
    purpose: "Push notifications",
    href: "https://firebase.google.com/support/privacy",
    label: "firebase.google.com/support/privacy",
  },
  {
    name: "Firebase In-App Messaging",
    purpose: "In-app messages and announcements",
    href: "https://firebase.google.com/support/privacy",
    label: "firebase.google.com/support/privacy",
  },
  {
    name: "Sentry",
    purpose: "Crash reporting and error monitoring (includes session replay for debug purposes)",
    href: "https://sentry.io/privacy",
    label: "sentry.io/privacy",
  },
  {
    name: "Mixpanel",
    purpose: "Product analytics and event tracking",
    href: "https://mixpanel.com/legal/privacy-policy",
    label: "mixpanel.com/legal/privacy-policy",
  },
  {
    name: "RevenueCat",
    purpose: "Subscription management and purchase validation",
    href: "https://www.revenuecat.com/privacy",
    label: "revenuecat.com/privacy",
  },
  {
    name: "Google Mobile Ads",
    purpose: "Advertising (free tier)",
    href: "https://policies.google.com/privacy",
    label: "policies.google.com/privacy",
  },
  {
    name: "Pexels API",
    purpose: "Curated wallpaper content",
    href: "https://www.pexels.com/privacy-policy",
    label: "pexels.com/privacy-policy",
  },
  {
    name: "WallHaven API",
    purpose: "Curated wallpaper content (safe tier by default)",
    href: "https://wallhaven.cc/help/privacy",
    label: "wallhaven.cc/help/privacy",
  },
];

export default function PrivacyPage() {
  return (
    <>
      <Header />

      <main className="min-h-screen bg-neutral-100 pt-32 pb-24">
        <div className="mx-auto w-full max-w-3xl px-4 sm:px-6 lg:px-8">
          <h1 className="text-3xl font-bold tracking-tight text-black sm:text-4xl">
            Privacy Policy
          </h1>
          <p className="mt-3 text-neutral-500">Effective date: {EFFECTIVE_DATE}</p>
          <p className="mt-6 text-neutral-600 leading-relaxed">
            Hash Studios built the {APP_NAME} app as an open source app. This service is provided
            by Hash Studios at no cost and is intended for use as-is.
          </p>
          <p className="mt-3 text-neutral-600 leading-relaxed">
            This page informs visitors regarding our policies for the collection, use, and
            disclosure of personal information for anyone who uses our service. If you choose to
            use our service, you agree to the collection and use of information in relation to
            this policy. The personal information that we collect is used for providing and
            improving the service. We will not use or share your information with anyone except
            as described in this Privacy Policy.
          </p>

          <Section heading="Information We Collect">
            <SubSection heading="When You Use the App Without Signing In">
              <p>
                On iOS, you can browse and buy without creating an account. On Android, sign-in is
                required. When you use {APP_NAME} without signing in, we collect:
              </p>
              <ul className="list-disc space-y-1 pl-5">
                <li>
                  <strong className="text-black">Usage and analytics data</strong> - app
                  interactions, screens visited, features used (via Firebase Analytics and
                  Mixpanel)
                </li>
                <li>
                  <strong className="text-black">Crash reports and diagnostic data</strong> -
                  error logs and device information (via Sentry)
                </li>
                <li>
                  <strong className="text-black">Ad identifiers</strong> - anonymous advertising
                  ID used to serve relevant ads (via Google Mobile Ads)
                </li>
                <li>
                  <strong className="text-black">Device information</strong> - device model, OS
                  version, IP address (collected automatically by analytics and crash SDKs)
                </li>
              </ul>
            </SubSection>

            <SubSection heading="When You Sign In">
              <p>
                When you create an account using Google Sign-In or Sign in with Apple, we
                additionally collect:
              </p>
              <ul className="list-disc space-y-1 pl-5">
                <li>
                  <strong className="text-black">Name and email address</strong> - from your
                  Google or Apple account
                </li>
                <li>
                  <strong className="text-black">Profile photo</strong> - from your Google account
                  (if using Google Sign-In)
                </li>
                <li>
                  <strong className="text-black">User ID</strong> - a unique identifier assigned
                  to your account in Firebase
                </li>
              </ul>
            </SubSection>

            <SubSection heading="Content You Create">
              <p>When you use community features, we collect:</p>
              <ul className="list-disc space-y-1 pl-5">
                <li>
                  <strong className="text-black">Uploaded wallpapers and home screen setups</strong>{" "}
                  - stored in Firebase Storage and Firestore
                </li>
                <li>
                  <strong className="text-black">Profile information</strong> - username, bio,
                  profile photo, cover photo, and social links you add
                </li>
                <li>
                  <strong className="text-black">Favourites</strong> - wallpapers and setups you
                  mark as favourites
                </li>
                <li>
                  <strong className="text-black">AI-generated wallpapers</strong> - prompts you
                  submit and images generated
                </li>
              </ul>
            </SubSection>

            <SubSection heading="Purchase Information">
              <p>If you purchase a subscription or lifetime access:</p>
              <ul className="list-disc space-y-1 pl-5">
                <li>
                  <strong className="text-black">Purchase history and entitlement status</strong>{" "}
                  - managed by RevenueCat and Apple&apos;s StoreKit
                </li>
              </ul>
            </SubSection>
          </Section>

          <Section heading="How We Use Your Information">
            <p>We use the information we collect to:</p>
            <ul className="list-disc space-y-1 pl-5">
              <li>Provide, maintain, and improve the app</li>
              <li>Authenticate you and manage your account</li>
              <li>Sync your favourites and profile across devices</li>
              <li>Serve relevant advertisements (free tier only)</li>
              <li>Process in-app purchases and verify subscription entitlements</li>
              <li>Monitor for crashes and technical errors</li>
              <li>Understand how features are used and improve the user experience</li>
              <li>Send push notifications for activity on your posts (if you grant permission)</li>
            </ul>
          </Section>

          <Section heading="Third-Party Service Providers">
            <p>
              We use the following third-party services. Each has access only to the data
              necessary to perform their function. We require them to uphold the same level of
              data protection as this policy.
            </p>
            <div className="mt-2 overflow-x-auto rounded-2xl border border-neutral-200 bg-white">
              <table className="w-full min-w-[560px] text-left text-sm">
                <thead>
                  <tr className="border-b border-neutral-200">
                    <th className="px-4 py-3 font-semibold text-black">Service</th>
                    <th className="px-4 py-3 font-semibold text-black">Purpose</th>
                    <th className="px-4 py-3 font-semibold text-black">Privacy Policy</th>
                  </tr>
                </thead>
                <tbody>
                  {PROVIDERS.map((provider) => (
                    <tr key={provider.name} className="border-b border-neutral-100 last:border-b-0">
                      <td className="px-4 py-3 align-top text-neutral-600">{provider.name}</td>
                      <td className="px-4 py-3 align-top text-neutral-600">{provider.purpose}</td>
                      <td className="px-4 py-3 align-top">
                        <a
                          href={provider.href}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="text-accent underline"
                        >
                          {provider.label}
                        </a>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Section>

          <Section heading="Data Retention">
            <ul className="list-disc space-y-1 pl-5">
              <li>
                <strong className="text-black">Account data</strong> - retained while your account
                is active. Deleted within 30 days of an account deletion request.
              </li>
              <li>
                <strong className="text-black">Analytics data</strong> - retained according to
                each provider&apos;s retention policies (typically 14 months for Firebase
                Analytics, 5 years for Mixpanel).
              </li>
              <li>
                <strong className="text-black">Crash logs</strong> - retained for 90 days in
                Sentry.
              </li>
              <li>
                <strong className="text-black">Uploaded content</strong> - retained until you
                delete it or request account deletion.
              </li>
              <li>
                <strong className="text-black">Purchase history</strong> - retained by RevenueCat
                and Apple as required for financial record-keeping.
              </li>
            </ul>
          </Section>

          <Section heading="Your Rights and Choices">
            <SubSection heading="Accessing and Deleting Your Data">
              <p>
                You can request deletion of your account and associated data at any time by
                contacting us at{" "}
                <a href={`mailto:${CONTACT_EMAIL}`} className="text-accent underline">
                  {CONTACT_EMAIL}
                </a>
                . We will delete your account data within 30 days. Note that some data held by
                third-party providers (e.g. Apple purchase history) is outside our control and
                subject to their own retention policies.
              </p>
            </SubSection>

            <SubSection heading="Revoking Consent">
              <ul className="list-disc space-y-1 pl-5">
                <li>
                  <strong className="text-black">Analytics opt-out</strong> - You can limit ad
                  tracking through your device&apos;s privacy settings (iOS: Settings → Privacy
                  &amp; Security → Tracking).
                </li>
                <li>
                  <strong className="text-black">Push notifications</strong> - You can disable
                  push notifications at any time in your device settings.
                </li>
                <li>
                  <strong className="text-black">Sign out</strong> - You can sign out of your
                  account at any time within the app. This stops further syncing of personal data.
                </li>
              </ul>
            </SubSection>
          </Section>

          <Section heading="Cookies">
            <p>
              This app does not use cookies directly. However, some third-party SDKs (such as
              analytics and advertising libraries) may use local storage or device identifiers
              with similar functionality. You can limit this through your device&apos;s
              advertising settings.
            </p>
          </Section>

          <Section heading="Children's Privacy">
            <p>
              This service does not knowingly collect personal information from children under
              13. If you are a parent or guardian and believe your child has provided us with
              personal information, please contact us at{" "}
              <a href={`mailto:${CONTACT_EMAIL}`} className="text-accent underline">
                {CONTACT_EMAIL}
              </a>{" "}
              and we will delete it promptly.
            </p>
          </Section>

          <Section heading="Security">
            <p>
              We value your trust and strive to use commercially acceptable means to protect your
              personal information. However, no method of transmission over the internet or
              electronic storage is 100% secure. We cannot guarantee absolute security.
            </p>
          </Section>

          <Section heading="Links to Other Sites">
            <p>
              The app may contain links to external sites. These are not operated by us. We
              strongly advise reviewing the privacy policies of any third-party sites you visit.
            </p>
          </Section>

          <Section heading="Changes to This Privacy Policy">
            <p>
              We may update this Privacy Policy from time to time. Changes will be posted on this
              page with an updated effective date. Continued use of the app after changes
              constitutes acceptance of the updated policy.
            </p>
          </Section>

          <Section heading="Contact Us">
            <p>
              If you have questions or requests regarding this Privacy Policy, contact us at:
            </p>
            <p>
              <strong className="text-black">Email:</strong>{" "}
              <a href={`mailto:${CONTACT_EMAIL}`} className="text-accent underline">
                {CONTACT_EMAIL}
              </a>
              <br />
              <strong className="text-black">Website:</strong> {SITE_URL}
            </p>
          </Section>
        </div>
      </main>

      <Footer />
    </>
  );
}
