import { env, exports } from "cloudflare:workers";
import { beforeEach, describe, expect, it } from "vitest";
import { installSchema } from "./database";
beforeEach(installSchema);
describe("Bloomward service", () => {
  it("reports availability without exposing account data", async () => {
    const response = await exports.default.fetch("https://api.bloomward.inqox.com/health");
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ service: "bloomward-api", status: "ok", sync: "enabled" });
    expect(response.headers.get("Cache-Control")).toBe("no-store");
    expect(response.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });
  it("checks the schema is installed", async () => {
    const response = await exports.default.fetch("https://api.bloomward.inqox.com/ready");
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ database: "reachable", sync: "enabled" });
  });
  it.each(["GET", "POST", "PUT", "DELETE", "OPTIONS"])("rejects forged credentials on %s", async method => {
    const response = await exports.default.fetch("https://api.bloomward.inqox.com/v1/sync", {
      method, headers: { Authorization: "Bearer not-a-session", "X-User-Id": "someone-else" },
    });
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: "unauthorized" });
  });
  it("rejects caller IDs and cookies without a bearer session", async () => {
    expect((await exports.default.fetch("https://api.bloomward.inqox.com/v1/sync", {
      headers: { "X-User-Id": "user_victim", Cookie: "__session=fake" },
    })).status).toBe(401);
  });
  it("keeps API and app root responses distinct", async () => {
    const app = await exports.default.fetch("https://bloomward.inqox.com/");
    expect(app.headers.get("Content-Type")).toContain("text/html");
    expect(await app.text()).toContain("cloud sync");
    expect(await (await exports.default.fetch("https://api.bloomward.inqox.com/")).json()).toMatchObject({ service: "bloomward-api" });
  });
  it("returns 404 for unknown routes and 405 for unsupported public methods", async () => {
    expect((await exports.default.fetch("https://api.bloomward.inqox.com/v1/users/user_victim")).status).toBe(404);
    const response = await exports.default.fetch("https://api.bloomward.inqox.com/health", { method: "POST" });
    expect(response.status).toBe(405);
    expect(response.headers.get("Allow")).toBe("GET, HEAD");
  });
  it("supports HEAD and discourages indexing", async () => {
    const response = await exports.default.fetch("https://api.bloomward.inqox.com/health", { method: "HEAD" });
    expect(response.status).toBe(200);
    expect(await response.text()).toBe("");
    expect(await (await exports.default.fetch("https://bloomward.inqox.com/robots.txt")).text()).toBe("User-agent: *\nDisallow: /\n");
  });
});
