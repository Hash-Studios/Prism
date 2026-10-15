import {parseRankArg, setupStudioAccount} from "../studio/account";

// Creates the Prism Studio profile and the studioConfig identity. When Studio has 5 live walls, it also adds
// Studio to the onboarding starter pack. Dry run unless --apply. Safe to run again.
// Usage: npm run studio:account -- [--apply] [--rank 0]
async function main(): Promise<void> {
  const rank = parseRankArg(process.argv);
  const apply = process.argv.includes("--apply");
  for (const line of await setupStudioAccount({apply, rank})) console.log(line);
  console.log(apply ? "Done." : "Dry run: nothing was written. Add -- --apply to write.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
