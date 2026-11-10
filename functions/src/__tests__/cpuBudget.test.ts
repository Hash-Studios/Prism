import assert from "node:assert/strict";
import {test} from "node:test";
import {RESET_VALUE} from "firebase-functions/v2/options";
import {REGION_CPU_BUDGET_VCPU} from "../common";
import * as functions from "../index";

// firebase-functions sets an option the code leaves out to RESET_VALUE, so Cloud Run uses its default.
type Option<T> = T | typeof RESET_VALUE;

interface Endpoint {
  region?: string[];
  cpu?: Option<number | "gcf_gen1">;
  availableMemoryMb?: Option<number>;
  maxInstances?: Option<number>;
  concurrency?: Option<number>;
}

// firebase-tools sizes "gcf_gen1" by memory. Without it, 2nd gen gets 1 vCPU up to 2 GiB.
const GEN1_VCPU: Record<number, number> = {128: 1 / 12, 256: 1 / 6, 512: 1 / 3, 1024: 7 / 12, 2048: 1, 4096: 2, 8192: 2};
// Cloud Run uses 100 when maxInstances is unset.
const UNSET_MAX_INSTANCES = 100;

function orDefault(value: Option<number> | undefined, fallback: number): number {
  return typeof value === "number" ? value : fallback;
}

function vcpu(endpoint: Endpoint): number {
  const memory = orDefault(endpoint.availableMemoryMb, 256);
  if (endpoint.cpu === "gcf_gen1") return GEN1_VCPU[memory];
  return typeof endpoint.cpu === "number" ? endpoint.cpu : memory <= 2048 ? 1 : 2;
}

function regionsOverBudget(endpoints: Record<string, Endpoint>): string[] {
  const maxCpu = new Map<string, number>();
  for (const endpoint of Object.values(endpoints)) {
    for (const region of endpoint.region ?? []) {
      const cpu = orDefault(endpoint.maxInstances, UNSET_MAX_INSTANCES) * vcpu(endpoint);
      maxCpu.set(region, (maxCpu.get(region) ?? 0) + cpu);
    }
  }
  return [...maxCpu].filter(([, cpu]) => cpu > REGION_CPU_BUDGET_VCPU).map(([region]) => region);
}

const endpoints: Record<string, Endpoint> = Object.fromEntries(
  Object.entries(functions as Record<string, {__endpoint: Endpoint}>).map(([name, fn]) => [name, fn.__endpoint]));

test("every region's maxInstances x vCPU fits the CPU budget", () => {
  assert.ok(Object.keys(endpoints).length > 100);
  assert.deepEqual(regionsOverBudget(endpoints), []);
});

test("one function raised to the Cloud Run default breaks the asia-south1 budget", () => {
  const over = {...endpoints, onWallApproved: {...endpoints.onWallApproved, maxInstances: UNSET_MAX_INSTANCES}};
  assert.deepEqual(regionsOverBudget(over), ["asia-south1"]);
});

test("a function without maxInstances breaks the budget of each of its regions", () => {
  const reset = {...endpoints, awardCoins: {...endpoints.awardCoins, maxInstances: RESET_VALUE}};
  assert.deepEqual(regionsOverBudget(reset), ["asia-south1", "us-central1"]);
});

test("fractional CPU functions take one request per instance", () => {
  const concurrent = Object.entries(endpoints).filter(([, e]) => vcpu(e) < 1 && orDefault(e.concurrency, 1) > 1);
  assert.deepEqual(concurrent.map(([name]) => name), []);
});
