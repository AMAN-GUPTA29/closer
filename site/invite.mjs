// The page an invite link opens: https://<site>/invite#t=<token>.
//
// The token is after '#', so browsers don't send it to the host. The page
// never joins anything: its button hands the token to the app through
// com.keeploom.app://invite, and the app asks before joining. No third-party
// requests are made from this page.

export function invitePage({ css, playUrl = "", appStoreUrl = "" }) {
  const stores = [
    ["Get it on Google Play", playUrl],
    ["Download on the App Store", appStoreUrl],
  ].filter(([, url]) => /^https:\/\/[^\s"'<>]+$/.test(url));
  const install = stores.length
    ? `<ol>
<li>Install Keeploom: ${stores.map(([label, url]) => `<a href="${url}">${label}</a>`).join(" or ")}.</li>
<li>Come back to this link and tap <strong>Open in Keeploom</strong>.</li>
</ol>`
    : "<p>You need Keeploom installed on this phone for the button to work.</p>";

  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex">
<meta name="referrer" content="no-referrer">
<meta property="og:title" content="You're invited to Keeploom">
<meta property="og:description" content="A private place to share photos and moments.">
<title>You're invited · Keeploom</title>
<style>${css}
.open{display:block;margin:24px 0;padding:14px 20px;border-radius:999px;background:var(--fg);color:var(--bg);text-align:center;text-decoration:none;font-weight:600}
[hidden]{display:none}</style></head>
<body><main>
<header><strong>Keeploom</strong></header>
<h1>You're invited</h1>
<p id="lede">Someone invited you to their private group on Keeploom. You'll see which group before you join.</p>
<a class="open" id="open" hidden>Open in Keeploom</a>
<p id="bad" hidden>This link is incomplete. Copy the whole link from the message, or use the invite code in it.</p>
<h2>If nothing happens</h2>
${install}
<p>You can also copy the whole invite message, open Keeploom, tap <strong>Join with a code</strong>, then <strong>Paste invite link</strong>. The code in the message works too.</p>
<footer>Keeploom · Keep what brings you closer.</footer>
</main>
<script>
function show() {
  var match = /^#t=([A-Za-z0-9_-]{16,128})$/.exec(location.hash);
  var open = document.getElementById("open");
  open.hidden = !match;
  document.getElementById("bad").hidden = !!match;
  if (match) open.href = "com.keeploom.app://invite?t=" + match[1];
  else open.removeAttribute("href");
}
addEventListener("hashchange", show);
show();
</script>
</body></html>
`;
}
