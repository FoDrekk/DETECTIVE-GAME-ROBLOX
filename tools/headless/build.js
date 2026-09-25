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
    *.rbxm           -> instances converted from the binary model (needs rbxm-parser)
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
  if (fsPath.endsWith(".rbxm")) {
    return emitRbxm(abs, name, parentVar);
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
  for (const ext of [".server.luau", ".client.luau", ".luau", ".rbxm"]) {
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

// ---- rbxm conversion ------------------------------------------------------
function emitRbxm(abs, name, parentVar) {
  let RobloxFile;
  try {
    ({ RobloxFile } = require(process.env.RBXM_PARSER || "rbxm-parser"));
  } catch (e) {
    console.error("rbxm-parser is required to convert .rbxm files (npm install rbxm-parser; or set RBXM_PARSER)");
    process.exit(2);
  }
  const file = RobloxFile.ReadFromBuffer(fs.readFileSync(abs));
  const shared = file.SharedStrings;
  const rootVar = emitRbxInstance(file.Roots[0], name, shared);
  lines.push(`${rootVar}.Parent = ${parentVar}`);
  return rootVar;
}

const PROP_MAP = { size: "Size", Color3uint8: "Color", shape: "Shape" };
const SKIP = new Set(["Name", "Tags", "AttributesSerialize", "formFactorRaw", "SourceAssetId", "Capabilities", "DefinesCapabilities", "UniqueId", "HistoryId", "ScriptGuid", "PivotOffset", "RotVelocity", "Velocity", "CustomPhysicalProperties", "CollisionGroupId", "AttributesReplicate", "ModelMeshData", "ModelMeshCFrame", "ModelMeshSize", "NeedsPivotMigration", "WorldPivotData", "ModelStreamingMode", "LevelOfDetail", "ScaleFactor", "TeamColor", "CFrame"]);

function sharedValue(shared, v) {
  if (v && v.Index !== undefined) {
    const s = shared[v.Index];
    if (!s) return Buffer.alloc(0);
    const raw = s.Value ?? s.value ?? s.Data ?? "";
    return Buffer.isBuffer(raw) ? raw : Buffer.from(raw, typeof raw === "string" ? "latin1" : undefined);
  }
  if (typeof v === "string") return Buffer.from(v, "latin1");
  return Buffer.alloc(0);
}

function decodeAttributes(buf) {
  const out = {};
  if (buf.length < 4) return out;
  let o = 0;
  const count = buf.readUInt32LE(o); o += 4;
  const readStr = () => { const n = buf.readUInt32LE(o); o += 4; const s = buf.slice(o, o + n).toString("utf8"); o += n; return s; };
  for (let i = 0; i < count; i++) {
    const key = readStr();
    const t = buf[o++];
    if (t === 0x02) out[key] = JSON.stringify(readStr());
    else if (t === 0x03) out[key] = buf[o++] ? "true" : "false";
    else if (t === 0x06) { out[key] = String(buf.readDoubleLE(o)); o += 8; }
    else if (t === 0x05) { out[key] = String(buf.readFloatLE(o)); o += 4; }
    else throw new Error("unsupported attribute type " + t + " for " + key);
  }
  return out;
}

function luaRbxValue(rv) {
  const v = rv.value;
  if (v === null || v === undefined) return null;
  if (typeof v === "boolean") return String(v);
  if (typeof v === "number") return Number.isFinite(v) ? String(v) : null;
  if (typeof v === "string") return JSON.stringify(v);
  if (typeof v === "object") {
    if (v._name !== undefined && v._value !== undefined) return { enum: v._name };
    if ("R" in v && "G" in v && "B" in v) return `Color3.fromRGB(${Math.round(v.R * 255)},${Math.round(v.G * 255)},${Math.round(v.B * 255)})`;
    if ("X" in v && "Y" in v && "Z" in v) return `Vector3.new(${v.X},${v.Y},${v.Z})`;
    if (v.Position && v.Orientation) {
      const p = v.Position, r = v.Orientation;
      return `CFrame.new(${p.X},${p.Y},${p.Z},${r.join(",")})`;
    }
  }
  return null;
}

const ENUM_TYPES = { Material: "Material", Shape: "PartType", Face: "NormalId", TopSurface: "SurfaceType", BottomSurface: "SurfaceType" };

function emitRbxInstance(inst, nameOverride, shared) {
  const v = newVar();
  const name = nameOverride || inst.Name;
  lines.push(`${v} = Shim.newInstance(${JSON.stringify(inst.ClassName)}, ${JSON.stringify(name)})`);
  const cfr = inst.Props.get("CFrame");
  if (cfr) {
    const val = luaRbxValue(cfr);
    if (val) lines.push(`${v}.CFrame = ${val}`);
  }
  for (const [k, rv] of inst.Props) {
    if (SKIP.has(k) || /Param[AB]$|SurfaceInput$|Surface$/.test(k)) continue;
    const key = PROP_MAP[k] || k;
    let val = luaRbxValue(rv);
    if (val === null) continue;
    if (typeof val === "object" && val.enum) {
      const enumType = ENUM_TYPES[key];
      if (!enumType) continue;
      val = `Enum.${enumType}.${val.enum}`;
    }
    lines.push(`Shim.internal(${v}).props[${JSON.stringify(key)}] = ${val}`);
  }
  const tags = sharedValue(shared, inst.Props.get("Tags") && inst.Props.get("Tags").value).toString("utf8").split("\0").filter(Boolean);
  for (const tag of tags) lines.push(`${v}:AddTag(${JSON.stringify(tag)})`);
  const attrs = decodeAttributes(sharedValue(shared, inst.Props.get("AttributesSerialize") && inst.Props.get("AttributesSerialize").value));
  for (const [k, val] of Object.entries(attrs)) lines.push(`${v}:SetAttribute(${JSON.stringify(k)}, ${val})`);
  for (const child of inst.Children) {
    const cv = emitRbxInstance(child, null, shared);
    lines.push(`${cv}.Parent = ${v}`);
  }
  return v;
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
