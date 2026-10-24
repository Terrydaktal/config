import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, posix } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const sourceDirectory = dirname(fileURLToPath(import.meta.url));
const config = readFileSync(join(sourceDirectory, "firefox-autoconfig.cfg"), "utf8");
const required = ["autoconfig/british-dictionary.js", "autoconfig/reverse-autoscroll.js"];
const bridge = "applicationlauncher-audio-bridge.js";

function runLoader({ available = [...required, bridge], fail = null } = {}) {
  const loaded = [], errors = [];
  const files = new Set(available.map(path => "/firefox/" + path));
  class File {
    constructor(path) { this.path = path; }
    clone() { return new File(this.path); }
    append(component) { this.path = posix.join(this.path, component); }
    exists() { return files.has(this.path); }
  }
  const services = {
    "@mozilla.org/file/directory_service;1": { get: () => new File("/firefox") },
    "@mozilla.org/network/io-service;1": { newFileURI: file => ({ spec: file.path }) },
    "@mozilla.org/moz/jssubscript-loader;1": {
      loadSubScript(path) {
        if (!files.has(path) || path === "/firefox/" + fail) {
          throw new Error("unavailable feature");
        }
        loaded.push(path.replace("/firefox/", ""));
      },
    },
  };
  vm.runInNewContext(config, {
    Components: {
      classes: Object.fromEntries(Object.entries(services).map(([id, service]) => [id, { getService: () => service }])),
      interfaces: {},
      utils: { reportError: error => errors.push(String(error)) },
    },
  });
  return { loaded, errors };
}

function installation(t) {
  const directory = mkdtempSync(join(tmpdir(), "config-firefox-install-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  mkdirSync(join(directory, "defaults/pref"), { recursive: true });
  writeFileSync(join(directory, "application.ini"), "[App]\nName=Firefox\n");
  return directory;
}

function install(directory) {
  execFileSync("bash", [join(sourceDirectory, "install-autoconfig.sh"), directory]);
}

test("shared entry point loads each feature once", () => {
  assert.ok(config.startsWith("//"));
  assert.deepEqual(runLoader(), { loaded: [...required, bridge], errors: [] });
});

test("an absent optional audio bridge does not block the browser features", () => {
  assert.deepEqual(runLoader({ available: required }), { loaded: required, errors: [] });
});

test("a failing feature does not prevent later features from loading", () => {
  const { loaded, errors } = runLoader({ fail: required[0] });
  assert.deepEqual(loaded, [required[1], bridge]);
  assert.equal(errors.length, 1);
  assert.ok(errors[0].includes(required[0]));
});

test("a missing required feature is reported, not silently ignored", () => {
  const { loaded, errors } = runLoader({ available: [bridge] });
  assert.deepEqual(loaded, [bridge]);
  assert.equal(errors.length, 2);
});

test("fresh provisioning installs the shared bundle without requiring applicationlauncher", t => {
  const directory = installation(t);
  install(directory);
  assert.equal(readFileSync(join(directory, "firefox-autoconfig.cfg"), "utf8"), config);
  for (const path of [...required, "autoscroll/ReverseAutoScrollChild.sys.mjs", "autoscroll/scroll-range.sys.mjs"]) {
    assert.equal(readFileSync(join(directory, path), "utf8"), readFileSync(join(sourceDirectory, path), "utf8"));
    assert.equal(statSync(join(directory, path)).mode & 0o777, 0o644);
  }
  const preferences = readFileSync(join(directory, "defaults/pref/99-firefox-autoconfig.js"), "utf8");
  assert.ok(preferences.includes('"general.config.filename", "firefox-autoconfig.cfg"'));
  assert.equal(existsSync(join(directory, "defaults/pref/zz-applicationlauncher-audio-bridge.js")), false);
});

test("migration retargets both selectors, preserves audio, and is repeatable", t => {
  const directory = installation(t);
  const legacy = "// Previous dictionary, autoscroll and audio configuration.\n";
  const preferences = 'pref("general.config.filename", "british-dictionary.cfg");\n';
  writeFileSync(join(directory, "british-dictionary.cfg"), legacy);
  writeFileSync(join(directory, "defaults/pref/99-british-dictionary-autoconfig.js"), preferences);
  writeFileSync(join(directory, "defaults/pref/zz-applicationlauncher-audio-bridge.js"), preferences);
  writeFileSync(join(directory, bridge), "// Existing audio bridge, owned by applicationlauncher.\n");
  for (let attempt = 0; attempt < 2; attempt++) {
    install(directory);
    assert.equal(existsSync(join(directory, "british-dictionary.cfg")), false);
    assert.equal(existsSync(join(directory, "defaults/pref/99-british-dictionary-autoconfig.js")), false);
    assert.equal(readFileSync(join(directory, "british-dictionary.cfg.before-firefox-autoconfig"), "utf8"), legacy);
    assert.equal(statSync(join(directory, "british-dictionary.cfg.before-firefox-autoconfig")).mode & 0o777, 0o600);
    assert.equal(readFileSync(join(directory, bridge), "utf8"), "// Existing audio bridge, owned by applicationlauncher.\n");
    for (const file of readdirSync(join(directory, "defaults/pref"))) {
      const contents = readFileSync(join(directory, "defaults/pref", file), "utf8");
      assert.ok(contents.includes('"general.config.filename", "firefox-autoconfig.cfg"'));
      assert.ok(!contents.includes("british-dictionary.cfg"));
    }
  }
});

test("migration rejects redirected destinations before changing any files", t => {
  const directory = installation(t);
  const existing = join(directory, "unrelated.js");
  writeFileSync(existing, "// Do not replace me.\n");
  symlinkSync(existing, join(directory, "defaults/pref/zz-applicationlauncher-audio-bridge.js"));
  const result = spawnSync("bash", [join(sourceDirectory, "install-autoconfig.sh"), directory], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.ok(result.stderr.includes("Refusing non-regular destination"));
  assert.equal(readFileSync(existing, "utf8"), "// Do not replace me.\n");
  assert.equal(existsSync(join(directory, "firefox-autoconfig.cfg")), false);
});
