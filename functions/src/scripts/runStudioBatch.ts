import {parseRunInput, createStudioRun} from "../studio/planRun";
import {buildDailyPlan} from "../studio/plan";
import {STUDIO_SERIES} from "../studio/series";
import {DUO_PROVIDER_SIZE} from "../studio/duo";
import {parseStudioConfig} from "../studio/config";

// Plans a Prism Studio run now, like the runStudioBatch callable. The deployed processStudioCandidate makes the images.
// Usage: npm run studio:run -- --count 10 [--series after-dark]
async function main(): Promise<void> {
  for (let i = 2; i < process.argv.length; i++) {
    const flag = process.argv[i];
    if (flag === "--dry-run") continue;
    if ((flag !== "--count" && flag !== "--series") || !process.argv[i + 1] || process.argv[i + 1].startsWith("--")) {
      throw new Error(`Invalid Studio argument: ${flag}`);
    }
    i++;
  }
  const arg = (name: string) => {
    const at = process.argv.indexOf(`--${name}`);
    return at >= 0 ? process.argv[at + 1] : undefined;
  };
  const series = arg("series");
  const input = parseRunInput({count: Number(arg("count") ?? 10), ...(series ? {seriesId: series} : {})});
  if (process.argv.includes("--dry-run")) {
    const config = parseStudioConfig(undefined);
    const plan = buildDailyPlan({series: STUDIO_SERIES.filter((s) => !series || s.id === series), count: input.count,
      manualSeriesId: series, weights: {}, recentSubjectIds: new Set(), rng: Math.random});
    console.log(JSON.stringify({dryRun: true, count: plan.length, model: config.model,
      candidates: plan.map((item) => ({...item, ...(item.duoPresetId ? DUO_PROVIDER_SIZE :
        {width: config.width, height: config.height})}))}));
    return;
  }
  const result = await createStudioRun({runId: `m${Date.now()}`, ...input, source: "manual"});
  console.log(JSON.stringify(result));
  if (result.status !== "created") process.exitCode = 1;
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
