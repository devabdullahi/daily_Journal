# Renders post.html inside the site's article template for a local look.
import json, html, re
from pathlib import Path
A = Path(__file__).resolve().parent.parent
meta = json.loads((A / "post.json").read_text())
body = (A / "post.html").read_text()
words = len(re.sub(r"<[^>]+>", " ", body).split())
css = "/Volumes/LaCie/Projects/personal_wesbite/styles.css"
page = f'''<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(meta["title"])}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Lora:ital,wght@0,400;0,700;1,400&display=swap">
<link rel="stylesheet" href="file://{css}"></head><body>
<header class="site-header"><a class="wordmark" href="#">Abdullahi Khalafalla</a></header>
<main id="main"><article><header class="article-header">
<p class="article-category">{meta["category"]} · {max(1, round(words/220))} minute read</p>
<h1>{html.escape(meta["title"])}</h1><p class="article-deck">{html.escape(meta["deck"])}</p>
<p class="article-byline">By Abdullahi Khalafalla · November 6, 2026</p></header>
<div class="article-body">
{body}
</div></article></main></body></html>'''
(A / "preview.html").write_text(page)
print(f"{words} words")
