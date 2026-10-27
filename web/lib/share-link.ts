export type ShareResult = "shared" | "cancelled" | "copied" | "failed";

type ShareTarget = {
  share?: (data: { title: string; url: string }) => Promise<void>;
  clipboard?: { writeText?: (text: string) => Promise<void> };
};

export async function shareLink(target: ShareTarget, data: { title: string; url: string }): Promise<ShareResult> {
  if (target.share) {
    try {
      await target.share(data);
      return "shared";
    } catch (error) {
      if ((error as { name?: string } | null)?.name === "AbortError") return "cancelled";
    }
  }
  if (!target.clipboard?.writeText) return "failed";
  try {
    await target.clipboard.writeText(data.url);
    return "copied";
  } catch {
    return "failed";
  }
}
