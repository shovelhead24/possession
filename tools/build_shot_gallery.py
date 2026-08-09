#!/usr/bin/env python3
"""Build logs/shots/index.html -- a browsable gallery of every screenshot session and its notes.

Regenerate any time; it reads the folders and JOURNAL.md rather than storing anything of its own.

Images are referenced RELATIVELY, not embedded. A single 1366x749 PNG is ~700KB and base64 inflates
it by a third, so embedding ten of them makes a 9MB page that is slow to open and impossible to
diff. The page lives next to the images, so relative paths just work.

usage:  python tools/build_shot_gallery.py
"""
import html
import os
import re
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SHOTS = os.path.normpath(os.path.join(HERE, "..", "logs", "shots"))
JOURNAL = os.path.join(SHOTS, "JOURNAL.md")
OUT = os.path.join(SHOTS, "index.html")


def md_inline(t):
    """Just enough markdown for the journal's prose: bold, code, em-dash. Not a parser."""
    t = html.escape(t)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
    t = re.sub(r"`(.+?)`", r"<code>\1</code>", t)
    return t


def parse_journal():
    """Split JOURNAL.md into sections on '### ' and '## ', keeping the Looking for / Saw / Fell out
    structure intact as prose."""
    if not os.path.exists(JOURNAL):
        return []
    out, cur = [], None
    for line in open(JOURNAL, encoding="utf-8"):
        m = re.match(r"^(#{2,3})\s+(.*)", line.rstrip())
        if m:
            if cur:
                out.append(cur)
            cur = {"title": m.group(2), "level": len(m.group(1)), "body": []}
        elif cur is not None:
            cur["body"].append(line.rstrip())
    if cur:
        out.append(cur)
    # drop the how-to preamble; keep anything that reads like a session
    return [s for s in out if s["title"].lower() not in ("screenshot journal",)]


def folders():
    """Every shot folder, newest first, with its images."""
    out = []
    if not os.path.isdir(SHOTS):
        return out
    for name in sorted(os.listdir(SHOTS), reverse=True):
        d = os.path.join(SHOTS, name)
        if not os.path.isdir(d):
            continue
        imgs = sorted(f for f in os.listdir(d) if f.lower().endswith((".png", ".jpg")))
        if imgs:
            out.append((name, imgs))
    return out


def match_section(folder, sections):
    """Best-effort tie a folder to a journal entry by patch name in the title."""
    key = re.sub(r"^\d{8}_\d{4}_?", "", folder).lower()
    for s in sections:
        t = s["title"].lower()
        if key and key in t:
            return s
        for img in ():
            pass
    return None


def render_body(lines):
    """Journal bodies are short prose with the odd bullet. Render paragraphs and lists, nothing more."""
    parts, buf, in_ul = [], [], False
    def flush():
        if buf:
            parts.append("<p>%s</p>" % md_inline(" ".join(buf)))
            buf.clear()
    for ln in lines:
        if not ln.strip():
            flush()
            continue
        if ln.lstrip().startswith("- "):
            flush()
            if not in_ul:
                parts.append("<ul>")
                in_ul = True
            parts.append("<li>%s</li>" % md_inline(ln.lstrip()[2:]))
            continue
        if in_ul:
            parts.append("</ul>")
            in_ul = False
        buf.append(ln.strip())
    flush()
    if in_ul:
        parts.append("</ul>")
    return "\n".join(parts)


