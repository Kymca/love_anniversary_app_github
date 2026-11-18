import {
  isReleaseManifest,
  selectCompatibleApkVariant,
  selectReleaseApk,
  supportedAndroidAbis,
} from "./release_manifest.ts";

const releaseManifest = {
  versionCode: 42,
  sha256: "b".repeat(64),
  apkObjectPath: "releases/42/app-release.apk",
  versionName: "1.2.3",
  packageName: "com.example.love_anniversary_app",
  releaseNotes: "Improvements",
  apkVariants: supportedAndroidAbis.map((abi) => ({
    abi,
    sha256: "a".repeat(64),
    apkObjectPath: `releases/42/app-${abi}.apk`,
  })),
};

Deno.test("validates complete and unique ABI variants in the release manifest", () => {
  assert(isReleaseManifest(releaseManifest));
  assert(
    !isReleaseManifest({
      ...releaseManifest,
      apkVariants: releaseManifest.apkVariants.slice(1),
    }),
  );
  assert(
    !isReleaseManifest({
      ...releaseManifest,
      apkVariants: [
        ...releaseManifest.apkVariants.slice(0, 2),
        releaseManifest.apkVariants[0],
      ],
    }),
  );
});

Deno.test("rejects variant paths or checksums that do not match the manifest", () => {
  assert(
    !isReleaseManifest({
      ...releaseManifest,
      apkVariants: releaseManifest.apkVariants.map((variant, index) =>
        index === 0
          ? { ...variant, apkObjectPath: "releases/41/app-arm64-v8a.apk" }
          : variant
      ),
    }),
  );
  assert(
    !isReleaseManifest({
      ...releaseManifest,
      apkVariants: releaseManifest.apkVariants.map((variant, index) =>
        index === 0 ? { ...variant, sha256: "invalid" } : variant
      ),
    }),
  );
});

Deno.test("selects the first ABI in Android device preference order", () => {
  assert(isReleaseManifest(releaseManifest));
  assertEquals(
    selectCompatibleApkVariant(releaseManifest, [
      "armeabi-v7a",
      "arm64-v8a",
    ])?.abi,
    "armeabi-v7a",
  );
  assertEquals(
    selectCompatibleApkVariant(releaseManifest, ["x86_64", "arm64-v8a"])?.abi,
    "x86_64",
  );
  assertEquals(
    selectCompatibleApkVariant(releaseManifest, ["riscv64"]),
    undefined,
  );
});

Deno.test("selects the universal APK for a legacy request without supportedAbis", () => {
  assert(isReleaseManifest(releaseManifest));
  assertEquals(
    selectReleaseApk(releaseManifest)?.apkObjectPath,
    "releases/42/app-release.apk",
  );
  assertEquals(selectReleaseApk(releaseManifest)?.sha256, "b".repeat(64));
  assertEquals(selectReleaseApk(releaseManifest)?.abi, undefined);
});

Deno.test("selects a split APK for a request with supportedAbis", () => {
  assert(isReleaseManifest(releaseManifest));
  assertEquals(
    selectReleaseApk(releaseManifest, ["armeabi-v7a", "arm64-v8a"])?.abi,
    "armeabi-v7a",
  );
  assertEquals(
    selectReleaseApk(releaseManifest, ["armeabi-v7a", "arm64-v8a"])
      ?.apkObjectPath,
    "releases/42/app-armeabi-v7a.apk",
  );
});

function assert(condition: boolean): asserts condition {
  if (!condition) throw new Error("Assertion failed.");
}

function assertEquals<T>(actual: T, expected: T): void {
  if (actual !== expected) {
    throw new Error(
      `Expected ${String(expected)}, received ${String(actual)}.`,
    );
  }
}
