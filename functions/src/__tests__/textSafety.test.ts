import assert from "node:assert/strict";
import test from "node:test";
import {hasBlockedWord} from "../textSafety";

test("hasBlockedWord catches blocked words split by punctuation without substring matches", () => {
  for (const name of [
    "s.e.x wallpapers", "x s.e.x wallpapers", "ｓ３ｘ wallpapers", "sëx wallpapers", "n.u.d.e collection",
    "p.orn wallpapers", "po.rn wallpapers", "p.o.r.n collection", "s e x wallpapers",
  ]) assert.equal(hasBlockedWord(name), true, name);
  for (const name of ["Scunthorpe landscapes", "Sculpture exhibition"]) {
    assert.equal(hasBlockedWord(name), false, name);
  }
});
