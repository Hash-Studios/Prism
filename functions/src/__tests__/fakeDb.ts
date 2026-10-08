import type {TestContext} from "node:test";
import * as admin from "firebase-admin";
import {db} from "../common";

export type Doc = Record<string, unknown>;

type Op = {__op: "inc"; n: number} | {__op: "arrayRemove" | "arrayUnion"; xs: unknown[]} | {__op: "delete" | "ts"};

const opOf = (value: unknown): Op | undefined =>
  typeof value === "object" && value !== null && "__op" in value ? value as Op : undefined;

function resolveValue(prev: unknown, value: unknown): unknown {
  const op = opOf(value);
  if (!op) return value;
  switch (op.__op) {
  case "inc": return (typeof prev === "number" ? prev : 0) + op.n;
  case "arrayRemove": return (Array.isArray(prev) ? prev : []).filter((x) => !op.xs.includes(x));
  case "arrayUnion": return [...(Array.isArray(prev) ? prev : []), ...op.xs.filter((x) => !(Array.isArray(prev) && prev.includes(x)))];
  case "ts": return admin.firestore.Timestamp.now();
  default: return undefined;
  }
}

function applyFields(prev: Doc | undefined, data: Doc, dotted: boolean): Doc {
  const next: Doc = {...(prev ?? {})};
  for (const [key, value] of Object.entries(data)) {
    const parts = dotted ? key.split(".") : [key];
    let target = next;
    for (const part of parts.slice(0, -1)) {
      target[part] = {...((target[part] as Doc | undefined) ?? {})};
      target = target[part] as Doc;
    }
    const last = parts[parts.length - 1];
    const resolved = resolveValue(target[last], value);
    if (opOf(value)?.__op === "delete") delete target[last];
    else target[last] = resolved;
  }
  return next;
}

function clone(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(clone);
  if (typeof value === "object" && value !== null && Object.getPrototypeOf(value) === Object.prototype) {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, clone(v)]));
  }
  return value;
}

const comparable = (v: unknown) => v instanceof admin.firestore.Timestamp ? v.toMillis() : v;

function matches(value: unknown, op: string, expected: unknown): boolean {
  const a = comparable(value) as never;
  const b = comparable(expected) as never;
  switch (op) {
  case "==": return a === b;
  case "!=": return a !== b;
  case "<": return a !== undefined && a < b;
  case "<=": return a !== undefined && a <= b;
  case ">": return a !== undefined && a > b;
  case ">=": return a !== undefined && a >= b;
  case "in": return (expected as unknown[]).map(comparable).includes(a);
  case "array-contains": return Array.isArray(value) && value.includes(expected);
  default: throw new Error(`fakeDb: unsupported operator ${op}`);
  }
}

interface Snap {
  id: string;
  ref: FakeRef;
  exists: boolean;
  data: () => Doc | undefined;
  updateTime?: {version: number};
}

interface FakeRef {
  id: string;
  path: string;
  get: () => Promise<Snap>;
  set: (data: Doc, options?: {merge?: boolean}) => Promise<void>;
  create: (data: Doc) => Promise<void>;
  update: (data: Doc, precondition?: {lastUpdateTime: {version: number}}) => Promise<void>;
  delete: () => Promise<void>;
  collection: (name: string) => unknown;
}

const lost = (code: number) => Object.assign(new Error(`firestore ${code}`), {code});

/**
 * An in-memory Firestore for tests: documents, queries, transactions and the FieldValue helpers that the
 * functions use. Returns the store so a test can seed and inspect documents by path.
 */
