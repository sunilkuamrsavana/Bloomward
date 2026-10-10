import { env } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { Webhook } from "standardwebhooks";
import { clerkWebhook } from "../src/webhook";
import { installSchema } from "./database";
// Random, local-test-only signing key; never a production credential.
const secret = `whsec_${btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))))}`;
const testEnv = { ...env, CLERK_WEBHOOK_SIGNING_SECRET: secret };
beforeEach(async () => {
  await installSchema();
  await env.DB.batch([env.DB.prepare("DELETE FROM account_snapshots"), env.DB.prepare("DELETE FROM deleted_accounts")]);
});
function request(body: string, time = new Date(), signedBody = body) {
  const id = "msg_test";
  return new Request("https://api.bloomward.inqox.com/webhooks/clerk", { method: "POST", body, headers: {
    "svix-id": id, "svix-timestamp": String(Math.floor(time.getTime() / 1000)),
    "svix-signature": new Webhook(secret).sign(id, time, signedBody),
  } });
}
const body = JSON.stringify({ type: "user.deleted", data: { id: "user_testdeletion", deleted: true } });
describe("Account deletion webhook", () => {
  it("removes only the deleted account and tolerates duplicate delivery", async () => {
    for (const id of ["user_testdeletion", "user_other"]) {
      await env.DB.prepare("INSERT INTO account_snapshots VALUES (?, 1, '{}', ?)").bind(id, new Date().toISOString()).run();
    }
    expect((await clerkWebhook(request(body), testEnv)).status).toBe(200);
    expect((await clerkWebhook(request(body), testEnv)).status).toBe(200);
    expect(await env.DB.prepare("SELECT user_id FROM account_snapshots").all()).toMatchObject({ results: [{ user_id: "user_other" }] });
    expect(await env.DB.prepare("SELECT user_id FROM deleted_accounts").all()).toMatchObject({ results: [{ user_id: "user_testdeletion" }] });
  });
  it("rejects forged and expired signatures", async () => {
    await expect(clerkWebhook(request(body, new Date(), "tampered"), testEnv)).rejects.toMatchObject({ status: 400 });
    await expect(clerkWebhook(request(body, new Date(0)), testEnv)).rejects.toMatchObject({ status: 400 });
    expect((await env.DB.prepare("SELECT user_id FROM deleted_accounts").all()).results).toEqual([]);
  });
  it("fails closed when the secret is not configured", async () => {
    await expect(clerkWebhook(request(body), { ...testEnv, CLERK_WEBHOOK_SIGNING_SECRET: "" })).rejects.toMatchObject({ status: 503 });
  });
});
