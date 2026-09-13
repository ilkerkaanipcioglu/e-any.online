#!/usr/bin/env python3
"""Content Feed Generator - multi-type content hub for all sites.
Supports: blog, video (YouTube), tweet, linkedin, link, news
"""
import os, sys, json, re
from datetime import datetime
from pathlib import Path

POSTS_DIR = Path("/data/stacks/feed/posts")
HTML_DIR = Path("/data/stacks/feed/html")

SITE_NAMES = {
    "agentandbot": ("AgentAndBot", "agentandbot.com", "/blog/"),
    "e-any": ("E-Any", "e-any.online", "/feed/"),
    "harezmi": ("Harezmi", "harezmi.com", "/blog/"),
    "eny": ("ENY", "eny.com.tr", "/blog/"),
    "ipcioglu": ("İlker İpçioğlu", "ilkerkaan.ipcioglu.com", "/blog/"),
}

BLOG_PREFIX = "/blog/"
FEED_PREFIX = "/feed/"

TYPE_ICONS = {
    "blog": "📝", "video": "📺", "tweet": "🐦",
    "linkedin": "🔗", "news": "📰", "link": "🔗",
}

def parse_post(filepath):
    content = open(filepath).read()
    parts = content.split("---\n", 2)
    if len(parts) < 3:
        return None
    
    fm = {}
    for line in parts[1].strip().split("\n"):
        if ":" in line:
            key, val = line.split(":", 1)
            key = key.strip()
            val = val.strip()
            if val.startswith("[") and val.endswith("]"):
                val = [v.strip().strip("'\"") for v in val[1:-1].split(",")]
            fm[key] = val
    
    sites = fm.get("sites", [])
    if isinstance(sites, str):
        sites = [sites]
    
    slug = filepath.stem
    ptype = fm.get("type", "blog")
    
    return {
        "slug": slug,
        "type": ptype,
        "title": fm.get("title", "Untitled"),
        "date": fm.get("date", datetime.now().strftime("%Y-%m-%d")),
        "author": fm.get("author", "AgentAndBot"),
        "sites": sites,
        "canonical_site": sites[0] if sites else None,
        "canonical_url": f"https://{SITE_NAMES.get(sites[0], [sites[0], sites[0], '/blog/'])[1]}{SITE_NAMES.get(sites[0], [sites[0], sites[0], '/blog/'])[2]}{slug}" if sites else "",
        "tags": fm.get("tags", []),
        "excerpt": fm.get("excerpt", ""),
        "source_url": fm.get("source_url", ""),
        "source_name": fm.get("source_name", ""),
        "body": parts[2].strip(),
    }

def embed_html(post):
    """Generate embed for external content types."""
    ptype = post["type"]
    src = post["source_url"]
    
    if ptype == "video" and src:
        # YouTube URL -> embed
        vid = re.search(r"(?:v=|youtu\.be/)([\w-]+)", src)
        if vid:
            return f'<div class="embed-container"><iframe src="https://www.youtube.com/embed/{vid.group(1)}" frameborder="0" allowfullscreen></iframe></div>'
        return f'<p><a href="{src}">📺 Videoyu izle</a></p>'
    
    if ptype == "tweet" and src:
        return f'<div class="embed-container"><blockquote class="twitter-tweet"><a href="{src}"></a></blockquote><script async src="https://platform.twitter.com/widgets.js"></script></div>'
    
    if ptype in ("linkedin", "link", "news") and src:
        return f'<p>🔗 <a href="{src}">{post.get("source_name", "Kaynağa git")}</a></p>'
    
    return ""

def body_to_html(text):
    """Simple markdown to HTML."""
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    lines, in_list = [], False
    for line in text.split("\n"):
        if line.startswith("## "):
            if in_list: lines.append("</ul>"); in_list = False
            lines.append(f"<h2>{line[3:]}</h2>")
        elif line.startswith("### "):
            if in_list: lines.append("</ul>"); in_list = False
            lines.append(f"<h3>{line[3:]}</h3>")
        elif line.startswith("- "):
            if not in_list: lines.append("<ul>"); in_list = True
            lines.append(f"<li>{line[2:]}</li>")
        elif line.startswith("1. "):
            if not in_list: lines.append("<ol>"); in_list = True
            lines.append(f"<li>{line[3:]}</li>")
        elif line == "":
            if in_list: lines.append("</ul>"); in_list = False
        else:
            if in_list: lines.append("</ul>"); in_list = False
            lines.append(f"<p>{line}</p>")
    if in_list: lines.append("</ul>")
    return "\n".join(lines)

