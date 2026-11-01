import assert from "node:assert/strict";
import test from "node:test";
import {parseCreatePromoCodesArgs, run, type CreatePromoCodesDeps} from "../scripts/createPromoCodes";

const NOW = Date.parse("2026-01-10T12:00:00Z");

test("parseCreatePromoCodesArgs rejects bad arguments", () => {
  assert.throws(
    () => parseCreatePromoCodesArgs(["--count", "3", "--type", "coins", "--amount", "100", "--expires-days", "30", "--dry-run"]),
    /project ID is required/,
  );
  assert.throws(
    () => parseCreatePromoCodesArgs(["--project", "demo-prism", "--count", "3", "--type", "gems", "--amount", "100",
      "--expires-days", "30", "--dry-run"]),
    /--type must be coins or premiumDays/,
  );
  for (const count of ["0", "501"]) {
    assert.throws(
      () => parseCreatePromoCodesArgs(["--project", "demo-prism", "--count", count, "--type", "coins", "--amount", "100",
        "--expires-days", "30", "--dry-run"]),
      /--count must be between 1 and 500/,
    );
  }
  assert.throws(
    () => parseCreatePromoCodesArgs(["--project", "demo-prism", "--count", "3", "--type", "coins", "--amount", "100",
      "--expires-days", "30", "--bogus", "1", "--dry-run"]),
    /Unknown or duplicate argument: --bogus/,
  );
  assert.throws(
    () => parseCreatePromoCodesArgs(["--project", "demo-prism", "--count", "3", "--type", "coins", "--amount", "100",
      "--expires-days", "30"]),
    /--out is required unless --dry-run/,
  );
});

test("dry run prints the plan and calls no write, file or code path", async () => {
  const lines: string[] = [];
  const calls: string[] = [];
  const deps: CreatePromoCodesDeps = {
    now: () => NOW,
    log: (line) => lines.push(line),
    claimFile: () => calls.push("claimFile"),
    writeFile: () => calls.push("writeFile"),
    write: async () => {
      calls.push("write");
      return "UNUSED";
    },
  };
  await run(["--project", "demo-prism", "--count", "3", "--type", "coins", "--amount", "100",
    "--expires-days", "30", "--dry-run"], deps);
  assert.deepEqual(calls, []);
  const output = lines.join("\n");
  assert.match(output, /3/);
  assert.match(output, /coins/);
  assert.doesNotMatch(output, /[A-HJ-NP-Z2-9]{10}/);
});
