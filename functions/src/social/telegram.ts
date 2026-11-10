import {createHash} from "node:crypto";
import {defineSecret} from "firebase-functions/params";

// A private approval bot, separate from the channel bot in studio/telegram.ts. Only the owner's chat is accepted.
export const socialBotToken = defineSecret("SOCIAL_TELEGRAM_BOT_TOKEN");
/** The owner's private chat with the bot. In a private chat the chat id is also the owner's user id. */
export const socialOwnerChatId = defineSecret("SOCIAL_TELEGRAM_OWNER_CHAT_ID");
export const socialTelegramSecrets = [socialBotToken, socialOwnerChatId];

export type ApprovalAction = "approve" | "skip" | "retry" | "drop";
const ACTION_CODES: Record<string, ApprovalAction> = {a: "approve", s: "skip", r: "retry", d: "drop"};

export interface ApprovalPress {
  updateId: number; callbackId: string; messageId: number; action: ApprovalAction; postId: string; hash: string;
}

/** Telegram sends this in every webhook call, so only Telegram can press a button. Derived from the bot token. */
export const webhookSecret = (token: string) =>
  createHash("sha256").update(`prism-social-webhook:${token}`).digest("hex").slice(0, 48);

export interface Telegram {
  sendPhotos(caption: string, photos: Buffer[]): Promise<void>;
  sendButtons(text: string, buttons: Array<{label: string; action: ApprovalAction; postId: string; hash: string}>): Promise<void>;
  sendText(text: string): Promise<void>;
  answer(callbackId: string, text: string): Promise<void>;
  /** Replaces a button message with the outcome, so the buttons go away. */
  markDone(messageId: number, text: string): Promise<void>;
  setWebhook(url: string, secret: string): Promise<void>;
}

export const callbackData = (action: ApprovalAction, postId: string, hash: string) =>
  `${action[0]}:${postId}:${hash.slice(0, 12)}`;

/** Reads one callback update. Returns null for anything that is not an owner press in the owner chat. */
export function parsePress(update: any, ownerChatId: string): ApprovalPress | null {
  const query = update?.callback_query;
  if (!query || typeof update.update_id !== "number") return null;
  if (String(query.from?.id) !== ownerChatId || String(query.message?.chat?.id) !== ownerChatId) return null;
  const match = /^([asrd]):([A-Za-z0-9_-]{1,64}):([a-f0-9]{12})$/.exec(String(query.data ?? ""));
  if (!match) return null;
  return {updateId: update.update_id, callbackId: String(query.id), messageId: Number(query.message?.message_id) || 0,
    action: ACTION_CODES[match[1]], postId: match[2], hash: match[3]};
}

export function telegramClient(token: string, ownerChatId: string, request: typeof fetch = fetch): Telegram {
  async function call(method: string, body: FormData | Record<string, unknown>): Promise<any> {
    const isForm = body instanceof FormData;
    let res: Response;
    try {
      res = await request(`https://api.telegram.org/bot${token}/${method}`, {
        method: "POST",
        headers: isForm ? {} : {"Content-Type": "application/json"},
        body: isForm ? body : JSON.stringify(body),
        signal: AbortSignal.timeout(60_000),
      });
    } catch {
      throw new Error(`Telegram ${method} request failed`);
    }
    const json = await res.json().catch(() => null);
    // Never put the token or the URL in the error.
    if (!res.ok || json?.ok !== true) throw new Error(`Telegram ${method} failed: ${res.status}`);
    return json.result;
  }
  return {
    async sendPhotos(caption, photos) {
      const form = new FormData();
      const blob = (bytes: Buffer) => new Blob([new Uint8Array(bytes)], {type: "image/jpeg"});
      form.set("chat_id", ownerChatId);
      if (photos.length === 1) {
        form.set("caption", caption.slice(0, 1024));
        form.set("photo", blob(photos[0]), "p0.jpg");
        await call("sendPhoto", form);
        return;
      }
      form.set("media", JSON.stringify(photos.map((_, i) => ({type: "photo", media: `attach://p${i}`,
        ...(i === 0 ? {caption: caption.slice(0, 1024)} : {})}))));
      photos.forEach((bytes, i) => form.set(`p${i}`, blob(bytes), `p${i}.jpg`));
      await call("sendMediaGroup", form);
    },
    async sendButtons(text, buttons) {
      await call("sendMessage", {chat_id: ownerChatId, text, reply_markup: {inline_keyboard: [buttons.map((b) => ({
        text: b.label, callback_data: callbackData(b.action, b.postId, b.hash)}))]}});
    },
    async sendText(text) {
      await call("sendMessage", {chat_id: ownerChatId, text});
    },
    async answer(callbackId, text) {
      await call("answerCallbackQuery", {callback_query_id: callbackId, text: text.slice(0, 200)});
    },
    async markDone(messageId, text) {
      await call("editMessageText", {chat_id: ownerChatId, message_id: messageId, text});
    },
    async setWebhook(url, secret) {
      await call("setWebhook", {url, secret_token: secret, allowed_updates: ["callback_query"]});
    },
  };
}
