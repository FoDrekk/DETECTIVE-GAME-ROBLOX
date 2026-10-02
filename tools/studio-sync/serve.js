#!/usr/bin/env node
"use strict";
/*
  Serves the repo's scripts to an open Roblox Studio over localhost, so they can be
  pushed into a place without Rojo (see README.md in this folder for why).

    node tools/studio-sync/serve.js [--port 34873] [--project default.project.json]

  GET /manifest        JSON: [{ path, class, length, hash }] for every mapped script
  GET /source?path=P   the CR-stripped source of one script (P is its Studio path)

  Bound to 127.0.0.1 only. The manifest is rebuilt from disk on every request, so a
  file edited between two syncs is picked up without restarting.
*/
const http = require("http");
const path = require("path");
const { buildManifest } = require("./manifest");

const args = process.argv.slice(2);
function option(name, fallback) {
  const at = args.indexOf(`--${name}`);
  return at >= 0 && args[at + 1] ? args[at + 1] : fallback;
}

const root = path.resolve(__dirname, "..", "..");
const port = Number(option("port", "34873"));
const project = option("project", "default.project.json");

const server = http.createServer((request, response) => {
  const url = new URL(request.url, `http://127.0.0.1:${port}`);
  try {
    if (url.pathname === "/manifest") {
      const list = buildManifest(root, project).map(({ path: p, class: c, length, hash }) => ({ path: p, class: c, length, hash }));
      response.writeHead(200, { "Content-Type": "application/json" });
      response.end(JSON.stringify(list));
      return;
    }
    if (url.pathname === "/source") {
      const wanted = url.searchParams.get("path");
      const entry = buildManifest(root, project).find((e) => e.path === wanted);
      if (!entry) {
        response.writeHead(404, { "Content-Type": "text/plain" });
        response.end(`no such script: ${wanted}`);
        return;
      }
      response.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
      response.end(entry.source);
      return;
    }
    response.writeHead(404, { "Content-Type": "text/plain" });
    response.end("not found");
  } catch (error) {
    response.writeHead(500, { "Content-Type": "text/plain" });
    response.end(String(error && error.stack ? error.stack : error));
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`studio-sync serving ${root} (${project}) on http://127.0.0.1:${port}`);
});
