import {db} from "../common";

export const CHALLENGE_THEMES = [
  "Quiet horizons", "Light through glass", "Shapes in nature", "After the rain", "Small worlds", "Night colours",
];

async function main(): Promise<void> {
  const dryRun = process.argv.includes("--dry-run");
  if (!dryRun && !process.argv.includes("--apply")) throw new Error("Pass --dry-run or --apply explicitly.");
  for (const [order, theme] of CHALLENGE_THEMES.entries()) {
    const key = `theme_${String(order + 1).padStart(2, "0")}`;
    if (dryRun) process.stdout.write(`${key}\t${order}\t${theme}\n`);
    else {
      await db.runTransaction(async (tx) => {
        const ref = db.collection("challengeThemes").doc(key);
        if (!(await tx.get(ref)).exists) tx.create(ref, {order, theme});
      });
    }
  }
}
if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`${String(error)}\n`); process.exitCode = 1;
  });
}
