import {parseRunInput, createStudioRun} from "../studio/planRun";

// Plans a Prism Studio run now, like the runStudioBatch callable. The deployed processStudioCandidate makes the images.
// Usage: npm run studio:run -- --count 10 [--series after-dark]
async function main(): Promise<void> {
  const arg = (name: string) => {
    const at = process.argv.indexOf(`--${name}`);
    return at >= 0 ? process.argv[at + 1] : undefined;
  };
  const series = arg("series");
  const input = parseRunInput({count: Number(arg("count") ?? 10), ...(series ? {seriesId: series} : {})});
  const result = await createStudioRun({runId: `m${Date.now()}`, ...input, source: "manual"});
  console.log(JSON.stringify(result));
  if (result.status !== "created") process.exitCode = 1;
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
