import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import path from "node:path";
import {test} from "node:test";
import {RESET_VALUE} from "firebase-functions/v2/options";

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
const GEN1_VCPU: Record<number, number> = {
  128: 0.0833,
  256: 0.1666,
  512: 0.3333,
  1024: 0.5833,
  2048: 1,
  4096: 2,
  8192: 2,
  16384: 4,
  32768: 8,
};
// Cloud Run uses 100 when maxInstances is unset.
const UNSET_MAX_INSTANCES = 100;

// Match firebase-functions' runtime loader: only functions with __endpoint deploy; nested exports form groups.
function collectEndpoints(exports: Record<string, unknown>, prefix = ""): Record<string, Endpoint> {
  const endpoints: Record<string, Endpoint> = {};
  for (const [name, value] of Object.entries(exports)) {
    if (typeof value === "function" && "__endpoint" in value && value.__endpoint && typeof value.__endpoint === "object") {
      endpoints[prefix + name] = value.__endpoint as Endpoint;
    } else if (value && typeof value === "object") {
      Object.assign(endpoints, collectEndpoints(value as Record<string, unknown>, `${prefix}${name}-`));
    }
  }
  return endpoints;
}

// Load the real deployment entry first in a new process. Importing common here would mask missing initialization.
const manifest = JSON.parse(execFileSync(process.execPath, ["-e", `
  const endpoints = (${collectEndpoints.toString()})(require(${JSON.stringify(path.resolve(__dirname, "../index.js"))}));
  const {REGION_CPU_BUDGET_VCPU: budget} = require(${JSON.stringify(path.resolve(__dirname, "../common.js"))});
  process.stdout.write(JSON.stringify({endpoints, budget}));
`], {encoding: "utf8"})) as {endpoints: Record<string, Endpoint>; budget: number};
const {endpoints} = manifest;

function orDefault(value: Option<number> | undefined, fallback: number): number {
  return typeof value === "number" ? value : fallback;
}

function vcpu(endpoint: Endpoint): number {
  const memory = orDefault(endpoint.availableMemoryMb, 256);
  assert.ok(Object.prototype.hasOwnProperty.call(GEN1_VCPU, memory), `unsupported memory option: ${JSON.stringify(endpoint)}`);
  const cpu = endpoint.cpu === "gcf_gen1" ? GEN1_VCPU[memory] :
    typeof endpoint.cpu === "number" ? endpoint.cpu : memory <= 2048 ? 1 : memory <= 8192 ? 2 : memory / 4096;
  assert.ok(Number.isFinite(cpu) && cpu > 0, `unsupported CPU or memory option: ${JSON.stringify(endpoint)}`);
  return cpu;
}

function effectiveConcurrency(endpoint: Endpoint): number {
  return orDefault(endpoint.concurrency, vcpu(endpoint) >= 1 ? 80 : 1);
}

function regionTotals(endpoints: Record<string, Endpoint>): Map<string, number> {
  const maxCpu = new Map<string, number>();
  for (const [name, endpoint] of Object.entries(endpoints)) {
    const regions = endpoint.region ?? ["us-central1"];
    assert.ok(Array.isArray(regions) && regions.length > 0, `${name} has invalid regions`);
    for (const region of regions) {
      const cpu = orDefault(endpoint.maxInstances, UNSET_MAX_INSTANCES) * vcpu(endpoint);
      assert.ok(Number.isFinite(cpu) && cpu > 0, `${name} has invalid instance CPU allocation`);
      maxCpu.set(region, (maxCpu.get(region) ?? 0) + cpu);
    }
  }
  return maxCpu;
}

function regionsOverBudget(endpoints: Record<string, Endpoint>): string[] {
  return [...regionTotals(endpoints)].filter(([, cpu]) => cpu > manifest.budget).map(([region]) => region);
}

test("every region's maxInstances x vCPU fits the CPU budget", (context) => {
  assert.ok(Object.keys(endpoints).length > 100);
  context.diagnostic(`${Object.keys(endpoints).length} exported endpoints; max vCPU by region: ${JSON.stringify(Object.fromEntries(regionTotals(endpoints)))}`);
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
  const concurrent = Object.entries(endpoints).filter(([, e]) => vcpu(e) < 1 && effectiveConcurrency(e) > 1);
  assert.deepEqual(concurrent.map(([name]) => name), []);
});

test("gcf_gen1 CPU follows firebase-tools memory mapping, including larger sizes", () => {
  assert.deepEqual(
    Object.entries(GEN1_VCPU).map(([memory]) => [Number(memory), vcpu({cpu: "gcf_gen1", availableMemoryMb: Number(memory)})]),
    [[128, 0.0833], [256, 0.1666], [512, 0.3333], [1024, 0.5833], [2048, 1], [4096, 2], [8192, 2], [16384, 4], [32768, 8]],
  );
});

test("unknown memory sizes fail instead of becoming NaN or inventing a CPU allocation", () => {
  for (const cpu of ["gcf_gen1", undefined, 1] as const) {
    assert.throws(() => vcpu({cpu, availableMemoryMb: 768}), /unsupported memory option/);
  }
});

test("default gen2 CPU includes the larger memory tiers in the budget", () => {
  assert.equal(vcpu({availableMemoryMb: 16384}), 4);
  assert.equal(vcpu({availableMemoryMb: 32768}), 8);
  for (const availableMemoryMb of [16384, 32768]) {
    assert.deepEqual(regionsOverBudget({large: {availableMemoryMb, maxInstances: 50}}), ["us-central1"]);
  }
});

test("unset and RESET_VALUE resource options use Firebase deployment defaults", () => {
  for (const reset of [undefined, RESET_VALUE]) {
    const endpoint = {cpu: reset, availableMemoryMb: reset, maxInstances: reset, concurrency: reset};
    assert.equal(vcpu(endpoint), 1);
    assert.equal(effectiveConcurrency(endpoint), 80);
    assert.equal(effectiveConcurrency({...endpoint, cpu: "gcf_gen1"}), 1);
    assert.deepEqual(Object.fromEntries(regionTotals({defaulted: endpoint})), {"us-central1": 100});
  }
  assert.equal(effectiveConcurrency({cpu: 1, concurrency: 8}), 8);
});

test("inventory includes grouped HTTP and task functions but ignores plain helpers", () => {
  const http = Object.assign(() => undefined, {__endpoint: {httpsTrigger: {}, maxInstances: 1}});
  const task = Object.assign(() => undefined, {__endpoint: {taskQueueTrigger: {}, cpu: "gcf_gen1", maxInstances: 2}});
  const inventory = collectEndpoints({http, group: {task, helper: () => undefined}, helper: () => undefined});
  assert.deepEqual(Object.keys(inventory), ["http", "group-task"]);
  assert.equal(regionTotals(inventory).get("us-central1"), 1 + 2 * GEN1_VCPU[256]);
});
