#!/usr/bin/env node
/*
  Builds a single Luau file that recreates this Rojo project's DataModel on
  top of RobloxShim.luau, then runs an entry script (tests, playthrough, or
  client smoke test). Usage:

    node tools/headless/build.js <entry.luau> <out.luau>

  Mapping follows Rojo's rules for default.project.json:
    init.server.luau -> Script named after the folder (children = siblings)
    init.client.luau -> LocalScript named after the folder
    init.luau        -> ModuleScript named after the folder
    X.server.luau    -> Script X, X.client.luau -> LocalScript X, X.luau -> ModuleScript X
    source trees and scripts from default.project.json -> shim instances
*/
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..", "..");
const [entryPath, outPath] = process.argv.slice(2);
if (!entryPath || !outPath) {
  console.error("usage: node build.js <entry.luau> <out.luau>");
  process.exit(2);
}

const project = JSON.parse(fs.readFileSync(path.join(root, "default.project.json"), "utf8"));
const lines = [];
let counter = 0;
const newVar = () => `I[${++counter}]`;

function longString(text) {
  let level = 1;
  while (text.includes("]" + "=".repeat(level) + "]")) level++;
  const eq = "=".repeat(level);
  return `[${eq}[\n${text}]${eq}]`;
}

// Emit the instance creation for a file-system path, returns var name.
function emitPath(fsPath, name, parentVar, props) {
  const abs = path.join(root, fsPath);
  const stat = fs.statSync(abs);
  if (stat.isDirectory()) {
    const entries = fs.readdirSync(abs).filter((f) => !f.startsWith("."));
    let initFile = null;
    let cls = "Folder";
    for (const [file, c] of [["init.server.luau", "Script"], ["init.client.luau", "LocalScript"], ["init.luau", "ModuleScript"]]) {
      if (entries.includes(file)) {
        initFile = file;
        cls = c;
      }
    }
    const v = newVar();
    lines.push(`${v} = Shim.newInstance(${JSON.stringify(cls)}, ${JSON.stringify(name)})`);
    if (initFile) {
      const src = fs.readFileSync(path.join(abs, initFile), "utf8");
      lines.push(`Shim.registerSource(${v}, ${longString(src)}, ${JSON.stringify(path.join(fsPath, initFile))})`);
    }
    applyProps(v, props);
    for (const file of entries.sort()) {
      if (file === initFile) continue;
      const childPath = path.join(fsPath, file);
      const childName = childBaseName(file, path.join(abs, file));
      if (childName === null) continue;
      emitPath(childPath, childName, v, null);
    }
    lines.push(`${v}.Parent = ${parentVar}`);
    return v;
  }
  let cls = "ModuleScript";
  if (fsPath.endsWith(".server.luau")) cls = "Script";
  else if (fsPath.endsWith(".client.luau")) cls = "LocalScript";
  else if (!fsPath.endsWith(".luau")) return null;
  const v = newVar();
  lines.push(`${v} = Shim.newInstance(${JSON.stringify(cls)}, ${JSON.stringify(name)})`);
  lines.push(`Shim.registerSource(${v}, ${longString(fs.readFileSync(abs, "utf8"))}, ${JSON.stringify(fsPath)})`);
  applyProps(v, props);
  lines.push(`${v}.Parent = ${parentVar}`);
  return v;
}

function childBaseName(file, abs) {
  if (fs.statSync(abs).isDirectory()) return file;
  for (const ext of [".server.luau", ".client.luau", ".luau"]) {
    if (file.endsWith(ext)) return file.slice(0, -ext.length);
  }
  return null;
}

function applyProps(v, props) {
  if (!props) return;
  for (const [k, val] of Object.entries(props)) {
    lines.push(`${v}.${k} = ${luaValue(val)}`);
  }
}

function luaValue(val) {
  if (typeof val === "boolean" || typeof val === "number") return String(val);
  if (typeof val === "string") return JSON.stringify(val);
  if (val && val.Enum) return `Enum.${val.Enum[0]}.${val.Enum[1]}`;
  throw new Error("unsupported $properties value " + JSON.stringify(val));
}

// Rojo project nodes.
const SERVICE_CLASSES = new Set(["Workspace", "Lighting", "ReplicatedStorage", "ServerStorage", "ServerScriptService", "StarterPlayer", "SoundService", "Players", "StarterGui", "MaterialService"]);
function emitNode(node, name, parentVar, isRoot) {
  let v;
  if (isRoot) {
    v = "Shim.game";
  } else if (node.$path) {
    v = emitPath(node.$path, name, parentVar, node.$properties);
  } else {
    const cls = node.$className || "Folder";
    v = newVar();
    if (SERVICE_CLASSES.has(cls)) {
      lines.push(`${v} = Shim.service(${JSON.stringify(cls)})`);
    } else if (cls === "StarterPlayerScripts") {
      lines.push(`${v} = Shim.newInstance("StarterPlayerScripts", ${JSON.stringify(name)})`);
      lines.push(`${v}.Parent = ${parentVar}`);
    } else {
      lines.push(`${v} = Shim.newInstance(${JSON.stringify(cls)}, ${JSON.stringify(name)})`);
      lines.push(`${v}.Parent = ${parentVar}`);
    }
    for (const [k, val] of Object.entries(node.$properties || {})) {
      if (k === "FilteringEnabled") continue;
      lines.push(`${v}.${k} = ${luaTypedProperty(val)}`);
    }
  }
  for (const [childName, child] of Object.entries(node)) {
    if (childName.startsWith("$")) continue;
    emitNode(child, childName, v, false);
  }
  return v;
}

// Rojo explicit property syntax ({ "Enum": "Future" } etc.) for services.
function luaTypedProperty(val) {
  if (typeof val !== "object" || val === null) return luaValue(val);
  if ("Enum" in val) return val.__enumType ? `Enum.${val.__enumType}.${val.Enum}` : JSON.stringify(val.Enum);
  if ("Color3" in val) return `Color3.new(${val.Color3.join(",")})`;
  if ("Color3uint8" in val) return `Color3.fromRGB(${val.Color3uint8.join(",")})`;
  if ("Vector3" in val) return `Vector3.new(${val.Vector3.join(",")})`;
  if ("Float32" in val || "Float64" in val) return String(val.Float32 ?? val.Float64);
  if ("Bool" in val) return String(val.Bool);
  if ("String" in val) return JSON.stringify(val.String);
  throw new Error("unsupported typed property " + JSON.stringify(val));
}

// ---- assemble -------------------------------------------------------------
const shimSource = fs.readFileSync(path.join(__dirname, "RobloxShim.luau"), "utf8");
const out = [];
out.push("--!nocheck");
out.push("-- GENERATED by tools/headless/build.js. Do not edit.");
out.push(`local Shim = (loadstring(${longString(shimSource)}, "=RobloxShim") :: any)()`);
out.push("setfenv(1, setmetatable({ Shim = Shim }, { __index = Shim.env }))");
out.push("local function buildTree()");
out.push("\tlocal I = {}");
emitNode(project.tree, project.name, null, true);
out.push(...lines.map((l) => "\t" + l));
out.push("end");
out.push("buildTree()");
out.push(fs.readFileSync(path.resolve(entryPath), "utf8"));
fs.writeFileSync(outPath, out.join("\n"));
console.log(`wrote ${outPath} (${counter} instances)`);