export function installFakeDb(t: TestContext, seed: Record<string, Doc> = {}) {
  const store = new Map<string, Doc>(Object.entries(seed));
  const versions = new Map<string, number>();
  let auto = 0;
  const FieldValue = admin.firestore.FieldValue;
  t.mock.method(FieldValue, "increment", (n: number) => ({__op: "inc", n}));
  t.mock.method(FieldValue, "arrayRemove", (...xs: unknown[]) => ({__op: "arrayRemove", xs}));
  t.mock.method(FieldValue, "arrayUnion", (...xs: unknown[]) => ({__op: "arrayUnion", xs}));
  t.mock.method(FieldValue, "delete", () => ({__op: "delete"}));
  t.mock.method(FieldValue, "serverTimestamp", () => ({__op: "ts"}));

  const write = (path: string, data: Doc | undefined) => {
    if (data === undefined) store.delete(path);
    else store.set(path, data);
    versions.set(path, (versions.get(path) ?? 0) + 1);
  };
  const snap = (path: string): Snap => {
    const data = store.get(path);
    return {
      id: path.split("/").pop() as string,
      ref: ref(path),
      exists: data !== undefined,
      data: () => data === undefined ? undefined : clone(data) as Doc,
      updateTime: data === undefined ? undefined : {version: versions.get(path) ?? 0},
    };
  };

  // Writes made through a transaction are applied when it ends, like the real one.
  let pending: Array<() => void> | null = null;
  const mutate = (apply: () => void) => {
    if (pending) pending.push(apply);
    else apply();
  };

  function ref(path: string): FakeRef {
    return {
      id: path.split("/").pop() as string,
      path,
      get: async () => snap(path),
      set: async (data: Doc, options?: {merge?: boolean}) => {
        mutate(() => write(path, applyFields(options?.merge ? store.get(path) : undefined, data, false)));
      },
      create: async (data: Doc) => {
        if (store.has(path)) throw lost(6);
        mutate(() => write(path, applyFields(undefined, data, false)));
      },
      update: async (data: Doc, precondition?: {lastUpdateTime: {version: number}}) => {
        if (!store.has(path)) throw lost(5);
        if (precondition && (versions.get(path) ?? 0) !== precondition.lastUpdateTime.version) throw lost(9);
        mutate(() => write(path, applyFields(store.get(path), data, true)));
      },
      delete: async () => {
        mutate(() => write(path, undefined));
      },
      collection: (name: string) => collection(`${path}/${name}`),
    };
  }

  type QueryState = {
    filters: Array<[string, string, unknown]>;
    orders: Array<[string | symbol, "asc" | "desc"]>;
    limitTo?: number;
    offsetBy: number;
    startAt?: unknown;
  };

  function query(path: string, state: QueryState) {
    const rows = (): Snap[] => {
      const depth = path.split("/").length + 1;
      let docs = [...store.keys()]
        .filter((p) => p.startsWith(`${path}/`) && p.split("/").length === depth)
        .map(snap)
        .filter((d) => state.filters.every(([field, op, value]) =>
          matches((d.data() as Doc)[field], op, value)));
      for (const [field, dir] of [...state.orders].reverse()) {
        const key = (d: Snap) =>
          field === "__name__" ? d.id : comparable((d.data() as Doc)[field as string]) as never;
        docs = docs.sort((x, y) => (key(x) < key(y) ? -1 : key(x) > key(y) ? 1 : 0) * (dir === "desc" ? -1 : 1));
      }
      if (state.startAt !== undefined) docs = docs.filter((d) => d.id >= (state.startAt as string));
      docs = docs.slice(state.offsetBy);
      return state.limitTo === undefined ? docs : docs.slice(0, state.limitTo);
    };
    const next = (patch: Partial<QueryState>) => query(path, {...state, ...patch});
    const q = {
      where: (field: string, op: string, value: unknown) => next({filters: [...state.filters, [field, op, value]]}),
      orderBy: (field: unknown, dir: "asc" | "desc" = "asc") =>
        next({orders: [...state.orders, [typeof field === "string" ? field : "__name__", dir]]}),
      limit: (n: number) => next({limitTo: n}),
      offset: (n: number) => next({offsetBy: n}),
      startAt: (value: unknown) => next({startAt: value}),
      select: () => q,
      count: () => ({get: async () => ({data: () => ({count: rows().length})})}),
      get: async () => {
        const docs = rows();
        return {docs, empty: docs.length === 0, size: docs.length, forEach: (fn: (d: unknown) => void) => docs.forEach(fn)};
      },
    };
    return q;
  }

  function collection(path: string) {
    return {
      ...query(path, {filters: [], orders: [], offsetBy: 0}),
      doc: (id?: string) => ref(`${path}/${id ?? `auto${++auto}`}`),
      add: async (data: Doc) => {
        const added = ref(`${path}/auto${++auto}`);
        await added.set(data);
        return added;
      },
    };
  }

  t.mock.method(db, "collection", (name: string) => collection(name));
  t.mock.method(db, "doc", (path: string) => ref(path));
  t.mock.method(db, "runTransaction", async (callback: (tx: unknown) => Promise<unknown>) => {
    pending = [];
    let wrote = false;
    let failure: unknown;
    const guarded = <A extends unknown[]>(fn: (...args: A) => Promise<unknown>) => (...args: A) => {
      wrote = true;
      fn(...args).catch((err: unknown) => {
        failure ??= err;
      });
    };
    const tx = {
      get: async (target: {get: () => Promise<unknown>}) => {
        if (wrote) throw new Error("Firestore transaction reads must precede writes");
        return target.get();
      },
      set: guarded((r: FakeRef, data: Doc, options?: {merge?: boolean}) => r.set(data, options)),
      update: guarded((r: FakeRef, data: Doc) => r.update(data)),
      create: guarded((r: FakeRef, data: Doc) => r.create(data)),
      delete: guarded((r: FakeRef) => r.delete()),
    };
    try {
      const result = await callback(tx);
      if (failure) throw failure;
      const queued = pending;
      pending = null;
      queued.forEach((apply) => apply());
      return result;
    } finally {
      pending = null;
    }
  });
  return store;
}
