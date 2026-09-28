import assert from "node:assert/strict";
import test from "node:test";

import {subscriptionFromRevenueCat} from "../syncSubscription";

const NOW = Date.parse("2026-01-01T00:00:00.000Z");

function subscriberJson(entitlements: Record<string, {expires_date: string | null}>): unknown {
  return {subscriber: {entitlements}};
}

test("subscriptionFromRevenueCat: a lifetime entitlement (null expiry) grants the lifetime tier", () => {
  const json = subscriberJson({prism_premium: {expires_date: null}});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: true, subscriptionTier: "lifetime"});
});

test("subscriptionFromRevenueCat: an entitlement expiring in the future grants the pro tier", () => {
  const json = subscriberJson({prism_ultra: {expires_date: "2026-02-01T00:00:00.000Z"}});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: true, subscriptionTier: "pro"});
});

test("subscriptionFromRevenueCat: an expired entitlement grants no premium", () => {
  const json = subscriberJson({prism_ultra: {expires_date: "2025-01-01T00:00:00.000Z"}});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: false, subscriptionTier: "free"});
});

test("subscriptionFromRevenueCat: an unknown entitlement key is ignored", () => {
  const json = subscriberJson({some_other_entitlement: {expires_date: null}});
  assert.deepEqual(subscriptionFromRevenueCat(json, NOW), {premium: false, subscriptionTier: "free"});
});

test("subscriptionFromRevenueCat: no entitlements at all grants no premium", () => {
  assert.deepEqual(subscriptionFromRevenueCat({subscriber: {entitlements: {}}}, NOW), {premium: false, subscriptionTier: "free"});
});
