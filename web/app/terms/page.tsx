import type { Metadata } from "next";
import { Footer } from "@/components/sections/footer";
import { Header } from "@/components/sections/header";
import { APP_NAME, SITE_URL } from "@/lib/site-config";

const CONTACT_EMAIL = "hash.studios.inc@gmail.com";
const EFFECTIVE_DATE = "2026-09-28";

const title = `Terms of Use | ${APP_NAME}`;
const description = `The Terms of Use (EULA) for ${APP_NAME} by Hash Studios, covering accounts, content, purchases and Prism Coins.`;

export const metadata: Metadata = {
  title,
  description,
  alternates: {
    canonical: "/terms",
  },
  openGraph: {
    url: `${SITE_URL}/terms`,
    title,
    description,
  },
  twitter: {
    card: "summary",
    title,
    description,
  },
};

function Section({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <section className="mt-10">
      <h2 className="text-xl font-semibold text-black">{heading}</h2>
      <div className="mt-2 space-y-3 text-neutral-600 leading-relaxed">{children}</div>
    </section>
  );
}

export default function TermsPage() {
  return (
    <>
      <Header />

      <main className="min-h-screen bg-neutral-100 pt-32 pb-24">
        <div className="mx-auto w-full max-w-3xl px-4 sm:px-6 lg:px-8">
          <h1 className="text-3xl font-bold tracking-tight text-black sm:text-4xl">Terms of Use</h1>
          <p className="mt-3 text-neutral-500">Effective date: {EFFECTIVE_DATE}</p>
          <p className="mt-6 text-neutral-600 leading-relaxed">
            These Terms of Use (&quot;Terms&quot;) are an agreement between you and Hash Studios
            (&quot;Hash Studios&quot;, &quot;we&quot;, &quot;us&quot;) for the use of the {APP_NAME}{" "}
            app (&quot;Prism&quot;, the &quot;app&quot;). By downloading, installing or using Prism,
            you agree to these Terms. If you do not agree, do not use the app.
          </p>

          <Section heading="1. Acceptance of these Terms">
            <p>
              You must be old enough to use Prism under the laws of your country. If you are using
              Prism on behalf of yourself, you confirm you have read, understood and accepted these
              Terms and our Privacy Policy.
            </p>
          </Section>

          <Section heading="2. Accounts">
            <p>
              On iOS, an account is optional. You can browse and buy without signing in. On Android,
              you need to sign in to use the app. Where an account is used, you sign in with Google
              or with Sign in with Apple. You are responsible for the activity on your account and
              for keeping your device secure.
            </p>
          </Section>

          <Section heading="3. Your content">
            <p>
              You keep ownership of the wallpapers, setups, profile details and other content you
              upload (&quot;your content&quot;). By uploading, you give Hash Studios a worldwide,
              royalty-free licence to host, store, display, distribute and promote your content
              inside Prism, so other users can see and use it as the app is designed to work.
            </p>
            <p>
              You are responsible for your content. You confirm you own it, or have the right to
              share it, and that it does not infringe anyone else&apos;s rights.
            </p>
          </Section>

          <Section heading="4. Zero tolerance for objectionable content and abusive users">
            <p>
              Prism has zero tolerance for objectionable content and abusive users. This includes
              content that is illegal, hateful, sexually explicit, violent, harassing, or that
              targets a person or group. We remove content that breaks this rule and eject users who
              post it, including by suspending or terminating their account.
            </p>
            <p>
              We review reports of objectionable content or abusive behaviour within 24 hours of
              receiving them.
            </p>
          </Section>

          <Section heading="5. Reporting and blocking">
            <p>
              You can report a wallpaper, setup, profile or comment directly in the app. You can
              also block another user so you no longer see their content or messages. We act on
              reports as described above.
            </p>
          </Section>

          <Section heading="6. Prohibited conduct">
            <p>When using Prism, you agree not to:</p>
            <ul className="list-disc space-y-1 pl-5">
              <li>Upload content you do not have the rights to share.</li>
              <li>Harass, threaten, impersonate or abuse other users.</li>
              <li>Upload illegal, hateful, sexually explicit or violent content.</li>
              <li>Attempt to bypass, exploit or interfere with the app, its coins or purchases.</li>
              <li>Use Prism for spam, scraping or any automated, unauthorised access.</li>
            </ul>
          </Section>

          <Section heading="7. Copyright and takedown requests">
            <p>
              If you believe content on Prism infringes your copyright or other intellectual
              property rights, contact us at{" "}
              <a href={`mailto:${CONTACT_EMAIL}`} className="text-accent underline">
                {CONTACT_EMAIL}
              </a>{" "}
              with a description of the content, its location in the app, and proof of your rights.
              We review takedown requests and remove infringing content we confirm.
            </p>
          </Section>

          <Section heading="8. Purchases and subscriptions">
            <p>
              Subscriptions and other in-app purchases are billed by Apple or Google, depending on
              where you downloaded Prism. Payment is charged to the account you used to buy the app
              store item. Manage or cancel a subscription in your Apple ID or Google Play account
              settings, not in Prism. If you switch devices or reinstall the app, use the
              &quot;Restore Purchases&quot; option to bring back a purchase already tied to your
              store account.
            </p>
          </Section>

          <Section heading="9. Prism Coins">
            <p>
              Prism Coins are an in-app reward you earn through activity in Prism. Coins have no
              cash value, cannot be exchanged for money, and cannot be bought, sold or transferred
              between accounts. We may adjust how coins are earned or spent at any time.
            </p>
          </Section>

          <Section heading="10. Termination">
            <p>
              We may suspend or terminate your access to Prism, including for breaking these Terms,
              posting objectionable content, or abusing other users. You can stop using Prism and
              delete your account at any time from the app&apos;s settings.
            </p>
          </Section>

          <Section heading="11. Disclaimers">
            <p>
              Prism is provided &quot;as is&quot; and &quot;as available&quot;, without warranties of
              any kind. We do not guarantee the app will be uninterrupted, error-free, or that any
              content in it is accurate or suitable for your purpose.
            </p>
          </Section>

          <Section heading="12. Limitation of liability">
            <p>
              To the extent allowed by law, Hash Studios is not liable for indirect, incidental or
              consequential damages arising from your use of Prism. Our total liability for any
              claim relating to the app is limited to the amount you paid us, if any, in the 12
              months before the claim.
            </p>
          </Section>

          <Section heading="13. Changes to these Terms">
            <p>
              We may update these Terms from time to time. We will change the effective date above
              when we do. Continuing to use Prism after a change means you accept the updated Terms.
            </p>
          </Section>

          <Section heading="14. Apple App Store purchases">
            <p>
              If you downloaded Prism from the Apple App Store, Apple&apos;s standard End User
              Licence Agreement also applies to your use of the app, in addition to these Terms. You
              can read it at{" "}
              <a
                href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
                target="_blank"
                rel="noopener noreferrer"
                className="text-accent underline"
              >
                apple.com/legal/internet-services/itunes/dev/stdeula
              </a>
              .
            </p>
          </Section>

          <Section heading="15. Contact">
            <p>
              Questions about these Terms? Email us at{" "}
              <a href={`mailto:${CONTACT_EMAIL}`} className="text-accent underline">
                {CONTACT_EMAIL}
              </a>
              .
            </p>
          </Section>
        </div>
      </main>

      <Footer />
    </>
  );
}
