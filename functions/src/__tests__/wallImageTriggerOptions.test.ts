import assert from "node:assert/strict";
import {test} from "node:test";
import {onCreatorWallWritten} from "../creatorProgress";
import {onWallCategorize} from "../onWallCategorize";
import {onWallModerate} from "../wallModeration";
import {onWallSearchTerms} from "../wallSearchTerms";

test("moderation deploys with one image-processing event per instance", () => {
  assert.equal(onWallModerate.__endpoint.concurrency, 1);
});

test("categorization deploys with one image-processing event per instance", () => {
  assert.equal(onWallCategorize.__endpoint.concurrency, 1);
});

test("search indexing retains the wall-write endpoint with platform-default concurrency", () => {
  const endpoint = onWallSearchTerms.__endpoint;
  assert.equal(endpoint.eventTrigger?.eventType, "google.cloud.firestore.document.v1.written");
  assert.equal(endpoint.eventTrigger?.eventFilterPathPatterns?.document, "walls/{wallId}");
  assert.equal(JSON.stringify(endpoint.concurrency), "null");
});

test("creator credits retain the retrying wall-write endpoint with platform-default concurrency", () => {
  const endpoint = onCreatorWallWritten.__endpoint;
  assert.equal(endpoint.eventTrigger?.eventType, "google.cloud.firestore.document.v1.written");
  assert.equal(endpoint.eventTrigger?.eventFilterPathPatterns?.document, "walls/{wallId}");
  assert.equal(endpoint.eventTrigger?.retry, true);
  assert.equal(JSON.stringify(endpoint.concurrency), "null");
});
