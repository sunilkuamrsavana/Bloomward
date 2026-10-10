import { env } from "cloudflare:workers";
import { beforeAll, beforeEach, describe, expect, it } from "vitest";
import { createLocalJWKSet, exportJWK, generateKeyPair, SignJWT, type JWTVerifyGetKey } from "jose";
import { authenticate, issuer } from "../src/auth";
import { sync } from "../src/sync";
import { snapshotSchema } from "../src/schema";
import { installSchema } from "./database";
let privateKey: CryptoKey;
let verifyKeys: JWTVerifyGetKey;
beforeAll(async () => {
  const pair = await generateKeyPair("RS256"); privateKey = pair.privateKey;
  verifyKeys = createLocalJWKSet({ keys: [{ ...await exportJWK(pair.publicKey), kid: "test-key", alg: "RS256" }] });
});
beforeEach(async () => {
  await installSchema();
  await env.DB.batch([env.DB.prepare("DELETE FROM account_snapshots"), env.DB.prepare("DELETE FROM deleted_accounts")]);
});
const empty = () => ({ schemaVersion: 1 as const, habits: [], routines: [], days: [], routineHistory: [], preferences: {} });
const habit = (title: string) => ({ id: "00000000-0000-4000-8000-000000000001", title, symbolName: "leaf", isArchived: false });
async function token(user = "user_alice", claims: Record<string, unknown> = {}) {
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({ sub: user, sid: "sess_test", iss: issuer, iat: now, nbf: now - 1, exp: now + 60, ...claims })
    .setProtectedHeader({ alg: "RS256", kid: "test-key" }).sign(privateKey);
}
async function request(user: string, method = "GET", body?: unknown) {
  return new Request("https://api.bloomward.inqox.com/v1/sync", {
    method, headers: { Authorization: `Bearer ${await token(user)}`, "Content-Type": "application/json", "X-User-Id": "user_victim" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}
const identify = (r: Request) => authenticate(r, verifyKeys);
const call = async (user: string, method = "GET", body?: unknown) => sync(await request(user, method, body), env, identify);
describe("Session validation", () => {
  it("accepts a valid native session without azp", async () => { expect(await identify(await request("user_alice"))).toBe("user_alice"); });
  it.each([{ exp: 1 }, { nbf: 9999999999 }, { iss: "https://another-app.clerk.accounts.dev" },
    { azp: "https://attacker.example" }, { sts: "pending" }, { sub: "not-a-clerk-user" }, { sid: null }])("rejects invalid claims %j", async claims => {
    const r = new Request("https://example.com", { headers: { Authorization: `Bearer ${await token("user_alice", claims)}` } });
    await expect(identify(r)).rejects.toMatchObject({ status: 401 });
  });
  it("rejects unsigned JWTs and modified signatures", async () => {
    const parts = (await token()).split(".");
    for (const value of [`${parts[0]}.${parts[1]}.AAAA`, "eyJhbGciOiJub25lIn0.eyJzdWIiOiJ1c2VyX2FsaWNlIn0."]) {
      await expect(identify(new Request("https://example.com", { headers: { Authorization: `Bearer ${value}` } }))).rejects.toMatchObject({ status: 401 });
    }
  });
});
describe("Account-owned cloud snapshots", () => {
  const planner = () => ({ ...empty(), schemaVersion: 3, planTasks: [{
    id: "00000000-0000-4000-8000-000000000040", title: "Work", notes: "", startsOn: {year: 2026, month: 10, day: 10},
    weekdays: [2,3,4,5,6], steps: [], isArchived: false,
  }], planOccurrences: [], dayNotes: [{
    id: "00000000-0000-4000-8000-000000000041", day: {year: 2026, month: 10, day: 10},
    title: "Ideas", body: "Private note", updatedAt: 800000000, isArchived: false,
  }] });
  it("round-trips planner tasks and notes without clearing legacy records", async () => {
    const snapshot = { ...planner(), habits: [habit("Workout")] };
    expect((await call("user_alice", "PUT", {baseRevision: 0, snapshot})).status).toBe(200);
    expect(await (await call("user_alice")).json()).toMatchObject({snapshot});
    expect(await (await call("user_bob")).json()).toMatchObject({snapshot: null});
  });
  it("blocks older clients from overwriting planner notes", async () => {
    await call("user_alice", "PUT", {baseRevision: 0, snapshot: planner()});
    await expect(call("user_alice", "PUT", {baseRevision: 1, snapshot: {...empty(), schemaVersion: 2}})).rejects.toMatchObject({status: 426});
  });
  it("rejects incomplete planner versions and planner fields in old schemas", () => {
    expect(snapshotSchema.safeParse({...empty(), schemaVersion: 3}).success).toBe(false);
    expect(snapshotSchema.safeParse({...planner(), schemaVersion: 2}).success).toBe(false);
  });
  it("rejects duplicate notes and invalid repeat weekdays", () => {
    const duplicate = planner(); duplicate.dayNotes.push(duplicate.dayNotes[0]!);
    expect(snapshotSchema.safeParse(duplicate).success).toBe(false);
    const invalid = planner(); invalid.planTasks[0]!.weekdays = [];
    expect(snapshotSchema.safeParse(invalid).success).toBe(false);
  });
  const nestedRoutine = () => ({
    id: "00000000-0000-4000-8000-000000000010", title: "Morning", symbolName: "leaf", isArchived: false,
    schedule: { weekdays: [2, 3] }, steps: [{
      id: "00000000-0000-4000-8000-000000000011", title: "Skincare", children: [{
        id: "00000000-0000-4000-8000-000000000012", title: "Wash", notes: "Gently",
        estimatedDurationSeconds: 120, schedule: { weekdays: [2], startMinute: 540 },
      }],
    }],
  });
  it("round-trips nested routines with inherited schedules and no habits", async () => {
    const snapshot = { ...empty(), schemaVersion: 2, routines: [nestedRoutine()] };
    expect((await call("user_alice", "PUT", { baseRevision: 0, snapshot })).status).toBe(200);
    expect(await (await call("user_alice")).json()).toMatchObject({ revision: 1, snapshot });
  });
  it("requires the new schema version for extended routines", () => {
    expect(snapshotSchema.safeParse({ ...empty(), routines: [nestedRoutine()] }).success).toBe(false);
  });
  it("atomically refuses older clients overwriting the new structure", async () => {
    const snapshot = { ...empty(), schemaVersion: 2, routines: [nestedRoutine()] };
    await call("user_alice", "PUT", { baseRevision: 0, snapshot });
    await expect(call("user_alice", "PUT", { baseRevision: 1, snapshot: empty() })).rejects.toMatchObject({ status: 426 });
    expect(await (await call("user_alice")).json()).toMatchObject({ revision: 1, snapshot });
  });
  it("accepts an existing version-one account upgrading without clearing data", async () => {
    const snapshot = { ...empty(), habits: [habit("Read")] };
    await call("user_alice", "PUT", { baseRevision: 0, snapshot });
    const upgraded = { ...snapshot, schemaVersion: 2, routines: [nestedRoutine()] };
    expect((await call("user_alice", "PUT", { baseRevision: 1, snapshot: upgraded })).status).toBe(200);
    expect(await (await call("user_alice")).json()).toMatchObject({ revision: 2, snapshot: upgraded });
  });
  it("rejects duplicate nested IDs and incompatible or empty schedules", () => {
    const duplicate = nestedRoutine();
    duplicate.steps[0]!.children[0]!.id = duplicate.steps[0]!.id;
    const incompatible = nestedRoutine();
    incompatible.steps[0]!.children[0]!.schedule.weekdays = [7];
    const emptyDays = nestedRoutine();
    emptyDays.schedule.weekdays = [];
    for (const routine of [duplicate, incompatible, emptyDays]) {
      expect(snapshotSchema.safeParse({ ...empty(), schemaVersion: 2, routines: [routine] }).success).toBe(false);
    }
  });
  it("rejects excessive nesting before traversing unbounded input", () => {
    let item: Record<string, unknown> = { id: crypto.randomUUID(), title: "Step" };
    for (let depth = 0; depth < 8; depth++) item = { id: crypto.randomUUID(), title: "Group", children: [item] };
    expect(snapshotSchema.safeParse({ ...empty(), schemaVersion: 2, routines: [{ ...nestedRoutine(), steps: [item] }] }).success).toBe(false);
  });
  it("round-trips a backup to a second client of the same account", async () => {
    const snapshot = { ...empty(), habits: [habit("Water")] };
    expect(await (await call("user_alice")).json()).toMatchObject({ revision: 0, snapshot: null });
    expect((await call("user_alice", "PUT", { baseRevision: 0, snapshot })).status).toBe(200);
    expect(await (await call("user_alice")).json()).toMatchObject({ revision: 1, snapshot });
  });
  it("isolates accounts despite caller-supplied IDs", async () => {
    await call("user_alice", "PUT", { baseRevision: 0, snapshot: { ...empty(), habits: [habit("Private")] } });
    expect(await (await call("user_bob")).json()).toMatchObject({ revision: 0, snapshot: null });
    await call("user_bob", "PUT", { baseRevision: 0, snapshot: empty() });
    expect(await (await call("user_alice")).json()).toMatchObject({ revision: 1, snapshot: { habits: [habit("Private")] } });
  });
  it("rejects stale writes and returns the current revision", async () => {
    const snapshot = { ...empty(), habits: [habit("Original")] };
    await call("user_alice", "PUT", { baseRevision: 0, snapshot });
    const stale = await call("user_alice", "PUT", { baseRevision: 0, snapshot: empty() });
    expect(stale.status).toBe(409);
    expect(await stale.json()).toMatchObject({ revision: 1, snapshot });
  });
  it("allows exactly one competing write at the same revision", async () => {
    await call("user_alice", "PUT", { baseRevision: 0, snapshot: empty() });
    const responses = await Promise.all(["A", "B"].map(title => call("user_alice", "PUT", { baseRevision: 1, snapshot: { ...empty(), habits: [habit(title)] } })));
    expect(responses.map(r => r.status).sort()).toEqual([200, 409]);
    expect(await (await call("user_alice")).json()).toMatchObject({ revision: 2 });
  });
  it("retains record deletions", async () => {
    await call("user_alice", "PUT", { baseRevision: 0, snapshot: { ...empty(), habits: [habit("Delete me")] } });
    await call("user_alice", "PUT", { baseRevision: 1, snapshot: empty() });
    expect(await (await call("user_alice")).json()).toMatchObject({ revision: 2, snapshot: empty() });
  });
  it("rejects oversized bodies before parsing", async () => {
    await expect(call("user_alice", "PUT", { data: "x".repeat(530000) })).rejects.toMatchObject({ status: 413 });
  });
  it("rejects duplicate IDs, unknown versions and injected owners", async () => {
    for (const snapshot of [{ ...empty(), schemaVersion: 4 }, { ...empty(), userID: "user_victim" }, { ...empty(), habits: [habit("A"), habit("B")] }]) {
      await expect(call("user_alice", "PUT", { baseRevision: 0, snapshot })).rejects.toMatchObject({ status: 422 });
    }
  });
  it("cannot resurrect a deleted account with an unexpired session", async () => {
    await env.DB.prepare("INSERT INTO deleted_accounts VALUES (?, ?)").bind("user_alice", new Date().toISOString()).run();
    await expect(call("user_alice")).rejects.toMatchObject({ status: 403 });
    await expect(call("user_alice", "PUT", { baseRevision: 0, snapshot: empty() })).rejects.toMatchObject({ status: 403 });
  });
  it("validates the iOS wire format with settings and progress", () => {
    const snapshot = { ...empty(), habits: [{ ...habit("Water"), settings: {
      category: "Health", weekdays: [2,4,6], timeWindowEnabled: true, startMinute: 960, endMinute: 1140,
      carryForward: true, allowsRest: true, isPaused: false, endOfDayMinute: 1380, reminderStyle: "Persistent", notes: "",
      createdOn: { year: 2026, month: 9, day: 21 },
    } }], days: [{ day: { year: 2026, month: 9, day: 21 }, entries: [{ habitID: habit("").id, status: "completed", updatedAt: 81234.5 }] }] };
    expect(snapshotSchema.safeParse(snapshot).success).toBe(true);
  });
});
