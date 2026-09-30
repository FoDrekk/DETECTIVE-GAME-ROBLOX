"use strict";
/*
  The script manifest shared by the Studio sync tools.

  Reads the Rojo project (default.project.json) and lists every Luau file it maps
  to a Studio script: its Studio path ("ServerScriptService.Server.OfficeRoom"),
  its class, and its source with "\r" stripped (Windows checkouts carry CRLF; Studio
  sources are LF).

  The fingerprint is the same one the Studio side computes: h = (h * 31 + byte) mod
  2^32 over the UTF-8 bytes of the CR-stripped source, alongside the byte length.
*/
const fs = require("fs");
const path = require("path");

function fingerprint(source) {
  const buf = Buffer.from(source, "utf8");
  let h = 0;
  for (const byte of buf) {
    h = (h * 31 + byte) % 4294967296;
  }
  return { length: buf.length, hash: h };
}

function readSource(file) {
  return fs.readFileSync(file).toString("utf8").replace(/\r/g, "");
}

function buildManifest(root, projectFile = "default.project.json") {
  const project = JSON.parse(fs.readFileSync(path.join(root, projectFile), "utf8"));
  const entries = new Map();

  function add(studioPath, className, file) {
    const source = readSource(file);
    const print = fingerprint(source);
    entries.set(studioPath, { path: studioPath, class: className, length: print.length, hash: print.hash, source });
  }

  function classFor(file) {
    if (file.endsWith(".server.luau")) return "Script";
    if (file.endsWith(".client.luau")) return "LocalScript";
    return "ModuleScript";
  }

  function walk(dir, studioPath) {
    const names = fs.readdirSync(dir);
    for (const [initName, className] of [
      ["init.server.luau", "Script"],
      ["init.client.luau", "LocalScript"],
      ["init.luau", "ModuleScript"],
    ]) {
      if (names.includes(initName)) {
        add(studioPath, className, path.join(dir, initName));
      }
    }
    for (const name of names) {
      const full = path.join(dir, name);
      if (fs.statSync(full).isDirectory()) {
        walk(full, `${studioPath}.${name}`);
        continue;
      }
      if (name.startsWith("init.") || !name.endsWith(".luau")) {
        continue;
      }
      const base = name.replace(/\.(server|client)\.luau$/, "").replace(/\.luau$/, "");
      add(`${studioPath}.${base}`, classFor(name), full);
    }
  }

  function visit(node, studioPath) {
    if (node.$path) {
      const target = path.join(root, node.$path);
      if (fs.statSync(target).isDirectory()) {
        walk(target, studioPath);
      } else if (target.endsWith(".luau")) {
        add(studioPath, classFor(target), target);
      }
    }
    for (const [key, child] of Object.entries(node)) {
      if (!key.startsWith("$")) {
        visit(child, `${studioPath}.${key}`);
      }
    }
  }

  for (const [key, node] of Object.entries(project.tree)) {
    if (!key.startsWith("$")) {
      visit(node, key);
    }
  }
  return [...entries.values()].sort((a, b) => (a.path < b.path ? -1 : 1));
}

module.exports = { buildManifest, fingerprint };

if (require.main === module) {
  const root = path.resolve(process.argv[2] || ".");
  for (const entry of buildManifest(root)) {
    console.log(`${entry.path}|${entry.class}|${entry.length}|${entry.hash}`);
  }
}
