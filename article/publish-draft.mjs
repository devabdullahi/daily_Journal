// Saves the article to the live site as a DRAFT (never published).
// Usage: ADMIN_PASSWORD='…' node publish-draft.mjs [https://abdullahi-agr.pages.dev]
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join, basename } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const site = (process.argv[2] || "https://abdullahi-agr.pages.dev").replace(/\/$/, "");
const password = process.env.ADMIN_PASSWORD;
if (!password) throw new Error("Set ADMIN_PASSWORD in the environment.");

const headers = { Origin: site };
const login = await fetch(`${site}/api/login`, {
  method: "POST",
  headers: { ...headers, "Content-Type": "application/json" },
  body: JSON.stringify({ password }),
});
if (!login.ok) throw new Error(`Login failed: ${login.status} ${await login.text()}`);
headers.Cookie = login.headers.get("set-cookie").split(";")[0];

let html = await readFile(join(here, "post.html"), "utf8");
const srcs = [...new Set([...html.matchAll(/src="(images\/[^"]+)"/g)].map((m) => m[1]))];
for (const src of srcs) {
  const type = src.endsWith(".png") ? "image/png" : "image/jpeg";
  const form = new FormData();
  form.append("file", new Blob([await readFile(join(here, src))], { type }), basename(src));
  const res = await fetch(`${site}/api/images`, { method: "POST", headers, body: form });
  if (!res.ok) throw new Error(`Upload ${src} failed: ${res.status} ${await res.text()}`);
  const { url } = await res.json();
  html = html.replaceAll(`src="${src}"`, `src="${url}"`);
  console.log(`uploaded ${src} -> ${url}`);
}

const meta = JSON.parse(await readFile(join(here, "post.json"), "utf8"));
const res = await fetch(`${site}/api/posts/${meta.slug}`, {
  method: "PUT",
  headers: { ...headers, "Content-Type": "application/json" },
  body: JSON.stringify({ ...meta, html, status: "draft" }),
});
if (!res.ok) throw new Error(`Save failed: ${res.status} ${await res.text()}`);
console.log(`Draft saved. Preview: ${site}/posts/${meta.slug}  Edit/publish: ${site}/admin/`);
