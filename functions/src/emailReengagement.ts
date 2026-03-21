import * as admin from "firebase-admin";
import {logger} from "firebase-functions/v2";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const MAIL_COLLECTION = "mail";
const FROM_EMAIL = "Prism Wallpapers <noreply@prismwalls.com>";
const UNSUBSCRIBE_BASE = "https://prismwalls.com/unsubscribe";
const REENGAGEMENT_WEB_BASE = "https://prismwalls.com/reengagement";

export interface ReengagementEmailParams {
  userId: string;
  email: string;
  sequence: number;
  segment: string;
}

/**
 * Queues a re-engagement email by writing to the `mail` Firestore collection.
 *
 * This relies on the Firebase Extension "Trigger Email" (firestore-send-email)
 * being installed and configured with a SendGrid / Mailgun transport.
 *
 * Each email includes:
 *   - RFC 8058 one-click List-Unsubscribe headers
 *   - A base64url unsubscribe token tied to the userId
 *   - A deep-link CTA to open the AI tab inside the app
 *   - Metadata fields for reporting and suppression tracking
 */
export async function queueReengagementEmail(params: ReengagementEmailParams): Promise<void> {
  const {userId, email, sequence, segment} = params;

  // Simple unsubscribe token — base64url of "uid:action:scope".
  // In production replace with a signed JWT for tamper-resistance.
  const unsubscribeToken = Buffer
    .from(`${userId}:unsubscribe:reengagement`)
    .toString("base64url");
  const unsubscribeUrl = `${UNSUBSCRIBE_BASE}?token=${unsubscribeToken}&uid=${encodeURIComponent(userId)}`;

  // CTA deep link with web fallback — email clients open the web URL;
  // the web page handles the app-link redirect via app-links / universal links.
  const ctaUrl = `${REENGAGEMENT_WEB_BASE}?seq=${sequence}&source=email&uid=${encodeURIComponent(userId)}`;

  const subject = _subject(sequence);
  const html = _buildHtml(sequence, ctaUrl, unsubscribeUrl);

  try {
    await db.collection(MAIL_COLLECTION).add({
      to: email,
      from: FROM_EMAIL,
      message: {
        subject,
        html,
        headers: {
          // RFC 8058 one-click unsubscribe — required for Gmail/Yahoo bulk mail compliance.
          "List-Unsubscribe": `<${unsubscribeUrl}>`,
          "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
        },
      },
      // Metadata stored on the mail doc for analytics / suppression auditing.
      metadata: {
        userId,
        sequence,
        segment,
        sentAt: admin.firestore.Timestamp.now(),
        type: "reengagement",
      },
    });
    logger.info("queueReengagementEmail: queued.", {userId, sequence, segment});
  } catch (err) {
    logger.error("queueReengagementEmail: failed.", {userId, sequence, err});
  }
}

// ── Subject lines ─────────────────────────────────────────────────────────────

function _subject(sequence: number): string {
  switch (sequence) {
    case 1: return "Prism 3.0 is here — AI wallpapers, coins & more";
    case 2: return "Your 50 Prism Coins are waiting to be claimed";
    case 3: return "Should we remove you from our list?";
    default: return "An update from Prism";
  }
}

// ── HTML builders ─────────────────────────────────────────────────────────────

function _buildHtml(sequence: number, ctaUrl: string, unsubscribeUrl: string): string {
  switch (sequence) {
    case 1: return _seq1Html(ctaUrl, unsubscribeUrl);
    case 2: return _seq2Html(ctaUrl, unsubscribeUrl);
    case 3: return _seq3Html(ctaUrl, unsubscribeUrl);
    default: return _seq1Html(ctaUrl, unsubscribeUrl);
  }
}

const BASE_STYLES = `
  body{margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;}
  .wrap{max-width:600px;margin:0 auto;background:#111;color:#fff;}
  .content{padding:40px 32px;}
  .lead{font-size:20px;font-weight:600;color:#fff;margin:0 0 16px;}
  .txt{font-size:16px;color:rgba(255,255,255,.7);line-height:1.6;margin:0 0 24px;}
  .cta{display:block;background:linear-gradient(135deg,#E57697 0%,#9C5CC7 100%);color:#fff;text-decoration:none;text-align:center;padding:16px 32px;border-radius:12px;font-size:16px;font-weight:700;margin:0 0 16px;}
  .cta-sec{display:block;background:rgba(255,255,255,.08);color:rgba(255,255,255,.7);text-decoration:none;text-align:center;padding:14px 32px;border-radius:12px;font-size:15px;font-weight:500;}
  .foot{padding:24px 32px;text-align:center;color:rgba(255,255,255,.3);font-size:13px;border-top:1px solid rgba(255,255,255,.05);}
  .foot a{color:rgba(255,255,255,.4);text-decoration:underline;}
`;

