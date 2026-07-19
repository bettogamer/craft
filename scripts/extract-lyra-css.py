#!/usr/bin/env python3
# extract-lyra-css.py — decodifica un .mhtml de shadcn (tema Lyra) y extrae SOLO
# lo que Craft necesita, para no rebuscar a mano en el mhtml (quoted-printable, 2.9 MB):
#
#   1. --tokens   La paleta de tokens (:root claro + .dark) con oklch y su conversión
#                 a RGBA 0-1 (lo que consumen los componentes Craft). Salida markdown.
#   2. --css      Un .css PLANO y grepeable con solo las reglas por-componente
#                 (selectores con data-slot / data-state / data-active), dedup + ordenadas.
#
# Uso:
#   python scripts/extract-lyra-css.py "shadcn-pages/Repo - shadcn_ui.mhtml" --tokens
#   python scripts/extract-lyra-css.py "shadcn-pages/Repo - shadcn_ui.mhtml" --css > docs/reference/lyra-repo.css
#
# El CSS Lyra NO es fetcheable (login del owner); estos .mhtml son la única fuente real.
# Ver docs/lyra-tokens.md (generado con --tokens) y la memoria craft-shadcn-pages-reference.

import argparse
import email
import math
import re
from email import policy

# ── oklch → sRGB (0-1) ──────────────────────────────────────────────────────
def _oklch_to_rgb(L, C, H):
    a = C * math.cos(math.radians(H))
    b = C * math.sin(math.radians(H))
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.2914855480 * b
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    def gamma(x):
        x = max(0.0, min(1.0, x))
        return 1.055 * (x ** (1 / 2.4)) - 0.055 if x > 0.0031308 else 12.92 * x

    return gamma(r), gamma(g), gamma(bl)


_OKLCH_RE = re.compile(
    r'oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*(?:/\s*([\d.]+%?))?\s*\)', re.I)


def oklch_to_rgba(value):
    """'oklch(0.148 0.004 228.8)' or '... / 15%)' → (r,g,b,a) floats 0-1, or None."""
    m = _OKLCH_RE.search(value)
    if not m:
        return None
    L, C, H = float(m.group(1)), float(m.group(2)), float(m.group(3))
    alpha = 1.0
    if m.group(4):
        a = m.group(4)
        alpha = float(a[:-1]) / 100.0 if a.endswith('%') else float(a)
    r, g, b = _oklch_to_rgb(L, C, H)
    return r, g, b, alpha


# ── mhtml → css chunks ──────────────────────────────────────────────────────
def css_parts(path):
    msg = email.message_from_file(open(path, encoding='utf-8'), policy=policy.default)
    for p in msg.walk():
        if p.get_content_type() == 'text/css':
            yield p.get_payload(decode=True).decode('utf-8', 'replace')


def all_css(path):
    return '\n'.join(css_parts(path))


# ── token palette ───────────────────────────────────────────────────────────
# Un bloque de tema define --primary: oklch(...) junto a --input/--muted.
_TOKEN_BLOCK_RE = re.compile(r'\{([^{}]*--primary:\s*oklch[^{}]*)\}')
_DECL_RE = re.compile(r'(--[\w-]+):\s*([^;]+)')


def token_blocks(css):
    """Return [ {name: value} ] for each theme block found (first = light, then dark)."""
    blocks = []
    seen = set()
    for m in _TOKEN_BLOCK_RE.finditer(css):
        body = m.group(1)
        if '--input' not in body and '--muted' not in body:
            continue
        toks = {}
        for d in _DECL_RE.finditer(body):
            toks[d.group(1)] = d.group(2).strip()
        key = tuple(sorted(toks.items()))
        if key in seen:
            continue
        seen.add(key)
        blocks.append(toks)
    return blocks


def fmt_rgba(value):
    rgba = oklch_to_rgba(value)
    if rgba is None:
        return ''  # non-oklch (e.g. --radius: 0)
    r, g, b, a = rgba
    return f'{r:.3f}, {g:.3f}, {b:.3f}, {a:.3f}'


def emit_tokens(path):
    css = all_css(path)
    blocks = token_blocks(css)
    if not blocks:
        print('!! no token blocks found')
        return
    names = ['(light :root)', '(.dark)'] + [f'(block {i})' for i in range(2, len(blocks))]
    for name, toks in zip(names, blocks):
        print(f'\n### {name}\n')
        print('| Token | oklch (fuente) | r, g, b, a (0-1) |')
        print('|---|---|---|')
        for k, v in toks.items():
            print(f'| `{k}` | `{v}` | {fmt_rgba(v)} |')


# ── component rules (data-slot / data-state / data-active) ───────────────────
_RULE_RE = re.compile(r'([^{}]+)\{([^{}]*)\}')
_KEEP = ('data-slot', 'data-state', 'data-active', 'data-selected', 'data-favorite')


def emit_css(path):
    seen = set()
    rules = []
    for css in css_parts(path):
        for m in _RULE_RE.finditer(css):
            sel = m.group(1).strip()
            if not any(k in sel for k in _KEEP):
                continue
            body = ' '.join(m.group(2).split())
            rule = f'{sel} {{ {body} }}'
            if rule in seen:
                continue
            seen.add(rule)
            rules.append(rule)
    print(f'/* extracted from {path} - {len(rules)} component rules */')
    for r in sorted(rules):
        print(r)


# ── cli ─────────────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('mhtml')
    ap.add_argument('--tokens', action='store_true', help='emit token palette (markdown)')
    ap.add_argument('--css', action='store_true', help='emit flat component css')
    args = ap.parse_args()
    if args.tokens:
        emit_tokens(args.mhtml)
    if args.css:
        emit_css(args.mhtml)
    if not (args.tokens or args.css):
        ap.error('pick --tokens and/or --css')


if __name__ == '__main__':
    main()