def generate_html(post, site_key):
    sn, sd, prefix = SITE_NAMES.get(site_key, (site_key, f"{site_key}.com", "/blog/"))
    is_canonical = (site_key == post["canonical_site"])
    icon = TYPE_ICONS.get(post["type"], "📄")
    tags = " ".join(f'<span class="tag">{t}</span>' for t in post["tags"])
    
    source_banner = ""
    if not is_canonical:
        cname = SITE_NAMES.get(post["canonical_site"], [post["canonical_site"]])[0]
        source_banner = f'''
        <div class="source-banner">
            📝 Bu içerik ilk olarak <a href="{post["canonical_url"]}">{cname}</a>'de yayınlanmıştır
        </div>'''
    
    canonical_tag = f'<link rel="canonical" href="{post["canonical_url"]}">' if not is_canonical else ""
    embed = embed_html(post)
    body = body_to_html(post["body"])
    
    return f'''<!DOCTYPE html>
<html lang="tr" data-theme="dark">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{post["title"]} — {sn}</title>
{canonical_tag}
<style>
:root {{--bg:#0d1117;--card:#161b22;--border:#30363d;--text:#c9d1d9;--muted:#8b949e;--accent:#58a6ff;--green:#3fb950;--yellow:#d29922;}}
* {{margin:0;padding:0;box-sizing:border-box;}}
body {{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:var(--bg);color:var(--text);line-height:1.7;}}
header {{background:var(--card);border-bottom:1px solid var(--border);padding:1.2rem 2rem;display:flex;align-items:center;gap:1rem;position:sticky;top:0;z-index:10;}}
header a {{color:var(--text);text-decoration:none;}} header a:hover {{color:var(--accent);}}
header .logo {{color:var(--green);font-size:1.3rem;}} header .sep {{color:var(--muted);}}
.container {{max-width:800px;margin:0 auto;padding:2rem 1.5rem;}}
.back-link {{display:inline-block;margin-bottom:1.5rem;color:var(--muted);text-decoration:none;font-size:0.9rem;}}
.back-link:hover {{color:var(--accent);}}
.source-banner {{background:rgba(210,153,34,0.12);border:1px solid var(--yellow);border-radius:6px;padding:0.8rem 1rem;margin-bottom:1.5rem;font-size:0.9rem;color:var(--yellow);}}
.source-banner a {{color:var(--accent);}}
h1 {{font-size:2rem;margin-bottom:0.5rem;}} .meta {{color:var(--muted);margin-bottom:1rem;font-size:0.9rem;}}
.tags {{display:flex;gap:0.4rem;flex-wrap:wrap;margin-bottom:1.5rem;}}
.tag {{background:rgba(88,166,255,0.15);color:var(--accent);padding:0.15rem 0.6rem;border-radius:12px;font-size:0.8rem;}}
.embed-container {{position:relative;padding-bottom:56.25%;height:0;overflow:hidden;margin:1rem 0;border-radius:8px;}}
.embed-container iframe {{position:absolute;top:0;left:0;width:100%;height:100%;}}
h2 {{margin:2rem 0 0.8rem;padding-bottom:0.3rem;border-bottom:1px solid var(--border);}}
h3 {{margin:1.5rem 0 0.5rem;}} p {{margin-bottom:1rem;}} a {{color:var(--accent);}}
ul,ol {{margin:0.5rem 0 1rem 1.5rem;}} li {{margin-bottom:0.3rem;}}
footer {{text-align:center;padding:2rem;color:var(--muted);font-size:0.85rem;border-top:1px solid var(--border);margin-top:3rem;}}
</style></head>
<body>
<header><span class="logo">◈</span><a href="{prefix}">{sn} Blog</a><span class="sep">·</span><a href="https://{sd}">{sd}</a></header>
<div class="container">
<a href="{prefix}" class="back-link">← Tüm Yazılar</a>
<h1>{icon} {post["title"]}</h1>
<div class="meta">{post["date"]} · {post["author"]} · {post["type"]}</div>
<div class="tags">{tags}</div>
{source_banner}
{embed}
{body}
</div>
<footer>{sn} · <a href="https://{sd}">{sd}</a></footer>
</body></html>'''

