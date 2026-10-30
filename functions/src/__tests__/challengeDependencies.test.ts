import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {dirname, resolve} from "node:path";
import test from "node:test";

test("challenge lifecycle does not depend on the daily picker", () => {
  const lifecycle = resolve(__dirname, "../weeklyChallenges.js");
  const picker = resolve(__dirname, "../wallOfTheDay.js");
  const seen = new Set<string>();
  const visit = (file: string, chain: string[]): void => {
    assert.notEqual(file, picker, `Daily picker dependency: ${chain.join(" -> ")}`);
    if (seen.has(file)) return;
    seen.add(file);
    const source = readFileSync(file, "utf8");
    for (const match of source.matchAll(/(?:require|import)\(["'](\.\.?\/[^"']+)["']\)/g)) {
      const dependency = resolve(dirname(file), match[1].endsWith(".js") ? match[1] : `${match[1]}.js`);
      visit(dependency, [...chain, dependency]);
    }
  };
  visit(lifecycle, [lifecycle]);
});
