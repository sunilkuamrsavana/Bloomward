import { HTTPError, json, securityHeaders } from "./http";
import { sync } from "./sync";
import { clerkWebhook } from "./webhook";

export default {
  async fetch(request, env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/webhooks/clerk") {
      try { return await clerkWebhook(request, env); }
      catch (error) {
        if (error instanceof HTTPError) return json({ error: error.code }, error.status);
        console.error(JSON.stringify({ event: "account_cleanup_failed" }));
        return json({ error: "temporarily_unavailable" }, 503);
      }
    }

    if (url.pathname === "/v1/sync") {
      try { return await sync(request, env); }
      catch (error) {
        if (error instanceof HTTPError) return json({ error: error.code }, error.status);
        console.error(JSON.stringify({ event: "sync_failed" }));
        return json({ error: "temporarily_unavailable" }, 503);
      }
    }
    if (url.pathname === "/v1" || url.pathname.startsWith("/v1/")) {
      return json({ error: "not_found" }, 404);
    }

    const knownPath = ["/", "/health", "/ready", "/robots.txt"].includes(url.pathname);
    if (!knownPath) return json({ error: "not_found" }, 404);
    if (request.method !== "GET" && request.method !== "HEAD") {
      return json({ error: "method_not_allowed" }, 405, { Allow: "GET, HEAD" });
    }

    let response: Response;
    if (url.pathname === "/health") {
      response = json({ service: "bloomward-api", status: "ok", sync: "enabled" });
    } else if (url.pathname === "/ready") {
      try {
        const row = await env.DB.prepare("SELECT COUNT(*) AS ready FROM sqlite_master WHERE type='table' AND name IN ('account_snapshots','deleted_accounts')").first<{ ready: number }>();
        response = row?.ready === 2
          ? json({ service: "bloomward-api", status: "ok", database: "reachable", sync: "enabled" })
          : json({ error: "not_ready" }, 503);
      } catch {
        // Never return database internals, credentials, or user data in public diagnostics.
        response = json({ error: "not_ready" }, 503);
      }
    } else if (url.pathname === "/robots.txt") {
      response = new Response("User-agent: *\nDisallow: /\n", {
        headers: { ...securityHeaders, "Content-Type": "text/plain; charset=utf-8" },
      });
    } else if (url.hostname === env.APP_HOST) {
      response = new Response("<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Bloomward</title><main><h1>Bloomward</h1><p>Small habits. A brighter you.</p><p>The iPhone app is in development. Signed-in accounts support cloud sync. Local mode remains on your iPhone.</p></main></html>", {
        headers: { ...securityHeaders, "Content-Type": "text/html; charset=utf-8" },
      });
    } else {
      response = json({ service: "bloomward-api", status: "ok", sync: "enabled" });
    }

    return request.method === "HEAD"
      ? new Response(null, { status: response.status, headers: response.headers })
      : response;
  },
} satisfies ExportedHandler<Env>;
