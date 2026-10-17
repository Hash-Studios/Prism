import {db} from "../common";

// Marks Studio walls for the next weekly Drop. Dry run unless --apply. Safe to run again.
// Usage: npm run drops:reserve -- <wallId> [<wallId> ...] [--apply]
async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const apply = args.includes("--apply");
  const ids = args.filter((arg) => !arg.startsWith("--"));
  if (ids.length === 0) throw new Error("Usage: npm run drops:reserve -- <wallId> [<wallId> ...] [--apply]");

  let reserved = 0;
  for (const id of ids) {
    const ref = db.collection("walls").doc(id);
    const data = (await ref.get()).data();
    if (!data) {
      console.log(`${id}: skip, wall not found`);
    } else if (data.origin !== "studio" || data.review !== false) {
      console.log(`${id}: skip, needs origin studio and review false`);
    } else if (data.dropReserved === true) {
      console.log(`${id}: already reserved`);
    } else {
      if (apply) await ref.update({dropReserved: true});
      console.log(`${id}: ${apply ? "reserved" : "would reserve"}`);
      reserved += 1;
    }
  }
  console.log(apply ? `Done. Reserved ${reserved}.` : `Dry run: ${reserved} would change. Add -- --apply to write.`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
