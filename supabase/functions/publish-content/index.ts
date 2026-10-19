// publish-content: receives a content bundle from GitHub Actions and
// publishes it to the public `content` bucket.
//
// Auth: no shared secret. The caller must present a GitHub Actions OIDC token
// issued to this repository's main branch with our audience. The function
// then writes with its built-in service role key.
//
// Layout in the bucket:
//   v1/bundles/<sha256>.json   immutable, cached for a year
//   v1/manifest.json           points at the current bundle, cached 60 s
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5.9.6";
import { createClient } from "npm:@supabase/supabase-js@2";

const ISSUER = "https://token.actions.githubusercontent.com";
const AUDIENCE = "islamic-kids-app-publish";
const REPOSITORY = "jibrilmohamod/islamic-kids-app";
const REF = "refs/heads/main";
const SCHEMA_VERSION = 1;
const MAX_BYTES = 5 * 1024 * 1024;

const jwks = createRemoteJWKSet(new URL(`${ISSUER}/.well-known/jwks`));

const json = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json(405, { error: "POST only" });

  // 1. Who is calling?
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  try {
    const { payload } = await jwtVerify(token, jwks, { issuer: ISSUER, audience: AUDIENCE });
    if (payload.repository !== REPOSITORY || payload.ref !== REF) {
      return json(403, { error: "token not issued to the main branch of this repository" });
    }
  } catch {
    return json(401, { error: "invalid or missing GitHub OIDC token" });
  }

  // 2. Is it a bundle this app version understands?
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.length === 0 || bytes.length > MAX_BYTES) return json(413, { error: "bad size" });
  let bundle: Record<string, unknown>;
  try {
    bundle = JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    return json(400, { error: "not JSON" });
  }
  if (bundle.schemaVersion !== SCHEMA_VERSION) return json(400, { error: "unsupported schemaVersion" });
  if (typeof bundle.bundleVersion !== "string") return json(400, { error: "missing bundleVersion" });
  if (!Array.isArray(bundle.surahs) || bundle.surahs.length === 0) return json(400, { error: "no surahs" });

  // 3. Publish: immutable bundle first, then move the manifest to it.
  const sha256 = await sha256Hex(bytes);
  const path = `v1/bundles/${sha256}.json`;
  const storage = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  ).storage.from("content");

  const up = await storage.upload(path, bytes, {
    contentType: "application/json",
    cacheControl: "31536000",
    upsert: true,
  });
  if (up.error) return json(500, { error: `bundle upload: ${up.error.message}` });

  const manifest = {
    schemaVersion: SCHEMA_VERSION,
    bundleVersion: bundle.bundleVersion,
    sha256,
    size: bytes.length,
    path,
    publishedAt: new Date().toISOString(),
  };
  const man = await storage.upload("v1/manifest.json", new TextEncoder().encode(JSON.stringify(manifest)), {
    contentType: "application/json",
    cacheControl: "60",
    upsert: true,
  });
  if (man.error) return json(500, { error: `manifest upload: ${man.error.message}` });

  return json(200, manifest);
});
