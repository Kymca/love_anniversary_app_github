export const supportedAndroidAbis = [
  "arm64-v8a",
  "armeabi-v7a",
  "x86_64",
] as const;
export const expectedPackageName = "com.example.love_anniversary_app";

type AndroidAbi = (typeof supportedAndroidAbis)[number];

export type ReleaseApkVariant = {
  abi: AndroidAbi;
  sha256: string;
  apkObjectPath: string;
};

export type ReleaseManifest = {
  versionCode: number;
  sha256: string;
  apkObjectPath: string;
  versionName: string;
  packageName: string;
  releaseNotes: string;
  apkVariants: ReleaseApkVariant[];
};

export type SelectedReleaseApk = {
  abi?: AndroidAbi;
  sha256: string;
  apkObjectPath: string;
};

const maximumReleaseNotesLength = 8_000;

function isReleaseApkVariant(
  value: unknown,
  versionCode: number,
): value is ReleaseApkVariant {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }
  const variant = value as Record<string, unknown>;
  return typeof variant.abi === "string" &&
    supportedAndroidAbis.some((abi) => abi === variant.abi) &&
    typeof variant.sha256 === "string" &&
    /^[a-fA-F0-9]{64}$/.test(variant.sha256) &&
    variant.apkObjectPath ===
      `releases/${versionCode}/app-${variant.abi}.apk`;
}

export function isReleaseManifest(value: unknown): value is ReleaseManifest {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return false;
  }
  const manifest = value as Record<string, unknown>;
  if (
    typeof manifest.versionCode !== "number" ||
    !Number.isSafeInteger(manifest.versionCode) ||
    manifest.versionCode <= 0 ||
    typeof manifest.sha256 !== "string" ||
    !/^[a-fA-F0-9]{64}$/.test(manifest.sha256) ||
    manifest.apkObjectPath !==
      `releases/${manifest.versionCode}/app-release.apk` ||
    typeof manifest.versionName !== "string" ||
    manifest.versionName.length === 0 ||
    manifest.versionName.length > 64 ||
    manifest.packageName !== expectedPackageName ||
    typeof manifest.releaseNotes !== "string" ||
    manifest.releaseNotes.length > maximumReleaseNotesLength ||
    !Array.isArray(manifest.apkVariants) ||
    manifest.apkVariants.length !== supportedAndroidAbis.length
  ) {
    return false;
  }

  const variantAbis = new Set<string>();
  for (const variant of manifest.apkVariants) {
    if (
      !isReleaseApkVariant(variant, manifest.versionCode) ||
      variantAbis.has(variant.abi)
    ) {
      return false;
    }
    variantAbis.add(variant.abi);
  }
  return supportedAndroidAbis.every((abi) => variantAbis.has(abi));
}

export function selectCompatibleApkVariant(
  manifest: ReleaseManifest,
  requestedAbis: readonly string[],
): ReleaseApkVariant | undefined {
  for (const abi of requestedAbis) {
    const variant = manifest.apkVariants.find((candidate) =>
      candidate.abi === abi
    );
    if (variant) return variant;
  }
  return undefined;
}

export function selectReleaseApk(
  manifest: ReleaseManifest,
  requestedAbis?: readonly string[],
): SelectedReleaseApk | undefined {
  if (requestedAbis === undefined) {
    return {
      sha256: manifest.sha256,
      apkObjectPath: manifest.apkObjectPath,
    };
  }
  const variant = selectCompatibleApkVariant(manifest, requestedAbis);
  return variant
    ? {
      abi: variant.abi,
      sha256: variant.sha256,
      apkObjectPath: variant.apkObjectPath,
    }
    : undefined;
}