def generate_index(posts, site_key, title):
    sn, sd, prefix = SITE_NAMES.get(site_key, (site_key, f"{site_key}.com", "/blog/"))
    cards = []
    for p in posts:
        icon = TYPE_ICONS.get(p["type"], "📄")
        tags = " ".join(f'<span class="tag">{t}</span>' for t in p["tags"])
        source_note = ""
        if site_key != p["canonical_site"]:
            cn = SITE_NAMES.get(p["canonical_site"], [p["canonical_site"]])[0]
            source_note = f'<div class="source-note">Kaynak: <a href="{p["canonical_url"]}">{cn}</a></div>'
        
        cards.append(f'''
<div class="post-card">
  <div class="post-type">{icon} {p["type"]}</div>
  <h2><a href="{prefix}{p["slug"]}">{p["title"]}</a></h2>
  <div class="meta">{p["date"]} · {p["author"]}</div>
  {source_note}
  <div class="excerpt">{p.get("excerpt", "")}</div>
  <div class="tags">{tags}</div>
</div>''')
    
    return f'''<!DOCTYPE html>
<html lang="tr" data-theme="dark">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title} — {sn}</title>
<style>
:root {{--bg:#0d1117;--card:#161b22;--border:#30363d;--text:#c9d1d9;--muted:#8b949e;--accent:#58a6ff;--green:#3fb950;}}
* {{margin:0;padding:0;box-sizing:border-box;}}
body {{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:var(--bg);color:var(--text);line-height:1.7;}}
header {{background:var(--card);border-bottom:1px solid var(--border);padding:1.2rem 2rem;display:flex;align-items:center;gap:1rem;position:sticky;top:0;z-index:10;}}
header a {{color:var(--text);text-decoration:none;font-weight:600;}} header a:hover {{color:var(--accent);}}
header .logo {{color:var(--green);font-size:1.3rem;}} header .sep {{color:var(--muted);}}
.container {{max-width:800px;margin:0 auto;padding:2rem 1.5rem;}}
h1 {{font-size:1.8rem;margin-bottom:1.5rem;}}
.post-list {{display:flex;flex-direction:column;gap:1rem;}}
.post-card {{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:1.5rem;}}
.post-card:hover {{border-color:var(--accent);}}
.post-type {{font-size:0.85rem;color:var(--muted);margin-bottom:0.3rem;}}
.post-card h2 {{font-size:1.3rem;margin-bottom:0.3rem;}}
.post-card h2 a {{color:var(--accent);text-decoration:none;}}
.post-card .meta {{color:var(--muted);font-size:0.85rem;margin-bottom:0.5rem;}}
.post-card .source-note {{font-size:0.8rem;color:var(--green);margin-bottom:0.3rem;}}
.post-card .source-note a {{color:var(--accent);}}
.post-card .excerpt {{color:var(--text);font-size:0.95rem;margin-bottom:0.5rem;}}
.post-card .tags {{display:flex;gap:0.4rem;flex-wrap:wrap;}}
.tag {{background:rgba(88,166,255,0.15);color:var(--accent);padding:0.15rem 0.6rem;border-radius:12px;font-size:0.8rem;}}
footer {{text-align:center;padding:2rem;color:var(--muted);font-size:0.85rem;border-top:1px solid var(--border);margin-top:3rem;}}
</style></head>
<body>
<header><span class="logo">◈</span><a href="{prefix}">{sn} Blog</a><span class="sep">·</span><a href="https://{sd}">{sd}</a></header>
<div class="container"><h1>{title}</h1><div class="post-list">{"".join(cards)}</div></div>
<footer>{sn} · <a href="https://{sd}">{sd}</a></footer>
</body></html>'''

def main():
    all_posts = []
    for f in sorted(POSTS_DIR.glob("*.md"), reverse=True):
        p = parse_post(f)
        if p:
            all_posts.append(p)
    
    all_posts.sort(key=lambda p: p.get("date", ""), reverse=True)
    print(f"📄 {len(all_posts)} icerik bulundu")
    
    all_sites = set()
    for p in all_posts:
        for s in p["sites"]:
            all_sites.add(s)
    print(f"🌐 Siteler: {', '.join(sorted(all_sites))}")
    
    for site_key in sorted(all_sites):
        sn, sd, prefix = SITE_NAMES.get(site_key, (site_key, f"{site_key}.com", "/blog/"))
        site_dir = HTML_DIR / site_key / "blog"
        site_dir.mkdir(parents=True, exist_ok=True)
        
        site_posts = [p for p in all_posts if site_key in p["sites"]]
        
        with open(site_dir / "index.html", "w") as f:
            f.write(generate_index(site_posts, site_key, f"{sn} Blog"))
        
        for p in site_posts:
            with open(site_dir / f"{p['slug']}.html", "w") as f:
                f.write(generate_html(p, site_key))
        
        print(f"  ✅ {site_key}: {len(site_posts)} icerik")
    
    feed = [{
        "title": p["title"], "slug": p["slug"], "type": p["type"],
        "date": p["date"], "author": p["author"],
        "canonical_site": p["canonical_site"],
        "canonical_url": p["canonical_url"],
        "sites": p["sites"], "tags": p["tags"],
        "excerpt": p["excerpt"], "source_url": p["source_url"],
    } for p in all_posts]
    with open(HTML_DIR / "feed.json", "w") as f:
        json.dump(feed, f, indent=2, ensure_ascii=False)
    print(f"  ✅ feed.json: {len(feed)} icerik")

if __name__ == "__main__":
    main()
