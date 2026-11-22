// Builds the public Keeploom web pages (privacy, terms, support, account
// deletion) into site/dist for Vercel. The text comes from the same Markdown
// files the app shows (assets/legal), so the store links and the app always
// match. No dependencies: only the small Markdown subset those files use.
//
//   node site/build.mjs            (SUPPORT_EMAIL=... to fill in the contact)

import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, "..");
const out = join(here, "dist");
const email = (process.env.SUPPORT_EMAIL ?? "").trim();

// Must say the same as legalContactText() in lib/features/legal/legal_content.dart.
const contact = email
  ? `Email us at ${email}. We reply within a few working days.`
  : "Contact details will be added here before Keeploom is released.";

const pages = [
  { slug: "privacy", file: join(root, "assets/legal/privacy.md") },
  { slug: "terms", file: join(root, "assets/legal/terms.md") },
  { slug: "support", file: join(root, "assets/legal/support.md") },
  { slug: "delete-account", file: join(here, "content/delete-account.md") },
];

const escape = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function inline(text) {
  let html = escape(text).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  if (email) {
    html = html.replaceAll(
      escape(email),
      `<a href="mailto:${escape(email)}">${escape(email)}</a>`,
    );
  }
  return html;
}

function render(markdown) {
  let title = "Keeploom";
  const html = [];
  let paragraph = [];
  let list = false;
  const flush = () => {
    if (paragraph.length) html.push(`<p>${inline(paragraph.join(" "))}</p>`);
    paragraph = [];
  };
  const closeList = () => {
    if (list) html.push("</ul>");
    list = false;
  };
  for (const raw of markdown.replaceAll("{{contact}}", contact).split("\n")) {
    const line = raw.trim();
    if (!line) {
      flush();
      closeList();
    } else if (line.startsWith("## ")) {
      flush();
      closeList();
      html.push(`<h2>${inline(line.slice(3))}</h2>`);
    } else if (line.startsWith("# ")) {
      flush();
      closeList();
      title = line.slice(2);
      html.push(`<h1>${inline(title)}</h1>`);
    } else if (line.startsWith("- ")) {
      flush();
      if (!list) html.push("<ul>");
      list = true;
      html.push(`<li>${inline(line.slice(2))}</li>`);
    } else {
      closeList();
      paragraph.push(line);
    }
  }
  flush();
  closeList();
  return { title, body: html.join("\n") };
}

const nav = pages
  .map((p) => `<a href="/${p.slug}">${p.slug === "delete-account" ? "Delete account" : p.slug[0].toUpperCase() + p.slug.slice(1)}</a>`)
  .join("");

const css = `
:root{--bg:#FFF7F1;--fg:#2E2A2A;--muted:#6E616F;--accent:#C92F52;--line:#EADCD6}
@media (prefers-color-scheme:dark){:root{--bg:#0E0810;--fg:#F4ECE8;--muted:#B3A6AE;--accent:#FF7B8C;--line:#2E282B}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 "Plus Jakarta Sans",system-ui,sans-serif}
main{max-width:720px;margin:0 auto;padding:24px 16px 64px}
header{display:flex;flex-wrap:wrap;gap:8px 18px;align-items:baseline;border-bottom:1px solid var(--line);padding-bottom:14px;margin-bottom:8px}
header strong{font-family:Fraunces,Georgia,serif;font-size:22px;margin-right:auto}
header a{color:var(--muted);text-decoration:none;font-size:14px}
header a:hover{color:var(--accent)}
h1{font-family:Fraunces,Georgia,serif;font-weight:600;font-size:32px;line-height:1.2;margin:28px 0 8px}
h2{font-size:18px;margin:28px 0 6px}
ul{padding-left:20px}li{margin:4px 0}
a{color:var(--accent)}
footer{margin-top:40px;color:var(--muted);font-size:14px}`;

function page(title, body) {
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escape(title)} · Keeploom</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Fraunces:wght@600&family=Plus+Jakarta+Sans:wght@400;600&display=swap" rel="stylesheet">
<style>${css}</style></head>
<body><main>
<header><strong>Keeploom</strong>${nav}</header>
${body}
<footer>Keeploom · Keep what brings you closer.</footer>
</main></body></html>
`;
}

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
for (const p of pages) {
  const { title, body } = render(readFileSync(p.file, "utf8"));
  writeFileSync(join(out, `${p.slug}.html`), page(title, body));
}
writeFileSync(
  join(out, "index.html"),
  page(
    "Keeploom",
    `<h1>Keeploom</h1>
<p>A private place to share photos and moments with your partner, friends and family.</p>
<ul>${pages.map((p) => `<li><a href="/${p.slug}">${render(readFileSync(p.file, "utf8")).title}</a></li>`).join("")}</ul>`,
  ),
);
console.log(`Built ${pages.length + 1} pages into site/dist${email ? "" : " (no SUPPORT_EMAIL set)"}`);
