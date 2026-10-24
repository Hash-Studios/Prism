/** Runs fn over items with at most `concurrency` calls in flight; each chunk finishes before the next starts. */
export async function runChunked<T>(items: readonly T[], concurrency: number, fn: (item: T) => Promise<void>) {
  for (let i = 0; i < items.length; i += concurrency) await Promise.all(items.slice(i, i + concurrency).map(fn));
}

/** Parses `--concurrency=N` (1 to 50). Missing means 1. */
export function parseConcurrency(argv: string[]): number {
  const args = argv.filter((arg) => arg.startsWith("--concurrency"));
  if (args.length === 0) return 1;
  const value = args.length === 1 && args[0].startsWith("--concurrency=") ? Number(args[0].slice("--concurrency=".length)) : NaN;
  if (!Number.isInteger(value) || value < 1 || value > 50) throw new Error("Invalid --concurrency.");
  return value;
}
