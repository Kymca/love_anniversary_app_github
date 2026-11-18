import { createClient } from "npm:@supabase/supabase-js@2";
import {
  expectedPackageName,
  isReleaseManifest,
  selectReleaseApk,
} from "./release_manifest.ts";

const bucketName = "app-releases";
const manifestPath = "releases/latest.json";
const signedUrlLifetimeSeconds = 300;
const maximumManifestBytes = 16 * 1024;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, x-client-info, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: corsHeaders,
  });
}

async function readLimitedBody(request: Request): Promise<string> {
  const reader = request.body?.getReader();
  if (!reader) {
    throw new SyntaxError("Request body is missing.");
  }

  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > 4_096) {
      await reader.cancel();
      throw new RangeError("Request body exceeds the allowed size.");
    }
    chunks.push(value);
  }

  const body = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(body);
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }
  let requestBody: unknown;
  try {
    requestBody = JSON.parse(await readLimitedBody(request));
  } catch (error) {
    if (error instanceof RangeError) {
      return jsonResponse({ error: "Request is too large." }, 413);
    }
    return jsonResponse({ error: "Invalid JSON request." }, 400);
  }
  if (typeof requestBody !== "object" || requestBody === null) {
    return jsonResponse({ error: "Invalid update request." }, 400);
  }

  const parsedRequest = requestBody as Record<string, unknown>;
  const { versionCode, packageName, supportedAbis } = parsedRequest;
  if (
    typeof versionCode !== "number" ||
    !Number.isSafeInteger(versionCode) ||
    versionCode < 0 ||
    packageName !== expectedPackageName
  ) {
    return jsonResponse({ error: "Invalid package or version code." }, 400);
  }
  const requestedAbis: string[] = [];
  const hasSupportedAbis = Object.hasOwn(parsedRequest, "supportedAbis");
  if (hasSupportedAbis) {
    if (
      !Array.isArray(supportedAbis) ||
      supportedAbis.length === 0 ||
      supportedAbis.length > 16
    ) {
      return jsonResponse({ error: "Invalid supported ABI list." }, 400);
    }
    for (const abi of supportedAbis) {
      if (typeof abi !== "string" || !/^[a-zA-Z0-9_-]{1,32}$/.test(abi)) {
        return jsonResponse({ error: "Invalid supported ABI list." }, 400);
      }
      requestedAbis.push(abi);
    }
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    console.error("Update function server credentials are not configured.");
    return jsonResponse({ error: "Update service is unavailable." }, 503);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: manifestFile, error: manifestError } = await admin.storage
    .from(bucketName)
    .download(manifestPath);
  if (manifestError || !manifestFile) {
    console.error("Could not read the latest update manifest.", manifestError);
    return jsonResponse({ error: "Update manifest is unavailable." }, 503);
  }
  if (manifestFile.size > maximumManifestBytes) {
    console.error("The latest update manifest exceeds its size limit.");
    return jsonResponse({ error: "Update manifest is invalid." }, 503);
  }

  let manifestJson: unknown;
  try {
    manifestJson = JSON.parse(await manifestFile.text());
  } catch {
    console.error("The latest update manifest is not valid JSON.");
    return jsonResponse({ error: "Update manifest is invalid." }, 503);
  }
  if (!isReleaseManifest(manifestJson)) {
    console.error("The latest update manifest failed validation.");
    return jsonResponse({ error: "Update manifest is invalid." }, 503);
  }

  const manifest = manifestJson;
  if ((versionCode as number) >= manifest.versionCode) {
    return jsonResponse({ updateAvailable: false });
  }

  const selectedApk = selectReleaseApk(
    manifest,
    hasSupportedAbis ? requestedAbis : undefined,
  );
  if (!selectedApk) {
    return jsonResponse(
      { error: "No compatible APK variant is available." },
      422,
    );
  }

  const { data: signedAsset, error: signedUrlError } = await admin.storage
    .from(bucketName)
    .createSignedUrl(selectedApk.apkObjectPath, signedUrlLifetimeSeconds);
  if (signedUrlError || !signedAsset?.signedUrl) {
    console.error("Could not sign the update APK URL.", signedUrlError);
    return jsonResponse({ error: "Update download is unavailable." }, 503);
  }

  const signedUrl = new URL(signedAsset.signedUrl, supabaseUrl);
  const expectedStoragePath =
    `/storage/v1/object/sign/${bucketName}/${selectedApk.apkObjectPath}`;
  if (
    signedUrl.protocol !== "https:" ||
    signedUrl.host !== new URL(supabaseUrl).host ||
    signedUrl.pathname !== expectedStoragePath ||
    !signedUrl.searchParams.has("token")
  ) {
    console.error("Generated update URL failed validation.");
    return jsonResponse({ error: "Update download is unavailable." }, 503);
  }

  const response: Record<string, unknown> = {
    updateAvailable: true,
    versionCode: manifest.versionCode,
    versionName: manifest.versionName,
    packageName: manifest.packageName,
    releaseNotes: manifest.releaseNotes,
    sha256: selectedApk.sha256,
    apkObjectPath: selectedApk.apkObjectPath,
    downloadUrl: signedUrl.toString(),
  };
  if (selectedApk.abi) response.abi = selectedApk.abi;
  return jsonResponse(response);
});
