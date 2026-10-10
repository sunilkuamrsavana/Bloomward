import { Webhook } from "standardwebhooks";
import { z } from "zod";
import { boundedText, HTTPError, json } from "./http";

const eventSchema = z.object({ type: z.string(), data: z.object({ id: z.string().regex(/^user_[a-zA-Z0-9]+$/), deleted: z.literal(true) }) });
export async function clerkWebhook(request: Request, env: Env): Promise<Response> {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405, { Allow: "POST" });
  if (!env.CLERK_WEBHOOK_SIGNING_SECRET) throw new HTTPError(503, "webhook_not_configured");
  const body = await boundedText(request, 64 * 1024);
  let event: unknown;
  try {
    event = new Webhook(env.CLERK_WEBHOOK_SIGNING_SECRET).verify(body, {
      "webhook-id": request.headers.get("svix-id") ?? "",
      "webhook-timestamp": request.headers.get("svix-timestamp") ?? "",
      "webhook-signature": request.headers.get("svix-signature") ?? "",
    });
  } catch { throw new HTTPError(400, "invalid_webhook_signature"); }
  const type = z.object({ type: z.string() }).safeParse(event);
  if (!type.success) throw new HTTPError(400, "invalid_event");
  if (type.data.type !== "user.deleted") return json({ received: true });
  const parsed = eventSchema.safeParse(event);
  if (!parsed.success) throw new HTTPError(400, "invalid_event");
  const userID = parsed.data.data.id;
  // Atomic and idempotent: retrying a genuine deletion cannot revive data.
  await env.DB.batch([
    env.DB.prepare("INSERT INTO deleted_accounts (user_id, deleted_at) VALUES (?, ?) ON CONFLICT(user_id) DO NOTHING").bind(userID, new Date().toISOString()),
    env.DB.prepare("DELETE FROM account_snapshots WHERE user_id = ?").bind(userID),
  ]);
  return json({ received: true });
}
