import {createHash, createHmac} from "node:crypto";
import {defineSecret} from "firebase-functions/params";

type BucketKind = "private" | "preview";
type Config = {accountId: string; accessKeyId: string; secretAccessKey: string; privateBucket: string; previewBucket: string};
const sha256 = (value: string | Buffer) => createHash("sha256").update(value).digest("hex");
const hmac = (key: string | Buffer, value: string) => createHmac("sha256", key).update(value).digest();
export const r2Secrets = [defineSecret("R2_ACCESS_KEY_ID"), defineSecret("R2_SECRET_ACCESS_KEY")];
function config(): Config {
  const values = [process.env.R2_ACCOUNT_ID, process.env.R2_ACCESS_KEY_ID, process.env.R2_SECRET_ACCESS_KEY,
    process.env.R2_PRIVATE_BUCKET, process.env.R2_PREVIEW_BUCKET];
  if (![...values, process.env.R2_PREVIEW_BASE_URL].some((value) => !!value)) throw new Error("R2 storage is not configured");
  if (values.some((value) => !value?.trim())) throw new Error("R2 storage configuration is incomplete");
  if (!/^[a-f0-9]{32}$/i.test(values[0]!) || values[3] === values[4] || !process.env.R2_PREVIEW_BASE_URL?.trim()) {
    throw new Error("R2 storage configuration is invalid");
  }
  if (![values[3], values[4]].every((value) => /^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$/.test(value!))) {
    throw new Error("R2 bucket configuration is invalid");
  }
  try {
    const preview = new URL(process.env.R2_PREVIEW_BASE_URL);
    if (preview.protocol !== "https:" || preview.username || preview.password || preview.port || preview.search || preview.hash) {
      throw new Error("Invalid preview endpoint");
    }
  } catch {
    throw new Error("R2 preview endpoint is invalid");
  }
  return {accountId: values[0]!, accessKeyId: values[1]!, secretAccessKey: values[2]!,
    privateBucket: values[3]!, previewBucket: values[4]!};
}
function bucketName(cfg: Config, kind: BucketKind) {
  return kind === "private" ? cfg.privateBucket : cfg.previewBucket;
}
function pathEncode(value: string) {
  return encodeURIComponent(value).replace(/[!'()*]/g, (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`);
}

/** Minimal AWS SigV4 S3 client for Cloudflare R2. All request bodies are bounded image assets. */
export class R2Storage {
  private readonly cfg = config();
  private readonly endpoint: string;
  constructor(private readonly request: typeof fetch = fetch, private readonly now: () => Date = () => new Date()) {
    this.endpoint = `https://${this.cfg.accountId}.r2.cloudflarestorage.com`;
  }
  private async signed(kind: BucketKind, method: string, object: string, body?: Buffer,
    headers: Record<string, string> = {}): Promise<Response> {
    const date = this.now().toISOString().replace(/[:-]|\.\d{3}/g, "");
    const day = date.slice(0, 8);
    const bucket = bucketName(this.cfg, kind);
    const canonicalUri = `/${pathEncode(bucket)}/${object.split("/").map(pathEncode).join("/")}`;
    const host = `${this.cfg.accountId}.r2.cloudflarestorage.com`;
    const payloadHash = body ? sha256(body) : sha256("");
    const normalized: Record<string, string> = {...headers, host, "x-amz-content-sha256": payloadHash, "x-amz-date": date};
    const names = Object.keys(normalized).map((key) => key.toLowerCase()).sort();
    const canonicalHeaders = names.map((name) => `${name}:${normalized[Object.keys(normalized).find((key) => key.toLowerCase() === name)!].trim()}\n`).join("");
    const signedHeaders = names.join(";");
    const canonicalRequest = [method, canonicalUri, "", canonicalHeaders, signedHeaders, payloadHash].join("\n");
    const scope = `${day}/auto/s3/aws4_request`;
    const stringToSign = `AWS4-HMAC-SHA256\n${date}\n${scope}\n${sha256(canonicalRequest)}`;
    const kDate = hmac(`AWS4${this.cfg.secretAccessKey}`, day);
    const kRegion = hmac(kDate, "auto");
    const kService = hmac(kRegion, "s3");
    const signature = createHmac("sha256", hmac(kService, "aws4_request")).update(stringToSign).digest("hex");
    const authorization = `AWS4-HMAC-SHA256 Credential=${this.cfg.accessKeyId}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;
    const url = `${this.endpoint}${canonicalUri}`;
    return this.request(url, {method, headers: {...headers, "x-amz-content-sha256": payloadHash,
      "x-amz-date": date, "Authorization": authorization}, signal: AbortSignal.timeout(15000),
    ...(body ? {body: new Uint8Array(body)} : {})});
  }
  async put(kind: BucketKind, object: string, bytes: Buffer, metadata: Record<string, string>, contentType: string) {
    const headers = {"content-type": contentType, "cache-control": kind === "preview" ? "public, max-age=31536000, immutable" :
      "private, no-store", "if-none-match": "*", ...Object.fromEntries(
      Object.entries(metadata).map(([key, value]) => [`x-amz-meta-${key.toLowerCase()}`, value]))};
    const response = await this.signed(kind, "PUT", object, bytes, headers);
    if (!response.ok && response.status !== 412 && response.status !== 409) {
      throw new Error(`R2 PUT failed (${response.status})`);
    }
    return response.status === 200 || response.status === 201;
  }
  async head(kind: BucketKind, object: string) {
    const response = await this.signed(kind, "HEAD", object);
    if (response.status === 404) return null;
    if (!response.ok) throw new Error(`R2 HEAD failed (${response.status})`);
    return {size: Number(response.headers.get("content-length")), contentType: response.headers.get("content-type") ?? "",
      sha256: response.headers.get("x-amz-meta-sha256") ?? "", uid: response.headers.get("x-amz-meta-uid") ?? "",
      objectId: response.headers.get("x-amz-meta-objectid") ?? "", repo: Buffer.from(response.headers.get("x-amz-meta-repo64") ?? "", "base64url").toString(),
      path: Buffer.from(response.headers.get("x-amz-meta-path64") ?? "", "base64url").toString(),
      gitSha: response.headers.get("x-amz-meta-gitsha") ?? "", uploadId: response.headers.get("x-amz-meta-uploadid") ?? ""};
  }
  async get(kind: BucketKind, object: string) {
    const response = await this.signed(kind, "GET", object);
    if (!response.ok) throw new Error(`R2 GET failed (${response.status})`);
    const declaredSize = Number(response.headers.get("content-length"));
    if (!Number.isSafeInteger(declaredSize) || declaredSize < 1 || declaredSize > 15 * 1024 * 1024) {
      throw new Error("R2 object size is invalid");
    }
    const reader = response.body?.getReader();
    if (!reader) throw new Error("R2 object body is missing");
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 15 * 1024 * 1024) {
        await reader.cancel();
        throw new Error("R2 object is too large");
      }
      chunks.push(value);
    }
    return Buffer.concat(chunks);
  }
  async delete(kind: BucketKind, object: string) {
    const response = await this.signed(kind, "DELETE", object);
    if (!response.ok && response.status !== 404) throw new Error(`R2 DELETE failed (${response.status})`);
  }
  presignGet(object: string, expiresAt: Date) {
    const bucket = this.cfg.privateBucket;
    const date = this.now().toISOString().replace(/[:-]|\.\d{3}/g, "");
    const day = date.slice(0, 8);
    const scope = `${day}/auto/s3/aws4_request`;
    const host = `${this.cfg.accountId}.r2.cloudflarestorage.com`;
    const uri = `/${pathEncode(bucket)}/${object.split("/").map(pathEncode).join("/")}`;
    const params: Record<string, string> = {"X-Amz-Algorithm": "AWS4-HMAC-SHA256",
      "X-Amz-Credential": `${this.cfg.accessKeyId}/${scope}`, "X-Amz-Date": date,
      "X-Amz-Expires": String(Math.max(1, Math.floor((expiresAt.getTime() - this.now().getTime()) / 1000))),
      "X-Amz-SignedHeaders": "host"};
    const query = Object.entries(params).sort(([a], [b]) => a.localeCompare(b))
      .map(([key, value]) => `${pathEncode(key)}=${pathEncode(value)}`).join("&");
    const canonical = ["GET", uri, query, `host:${host}\n`, "host", "UNSIGNED-PAYLOAD"].join("\n");
    const stringToSign = `AWS4-HMAC-SHA256\n${date}\n${scope}\n${sha256(canonical)}`;
    const kDate = hmac(`AWS4${this.cfg.secretAccessKey}`, day);
    const kRegion = hmac(kDate, "auto");
    const kService = hmac(kRegion, "s3");
    const key = hmac(kService, "aws4_request");
    const signature = createHmac("sha256", key).update(stringToSign).digest("hex");
    return `${this.endpoint}${uri}?${query}&X-Amz-Signature=${signature}`;
  }
}

export const r2ObjectId = (identity: {uid: string; repo: string; path: string; sha: string; sourceKind?: "owned";
  uploadId?: string}, digest: string) =>
  sha256(`${identity.sourceKind === "owned" ? "owned" : "github"}\0${identity.uid}\0${identity.repo}\0${identity.path}\0${identity.sha}\0${digest}\0${identity.uploadId ?? "imported"}`);
