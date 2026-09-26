#!/usr/bin/env node
/*
  Writes a Rojo-compatible sourcemap.json for default.project.json (same
  format as `rojo sourcemap`), so luau-lsp can resolve Roblox-style requires
  when type-checking without Rojo installed:

    node tools/headless/sourcemap.js > sourcemap.json
    luau-lsp analyze --sourcemap=sourcemap.json --definitions=<globalTypes.d.luau> src
*/
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..", "..");
const project = JSON.parse(fs.readFileSync(path.join(root, "default.project.json"), "utf8"));

function fromPath(rel, name) {
  const abs = path.join(root, rel);
  if (fs.statSync(abs).isDirectory()) {
    const entries = fs.readdirSync(abs).filter((f) => !f.startsWith(".")).sort();
    let className = "Folder";
    const filePaths = [];
    for (const [file, cls] of [["init.server.luau", "Script"], ["init.client.luau", "LocalScript"], ["init.luau", "ModuleScript"]]) {
      if (entries.includes(file)) {
        className = cls;
        filePaths.push(path.join(rel, file));
      }
    }
    const children = [];
    for (const file of entries) {
      if (filePaths.some((p) => path.basename(p) === file)) continue;
      const child = childNode(path.join(rel, file));
      if (child) children.push(child);
    }
    const node = { name, className, children };
    if (filePaths.length) node.filePaths = filePaths;
    return node;
  }
  if (rel.endsWith(".rbxm")) return { name, className: "Model", filePaths: [rel] };
  let className = "ModuleScript";
  if (rel.endsWith(".server.luau")) className = "Script";
  else if (rel.endsWith(".client.luau")) className = "LocalScript";
  return { name, className, filePaths: [rel] };
}

function childNode(rel) {
  const abs = path.join(root, rel);
  const file = path.basename(rel);
  if (fs.statSync(abs).isDirectory()) return fromPath(rel, file);
  for (const ext of [".server.luau", ".client.luau", ".luau", ".rbxm"]) {
    if (file.endsWith(ext)) return fromPath(rel, file.slice(0, -ext.length));
  }
  return null;
}

function fromNode(node, name) {
  const out = node.$path ? fromPath(node.$path, name) : { name, className: node.$className || "Folder", children: [] };
  out.children = out.children || [];
  for (const [childName, child] of Object.entries(node)) {
    if (childName.startsWith("$")) continue;
    out.children.push(fromNode(child, childName));
  }
  return out;
}

process.stdout.write(JSON.stringify(fromNode(project.tree, project.name), null, 1));
