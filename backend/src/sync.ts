import { authenticate } from "./auth";
import { boundedText, HTTPError, json } from "./http";
import { uploadSchema } from "./schema";

interface SnapshotRow { revision: number; snapshot: string; updated_at: string }
function envelope(row: SnapshotRow | null) {
  return row ? { revision: row.revision, snapshot: JSON.parse(row.snapshot), updatedAt: row.updated_at }
    : { revision: 0, snapshot: null, updatedAt: null };
}
export async function sync(request: Request, env: Env, identify = authenticate): Promise<Response> {
  const userID = await identify(request);
  if (request.method !== "GET" && request.method !== "PUT") return json({ error: "method_not_allowed" }, 405, { Allow: "GET, PUT" });
  if (await env.DB.prepare("SELECT 1 FROM deleted_accounts WHERE user_id = ?").bind(userID).first()) throw new HTTPError(403, "account_deleted");
  if (request.method === "GET") {
    const row = await env.DB.prepare("SELECT revision, snapshot, updated_at FROM account_snapshots WHERE user_id = ?").bind(userID).first<SnapshotRow>();
    return json(envelope(row));
  }
  if (request.headers.get("Content-Type")?.split(";")[0].trim() !== "application/json") throw new HTTPError(415, "json_required");
  let parsed: unknown;
  try { parsed = JSON.parse(await boundedText(request)); }
  catch (error) { if (error instanceof HTTPError) throw error; throw new HTTPError(400, "invalid_json"); }
  const result = uploadSchema.safeParse(parsed);
  if (!result.success) throw new HTTPError(422, "invalid_snapshot");
  const { baseRevision, snapshot } = result.data;
  // Atomic compare-and-swap: a stale device can never replace a newer revision.
  // The deletion predicate is also inside this statement to close a webhook/write race.
  const row = await env.DB.prepare(`
    INSERT INTO account_snapshots (user_id, revision, snapshot, updated_at)
    SELECT ?, 1, ?, ? WHERE NOT EXISTS (SELECT 1 FROM deleted_accounts WHERE user_id = ?)
      AND (? = 0 OR EXISTS (SELECT 1 FROM account_snapshots WHERE user_id = ?))
    ON CONFLICT(user_id) DO UPDATE SET revision = account_snapshots.revision + 1,
      snapshot = excluded.snapshot, updated_at = excluded.updated_at
    WHERE account_snapshots.revision = ?
      AND json_extract(account_snapshots.snapshot, '$.schemaVersion') <= json_extract(excluded.snapshot, '$.schemaVersion')
    RETURNING revision, snapshot, updated_at
  `).bind(userID, JSON.stringify(snapshot), new Date().toISOString(), userID, baseRevision, userID, baseRevision).first<SnapshotRow>();
  if (row) return json(envelope(row));
  if (await env.DB.prepare("SELECT 1 FROM deleted_accounts WHERE user_id = ?").bind(userID).first()) throw new HTTPError(403, "account_deleted");
  const current = await env.DB.prepare("SELECT revision, snapshot, updated_at FROM account_snapshots WHERE user_id = ?").bind(userID).first<SnapshotRow>();
  if (current && JSON.parse(current.snapshot).schemaVersion > snapshot.schemaVersion) throw new HTTPError(426, "app_update_required");
  return json(envelope(current), 409);
}