function _seq1Html(ctaUrl: string, unsubUrl: string): string {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Prism 3.0 is here</title><style>${BASE_STYLES}
  .hdr{background:linear-gradient(135deg,#E57697 0%,#9C5CC7 100%);padding:40px 32px;text-align:center;}
  .hdr h1{margin:0;font-size:32px;font-weight:800;color:#fff;letter-spacing:-1px;}
  .hdr p{margin:8px 0 0;font-size:16px;color:rgba(255,255,255,.85);}
  .feats{list-style:none;padding:0;margin:0 0 32px;}
  .feats li{padding:14px 0;border-bottom:1px solid rgba(255,255,255,.08);font-size:15px;color:rgba(255,255,255,.8);display:flex;align-items:flex-start;gap:12px;}
  .feats li:last-child{border-bottom:none;}
  .ico{font-size:22px;flex-shrink:0;}
</style></head><body>
<div class="wrap">
  <div class="hdr"><h1>Prism 3.0</h1><p>We rebuilt the app from scratch.</p></div>
  <div class="content">
    <p class="lead">AI wallpapers are finally here 🎨</p>
    <p class="txt">It's been a while. We've spent it building something big — and now it's ready.
    Prism 3.0 ships with AI wallpaper generation, a coins system, and a fresh wallpaper every single day.</p>
    <ul class="feats">
      <li><span class="ico">✨</span><div><strong>AI Wallpaper Generation</strong> — Describe any wallpaper, get it in seconds. First 3 are completely free.</div></li>
      <li><span class="ico">🪙</span><div><strong>Prism Coins</strong> — Earn coins for daily logins and streaks. Spend on premium walls and AI generations.</div></li>
      <li><span class="ico">📆</span><div><strong>Wall of the Day</strong> — A curated wallpaper drops every morning at 9 AM. Always something new.</div></li>
    </ul>
    <a href="${ctaUrl}" class="cta">Claim your 3 free AI generations →</a>
    <a href="https://prismwalls.com/wall-of-the-day" class="cta-sec">See today's Wall of the Day</a>
  </div>
  <div class="foot"><p>You received this because you signed up for Prism.<br>
  <a href="${unsubUrl}">Unsubscribe</a> · <a href="https://prismwalls.com">prismwalls.com</a></p></div>
</div></body></html>`;
}

function _seq2Html(ctaUrl: string, unsubUrl: string): string {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Your 50 Prism Coins are waiting</title><style>${BASE_STYLES}
  .hdr{background:linear-gradient(135deg,#F5A623 0%,#E57697 100%);padding:40px 32px;text-align:center;}
  .hdr h1{margin:0;font-size:26px;font-weight:800;color:#fff;}
  .coin-num{font-size:72px;font-weight:900;color:#fff;display:block;margin:4px 0 0;letter-spacing:-2px;}
  .box{background:rgba(245,166,35,.12);border:1px solid rgba(245,166,35,.3);border-radius:12px;padding:20px;margin:0 0 24px;}
  .box p{margin:0 0 8px;font-size:15px;color:rgba(255,255,255,.8);}
  .box p:last-child{margin:0;}
  .urgency{font-size:14px;color:rgba(245,166,35,.9);font-weight:600;margin:0 0 32px;text-align:center;}
  .cta-gold{display:block;background:linear-gradient(135deg,#F5A623 0%,#E57697 100%);color:#fff;text-decoration:none;text-align:center;padding:16px 32px;border-radius:12px;font-size:16px;font-weight:700;}
</style></head><body>
<div class="wrap">
  <div class="hdr"><h1>We saved something for you</h1><span class="coin-num">🪙 50</span></div>
  <div class="content">
    <p class="lead">Your 50 Prism Coins are ready to claim</p>
    <p class="txt">We wanted to make sure you didn't miss Prism 3.0 — so we credited 50 coins to your account.
    That's enough for 10 premium wallpaper downloads or 2 AI-generated wallpapers.</p>
    <div class="box">
      <p>🎨 <strong>2 AI wallpaper generations</strong> — describe anything, get a custom wallpaper</p>
      <p>🖼️ <strong>10 premium wallpapers</strong> — full-resolution, no watermarks</p>
    </div>
    <p class="urgency">⏳ Expires in 7 days — don't let them go to waste</p>
    <a href="${ctaUrl}" class="cta-gold">Claim my 50 coins →</a>
  </div>
  <div class="foot"><p>You received this because you signed up for Prism.<br>
  <a href="${unsubUrl}">Unsubscribe</a> · <a href="https://prismwalls.com">prismwalls.com</a></p></div>
</div></body></html>`;
}

function _seq3Html(ctaUrl: string, unsubUrl: string): string {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Should we remove you from our list?</title><style>${BASE_STYLES}
  .hdr{background:#1a1a1a;padding:40px 32px;text-align:center;border-bottom:1px solid rgba(255,255,255,.06);}
  .hdr h1{margin:0;font-size:22px;font-weight:700;color:rgba(255,255,255,.65);}
  .unsub-sec{text-align:center;margin-top:32px;padding-top:24px;border-top:1px solid rgba(255,255,255,.05);}
  .unsub-link{color:rgba(255,255,255,.35);font-size:14px;text-decoration:underline;}
</style></head><body>
<div class="wrap">
  <div class="hdr"><h1>👋 Is this goodbye?</h1></div>
  <div class="content">
    <p class="lead">We've tried to reach you a couple of times.</p>
    <p class="txt">No hard feelings if Prism isn't for you anymore. But if you'd like to give our new
    AI wallpaper generator one last try — it's genuinely impressive, and your first 3 generations are free.</p>
    <p class="txt">If we don't hear from you, we'll stop emailing. You won't receive anything further from us.</p>
    <a href="${ctaUrl}" class="cta">I want to stay — take me to Prism →</a>
    <div class="unsub-sec">
      <a href="${unsubUrl}" class="unsub-link">No thanks, remove me from this list</a>
    </div>
  </div>
  <div class="foot"><p><a href="https://prismwalls.com">prismwalls.com</a></p></div>
</div></body></html>`;
}
