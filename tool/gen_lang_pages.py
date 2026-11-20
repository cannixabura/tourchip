"""官網首頁的各語言網址：/en/、/ja/ … 各一份 index.html，讓 LINE、Facebook、X 等分享預覽（不跑 JS）
看到該語言的標題、說明和 OG 圖（hosting/img/og/<lang>.jpg，tool/gen_og.py 產生）。
用法：python3 tool/gen_lang_pages.py（改了 hosting/index.html 或 home-i18n.js 之後要重跑，再部署）
頁面內容和首頁一樣，語言由 i18n.js 依網址路徑決定。繁中仍是首頁 /。
"""
import html, json, os, re, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
H = f'{ROOT}/hosting'
SITE = 'https://tourchip.web.app'
LANGS = ['zh-Hans', 'en', 'ja', 'ko', 'ms', 'id', 'vi', 'th', 'pt', 'es', 'hi', 'fr', 'de', 'it', 'cs', 'pl', 'uk']

# 讀 home-i18n.js 的 window.TC_I18N
I18N = json.loads(subprocess.run(['node', '-e', '''
const fs=require('fs'); const window={}; eval(fs.readFileSync(process.argv[1],'utf8'));
process.stdout.write(JSON.stringify(window.TC_I18N));''', f'{H}/home-i18n.js'], capture_output=True, text=True, check=True).stdout)


def url(lang):
    return f'{SITE}/' if lang == 'zh-Hant' else f'{SITE}/{lang}/'


def alternates():
    rows = [f'<link rel="alternate" hreflang="{l}" href="{url(l)}">' for l in ['zh-Hant'] + LANGS]
    rows.append(f'<link rel="alternate" hreflang="x-default" href="{url("en")}">')
    return '\n'.join(rows)


def sub_meta(src, prop, value, attr='property'):
    pat = re.compile(rf'(<meta {attr}="{re.escape(prop)}"[^>]*content=")[^"]*(")')
    assert pat.search(src), prop
    return pat.sub(lambda m: m.group(1) + html.escape(value, quote=True) + m.group(2), src, count=1)


def build(src, lang):
    d = I18N[lang]
    s = src.replace('<html lang="zh-Hant">', f'<html lang="{lang}">', 1)
    s = re.sub(r'<title[^>]*>[^<]*</title>', lambda m: re.sub(r'>[^<]*<', '>' + html.escape(d['home_title']) + '<', m.group(0), count=1), s, count=1)
    s = sub_meta(s, 'description', d['meta_desc'], attr='name')
    s = sub_meta(s, 'og:site_name', '旅行团 TourChip' if lang == 'zh-Hans' else 'TourChip')
    s = sub_meta(s, 'og:title', d['og_title'])
    s = sub_meta(s, 'og:description', d['meta_desc'])
    s = sub_meta(s, 'og:image', f'{SITE}/img/og/{lang}.jpg')
    s = sub_meta(s, 'og:url', url(lang))
    s = s.replace(f'<link rel="canonical" href="{SITE}/">', f'<link rel="canonical" href="{url(lang)}">', 1)
    return s


def main():
    src = open(f'{H}/index.html', encoding='utf-8').read()
    # 首頁本身也加上各語言對照（只加一次）
    if 'hreflang="x-default"' not in src:
        src = src.replace(f'<link rel="canonical" href="{SITE}/">', f'<link rel="canonical" href="{SITE}/">\n' + alternates(), 1)
        open(f'{H}/index.html', 'w', encoding='utf-8').write(src)
    for lang in LANGS:
        os.makedirs(f'{H}/{lang}', exist_ok=True)
        open(f'{H}/{lang}/index.html', 'w', encoding='utf-8').write(build(src, lang))
        print(lang)


if __name__ == '__main__':
    main()
