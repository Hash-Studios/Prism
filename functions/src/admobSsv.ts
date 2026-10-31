import {createPublicKey, verify, type KeyObject} from "node:crypto";

const KEY_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";
const CACHE_MS = 3_600_000;
export class SsvUnavailable extends Error {}
export class SsvInvalid extends Error {}

export class GoogleSsvVerifier {
  private keys = new Map<string, KeyObject>();
  private until = 0;
  private unknownRefreshAt = -Infinity;
  private refresh?: Promise<void>;
  constructor(private readonly fetchKeys: typeof fetch = fetch) {}

  private async load(): Promise<void> {
    if (this.refresh) return this.refresh;
    this.refresh = (async () => {
      try {
        const response = await this.fetchKeys(KEY_URL, {signal: AbortSignal.timeout(5000), redirect: "error"});
        if (!response.ok) throw new Error("key endpoint failed");
        const body = await response.text();
        if (body.length > 65_536) throw new Error("key response too large");
        const entries = JSON.parse(body).keys;
        if (!Array.isArray(entries) || entries.length < 1 || entries.length > 20) throw new Error("invalid keys");
        const next = new Map<string, KeyObject>();
        for (const entry of entries) {
          const id = String(entry.keyId);
          if (!/^\d{1,20}$/.test(id) || typeof entry.pem !== "string" || entry.pem.length > 4096) {
            throw new Error("invalid key");
          }
          const key = createPublicKey(entry.pem);
          if (key.asymmetricKeyType !== "ec" || key.asymmetricKeyDetails?.namedCurve !== "prime256v1") {
            throw new Error("invalid key algorithm");
          }
          next.set(id, key);
        }
        this.keys = next;
        this.until = Date.now() + CACHE_MS;
      } catch {
        throw new SsvUnavailable("Google verification keys unavailable");
      }
    })();
    try {
      await this.refresh;
    } finally {
      this.refresh = undefined;
    }
  }

  async verify(raw: string): Promise<URLSearchParams> {
    if (raw.length > 16_384 || /[\r\n#]/.test(raw) || /%(?![0-9A-Fa-f]{2})/.test(raw)) {
      throw new SsvInvalid("invalid query");
    }
    const match = /^(.*)&signature=([A-Za-z0-9_-]{16,256}(?:=|%3[Dd]){0,2})&key_id=(\d{1,20})$/.exec(raw);
    if (!match || !match[1]) throw new SsvInvalid("invalid signature suffix");
    const params = new URLSearchParams(raw);
    const seen = new Set<string>();
    for (const [name, value] of params) {
      if (seen.has(name) || !name || value.length > 1024) throw new SsvInvalid("duplicate or oversized field");
      seen.add(name);
    }
    const signature = decodeURIComponent(match[2]);
    if (params.get("signature") !== signature || params.get("key_id") !== match[3]) throw new SsvInvalid("invalid suffix");
    const wasFresh = this.until > Date.now();
    if (!wasFresh) await this.load();
    // Unknown keys refresh once, but random key IDs cannot cause an unbounded fetch storm.
    if (!this.keys.has(match[3]) && wasFresh) {
      if (Date.now() - this.unknownRefreshAt < 30_000) throw new SsvUnavailable("Key refresh throttled; retry");
      this.unknownRefreshAt = Date.now();
      await this.load();
    }
    const key = this.keys.get(match[3]);
    if (!key) throw new SsvInvalid("unknown key");
    if (!verify("sha256", Buffer.from(match[1], "utf8"), key, Buffer.from(signature, "base64url"))) {
      throw new SsvInvalid("invalid signature");
    }
    return params;
  }
}