CSS = """
:root{--bg:#faf9f7;--fg:#1c1a17;--dim:#6b655d;--line:#e0dcd5;--card:#fff;--accent:#8a6d3b}
@media (prefers-color-scheme:dark){:root{--bg:#14130f;--fg:#eceae5;--dim:#95908a;--line:#2c2a25;--card:#1c1a17;--accent:#c9a86a}}
:root[data-theme=dark]{--bg:#14130f;--fg:#eceae5;--dim:#95908a;--line:#2c2a25;--card:#1c1a17;--accent:#c9a86a}
:root[data-theme=light]{--bg:#faf9f7;--fg:#1c1a17;--dim:#6b655d;--line:#e0dcd5;--card:#fff;--accent:#8a6d3b}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
 font:16px/1.6 ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif}
.wrap{max-width:1100px;margin:0 auto;padding:2.5rem 1.25rem 5rem}
h1{font-size:1.7rem;margin:0 0 .3rem;letter-spacing:-.01em}
.sub{color:var(--dim);margin:0 0 2.5rem;font-size:.95rem}
details{background:var(--card);border:1px solid var(--line);border-radius:10px;
 margin:0 0 1rem;overflow:hidden}
summary{cursor:pointer;padding:1rem 1.15rem;font-weight:600;list-style:none;
 display:flex;gap:.75rem;align-items:baseline}
summary::-webkit-details-marker{display:none}
summary::before{content:"\\25B8";color:var(--accent);transition:transform .15s;display:inline-block}
details[open] summary::before{transform:rotate(90deg)}
summary:hover{background:color-mix(in srgb,var(--accent) 8%,transparent)}
.meta{margin-left:auto;color:var(--dim);font-weight:400;font-size:.85rem;white-space:nowrap}
.body{padding:0 1.15rem 1.15rem;border-top:1px solid var(--line)}
.body p{margin:.9rem 0}
.body ul{margin:.9rem 0;padding-left:1.2rem}
.body li{margin:.35rem 0}
code{background:color-mix(in srgb,var(--accent) 14%,transparent);padding:.1em .35em;
 border-radius:4px;font-size:.88em}
.shots{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:.9rem;margin:1.1rem 0 0}
figure{margin:0}
figure img{width:100%;height:auto;display:block;border-radius:8px;border:1px solid var(--line);
 background:#000}
figcaption{color:var(--dim);font-size:.82rem;margin-top:.35rem}
.none{color:var(--dim);font-style:italic}
"""

JS = """
// deep-link to a session so a finding can be pointed at
document.querySelectorAll('details').forEach(function(d){
  d.addEventListener('toggle', function(){
    if (d.open && d.id) history.replaceState(null,'','#'+d.id);
  });
});
if (location.hash) {
  var t = document.getElementById(location.hash.slice(1));
  if (t) { t.open = true; t.scrollIntoView(); }
}
"""


def main():
    sections = parse_journal()
    fold = folders()
    used = set()
    cards = []

    for name, imgs in fold:
        sec = match_section(name, sections)
        if sec:
            used.add(id(sec))
        title = sec["title"] if sec else name
        body = render_body(sec["body"]) if sec else \
            '<p class="none">No journal entry yet. Add one to JOURNAL.md and rebuild.</p>'
        figs = "".join(
            '<figure><a href="%s/%s"><img loading="lazy" src="%s/%s" alt="%s"></a>'
            '<figcaption>%s</figcaption></figure>'
            % (name, i, name, i, html.escape(i), html.escape(os.path.splitext(i)[0]))
            for i in imgs)
        cards.append(
            '<details id="%s"><summary>%s<span class="meta">%s &middot; %d shot%s</span></summary>'
            '<div class="body">%s<div class="shots">%s</div></div></details>'
            % (html.escape(name), html.escape(title), html.escape(name),
               len(imgs), "" if len(imgs) == 1 else "s", body, figs))

    # journal entries with no folder of their own (the retrospective ones, and telemetry sessions)
    for i, sec in enumerate(sections):
        if id(sec) in used:
            continue
        cards.append(
            '<details id="note-%d"><summary>%s<span class="meta">notes only</span></summary>'
            '<div class="body">%s</div></details>'
            % (i, html.escape(sec["title"]), render_body(sec["body"])))

    doc = (
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        "<title>Possession - screenshot journal</title><style>%s</style></head><body>"
        "<div class=\"wrap\"><h1>Screenshot journal</h1>"
        "<p class=\"sub\">Every capture session, what it was taken to check, and what came out of "
        "looking at it. Click a title to open. Generated %s from JOURNAL.md.</p>"
        "%s</div><script>%s</script></body></html>"
        % (CSS, time.strftime("%Y-%m-%d %H:%M"), "\n".join(cards), JS))

    with open(OUT, "w", encoding="utf-8") as f:
        f.write(doc)
    print("wrote %s -- %d sessions, %d image folders"
          % (os.path.relpath(OUT), len(cards), len(fold)))


if __name__ == "__main__":
    main()
