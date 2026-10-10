import { createRemoteJWKSet, jwtVerify, type JWTVerifyGetKey } from "jose";
import { HTTPError } from "./http";

export const issuer = "https://clerk.bloomward.inqox.com";
// Public-key cache only; never cache a user's request, claims, or credentials.
const publicKeys = createRemoteJWKSet(new URL(`${issuer}/.well-known/jwks.json`), { timeoutDuration: 5000 });
const origins = new Set(["https://bloomward.inqox.com", "https://accounts.bloomward.inqox.com"]);

export async function authenticate(request: Request, keys: JWTVerifyGetKey = publicKeys): Promise<string> {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ") || authorization.length > 8192) throw new HTTPError(401, "unauthorized");
  try {
    const { payload } = await jwtVerify(authorization.slice(7), keys, {
      issuer, algorithms: ["RS256"], requiredClaims: ["sub", "sid", "exp", "nbf", "iat"],
      clockTolerance: 5,
    });
    if (typeof payload.sub !== "string" || !/^user_[a-zA-Z0-9]+$/.test(payload.sub)
        || typeof payload.sid !== "string" || !payload.sid.startsWith("sess_")
        || (payload.sts !== undefined && payload.sts !== "active")
        || (payload.azp !== undefined && (typeof payload.azp !== "string" || !origins.has(payload.azp)))) {
      throw new Error("Invalid session claims");
    }
    // Native sessions can omit azp. Cookies and caller-supplied user IDs are never accepted.
    return payload.sub;
  } catch { throw new HTTPError(401, "unauthorized"); }
}
