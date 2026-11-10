import {defineSecret} from "firebase-functions/params";

// A private approval bot, separate from the channel bot in studio/telegram.ts. Only the owner's chat is accepted.
export const socialBotToken = defineSecret("SOCIAL_TELEGRAM_BOT_TOKEN");
/** The owner's private chat with the bot. In a private chat the chat id is also the owner's user id. */
export const socialOwnerChatId = defineSecret("SOCIAL_TELEGRAM_OWNER_CHAT_ID");
export const socialTelegramSecrets = [socialBotToken, socialOwnerChatId];

export type ApprovalAction = "approve" | "skip" | "retry" | "drop";
const ACTION_CODES: Record<string, ApprovalAction> = {a: "approve", s: "skip", r: "retry", d: "drop"};

export interface ApprovalPress {updateId: number; callbackId: string; action: ApprovalAction; postId: string; hash: string}

export interface Telegram {
  sendPhotos(caption: string, photos: Buffer[]): Promise<void>;
  sendButtons(text: string, buttons: Array<{label: string; action: ApprovalAction; postId: string; hash: string}>): Promise<void>;
  sendText(text: string): Promise<void>;
  /** Owner presses after `offset`. Presses from anyone else are dropped here. Returns the next offset. */
  presses(offset: number): Promise<{presses: ApprovalPress[]; nextOffset: number}>;
  answer(callbackId: string, text: string): Promise<void>;
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
  return {updateId: update.update_id, callbackId: String(query.id), action: ACTION_CODES[match[1]], postId: match[2],
    hash: match[3]};
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
    async presses(offset) {
      const updates = await call("getUpdates", {offset, timeout: 0, allowed_updates: ["callback_query"]});
      const list = Array.isArray(updates) ? updates : [];
      const presses = list.map((u) => parsePress(u, ownerChatId)).filter((p): p is ApprovalPress => p !== null);
      const last = list.reduce((max, u) => typeof u?.update_id === "number" ? Math.max(max, u.update_id) : max, offset - 1);
      return {presses, nextOffset: last + 1};
    },
    async answer(callbackId, text) {
      await call("answerCallbackQuery", {callback_query_id: callbackId, text: text.slice(0, 200)});
    },
  };
}
