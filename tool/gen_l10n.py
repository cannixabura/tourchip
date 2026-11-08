# 由 tool/tx_source.json（python3 tool/extract_tx.py > tool/tx_source.json）＋ tool/i18n/ui.tsv（日韓馬印越泰譯文）產生 lib/l10n_table.dart
# 譯文的 {0}、{1}… 依英文字串裡佔位符出現的順序編號
import json, re, glob, sys
src = json.load(open('tool/tx_source.json', encoding='utf-8'))
rows = {}
for line in open('tool/i18n/ui.tsv', encoding='utf-8'):
    line = line.rstrip('\n')
    if not line or line.startswith('#'): continue
    c = line.split('\t')
    assert len(c) == 7, c[0]
    rows[c[0].replace('\\n', '\n')] = c[1:]
missing = [e['zh'] for e in src if e['zh'] not in rows]
if missing: sys.exit('沒有譯文：\n' + '\n'.join(missing))
PH = re.compile(r'\{([^{}]+)\}')
def esc(s): return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n').replace('$', '\\$') + "'"
out = ['// 由 tool/gen_l10n.py 產生，請勿手改。改譯文請改 tool/i18n/ui.tsv 再執行：python3 tool/gen_l10n.py',
       '// 每筆：中文（佔位符 {0}…）、英文（{0}…）、日、韓、馬來、印尼、越南、泰',
       '// ignore_for_file: lines_longer_than_80_chars', '',
       'const uiTable = <List<String>>[']
bad = 0
for i, e in enumerate(src):
    order = []
    for m in PH.finditer(e['en']):
        if m.group(1) not in order: order.append(m.group(1))
    zorder = [m.group(1) for m in PH.finditer(e['zh'])]
    def num(s, zh=False):
        def r(m):
            k = m.group(1)
            if k in order: return '{%d}' % order.index(k)
            # 中英寫法不同的運算式：數量一樣就照位置對應，否則中文那邊當成萬用字元
            if zh and len(zorder) == len(order): return '{%d}' % zorder.index(k)
            return '{*}'
        return PH.sub(r, s)
    zh, en = num(e['zh'], True), num(e['en'])
    tr = rows[e['zh']]
    for t in tr:
        need = set(re.findall(r'\{\d+\}', en)); got = set(re.findall(r'\{\d+\}', t))
        if need != got: print('placeholder mismatch', i, en, t, file=sys.stderr); bad += 1
    out.append('  [' + ', '.join(esc(x) for x in [zh, en] + tr) + '],')
out.append('];')
open('lib/l10n_table.dart', 'w', encoding='utf-8').write('\n'.join(out) + '\n')
print('entries', len(src), 'problems', bad)
