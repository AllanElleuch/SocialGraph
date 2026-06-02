#!/usr/bin/env node
// Builds the public legal site (Privacy Policy + Terms of Use) for Cloudflare
// Pages from the SAME markdown that the Flutter app bundles. Zero dependencies.
//
//   node legal/build.mjs        # writes HTML into legal/dist/
//
// Deploy with:  npx wrangler pages deploy legal/dist --project-name codelio-legal

import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const assets = join(root, '..', 'flutter_app', 'assets', 'legal');
const outDir = join(root, 'dist');

const DOCS = [
  { src: 'privacy-policy.md', out: 'privacy-policy.html', title: 'Privacy Policy' },
  { src: 'terms-of-use.md', out: 'terms-of-use.html', title: 'Terms of Use' },
];

/** Parse the leading `--- ... ---` YAML-ish front matter into a flat object. */
function parseFrontMatter(text) {
  const meta = {};
  if (!text.startsWith('---\n')) return { meta, body: text };
  const end = text.indexOf('\n---', 4);
  if (end === -1) return { meta, body: text };
  for (const line of text.slice(4, end).split('\n')) {
    const idx = line.indexOf(':');
    if (idx !== -1) meta[line.slice(0, idx).trim()] = line.slice(idx + 1).trim();
  }
  const body = text.slice(text.indexOf('\n', end + 1) + 1);
  return { meta, body };
}

const esc = (s) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

/** Minimal markdown -> HTML for our controlled docs. */
function renderInline(s) {
  return esc(s)
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\[(.+?)\]\((.+?)\)/g, '<a href="$2">$1</a>')
    .replace(/&lt;(https?:\/\/[^\s&]+)&gt;/g, '<a href="$1">$1</a>');
}

function renderMarkdown(md) {
  const out = [];
  const items = []; // pending <li> raw texts
  let para = [];
  let buf = []; // raw text of the current list item
  const flushItem = () => {
    if (buf.length) { items.push(buf.join(' ')); buf = []; }
  };
  const closeList = () => {
    flushItem();
    if (items.length) {
      out.push('<ul>');
      for (const it of items) out.push(`<li>${renderInline(it)}</li>`);
      out.push('</ul>');
      items.length = 0;
    }
  };
  const closePara = () => {
    if (para.length) { out.push(`<p>${renderInline(para.join(' '))}</p>`); para = []; }
  };
  for (const raw of md.replace(/\r\n/g, '\n').split('\n')) {
    const line = raw.trimEnd();
    // Indented, non-empty line: continuation of the current list item.
    if (buf.length && /^\s+\S/.test(line)) {
      buf.push(line.trim());
    } else if (line.startsWith('- ')) {
      closePara();
      flushItem();
      buf.push(line.slice(2));
    } else if (/^#{1,3} /.test(line)) {
      closePara();
      closeList();
      const level = line.match(/^#+/)[0].length;
      out.push(`<h${level}>${renderInline(line.replace(/^#+ /, ''))}</h${level}>`);
    } else if (line === '') {
      closePara();
      closeList();
    } else {
      closeList();
      para.push(line);
    }
  }
  closePara();
  closeList();
  return out.join('\n');
}

function page(title, bodyHtml, nav) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)} · Contextual Contacts</title>
<style>
  :root { color-scheme: dark; }
  body { margin:0; background:#0a0a0a; color:#e2e8f0;
    font:16px/1.6 -apple-system,BlinkMacSystemFont,"Inter",system-ui,sans-serif; }
  main { max-width:760px; margin:0 auto; padding:48px 24px 96px; }
  nav { margin-bottom:32px; font-size:14px; }
  nav a { color:#818cf8; text-decoration:none; margin-right:16px; }
  nav a:hover { text-decoration:underline; }
  h1 { font-size:30px; }
  h2 { font-size:21px; margin-top:36px; border-top:1px solid #222; padding-top:24px; }
  h3 { font-size:17px; margin-top:24px; }
  a { color:#818cf8; }
  li { margin:6px 0; }
  strong { color:#fff; }
  footer { margin-top:64px; color:#9ca3af; font-size:13px; border-top:1px solid #222; padding-top:16px; }
</style>
</head>
<body>
<main>
<nav>${nav}</nav>
${bodyHtml}
<footer>© 2026 Codelio · <a href="mailto:contact@codelio.fr">contact@codelio.fr</a></footer>
</main>
</body>
</html>
`;
}

rmSync(outDir, { recursive: true, force: true });
mkdirSync(outDir, { recursive: true });

const nav = DOCS.map((d) => `<a href="${d.out}">${d.title}</a>`).join('');

let indexLinks = '';
for (const doc of DOCS) {
  const text = readFileSync(join(assets, doc.src), 'utf8');
  const { meta, body } = parseFrontMatter(text);
  const html = page(doc.title, renderMarkdown(body), nav);
  writeFileSync(join(outDir, doc.out), html);
  const ver = meta.version ? ` (v${meta.version})` : '';
  indexLinks += `<li><a href="${doc.out}">${doc.title}</a>${ver}</li>`;
  console.log(`built ${doc.out}${ver}`);
}

writeFileSync(
  join(outDir, 'index.html'),
  page('Legal', `<h1>Contextual Contacts — Legal</h1><ul>${indexLinks}</ul>`, nav),
);
console.log(`built index.html → ${outDir}`);
