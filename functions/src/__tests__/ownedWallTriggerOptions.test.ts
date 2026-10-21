import assert from "node:assert/strict";
import {test} from "node:test";
import {onOwnedWallWritten} from "../ownedAssetDelivery";

test("the wall conversion trigger runs one conversion per instance with 1 GiB", () => {
  const endpoint = (onOwnedWallWritten as unknown as {__endpoint: {concurrency?: number; availableMemoryMb?: number}})
    .__endpoint;
  assert.equal(endpoint.concurrency, 1);
  assert.equal(endpoint.availableMemoryMb, 1024);
});
