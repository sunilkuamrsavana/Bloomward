import { env } from "cloudflare:workers";
import migration from "../migrations/0001_sync.sql?raw";
export async function installSchema() {
  const statements = migration.replace(/--[^\n]*/g, "").split(";").map(s => s.trim()).filter(Boolean);
  await env.DB.batch(statements.map(sql => env.DB.prepare(sql)));
}
