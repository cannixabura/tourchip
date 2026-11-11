# 抽出 lib/ 裡所有 tx('中文', 'English') 的字串對，輸出 JSON（翻譯表的來源）
# 字串裡的 $var / ${expr} 會變成 {var} / {expr} 佔位符
import re, json, sys, pathlib

def read_str(s, i):
    q = s[i]
    raw = s[i:i+3] in ("'''", '"""')
    if raw: raise ValueError('triple quotes')
    j = i + 1; out = []
    while j < len(s):
        c = s[j]
        if c == '\\':
            out.append(s[j:j+2]); j += 2; continue
        if c == '$':
            if s[j+1] == '{':
                depth = 1; k = j + 2
                while depth:
                    if s[k] == '{': depth += 1
                    elif s[k] == '}': depth -= 1
                    k += 1
                out.append('{' + s[j+2:k-1] + '}'); j = k; continue
            m = re.match(r'\$([A-Za-z_]\w*)', s[j:])
            out.append('{' + m.group(1) + '}'); j += len(m.group(0)); continue
        if c == q: return ''.join(out), j + 1
        out.append(c); j += 1
    raise ValueError('unterminated')

def unescape(t):
    return t.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n').replace('\\$', '$').replace('\\\\', '\\')

pairs = {}
for f in sorted(pathlib.Path('lib').rglob('*.dart')):
    s = f.read_text(encoding='utf-8')
    # tx('中文', 'English')，以及求助卡用的 txIn(語言, '中文', 'English')
    for m in re.finditer(r'\btx(?:In\(\s*[A-Za-z_]\w*\s*,\s*|\(\s*)', s):
        i = m.end()
        try:
            if s[i] not in "'\"": continue
            zh, i = read_str(s, i)
            # 相鄰字串接起來
            while True:
                k = i
                while s[k] in ' \n\t': k += 1
                if s[k] in "'\"" and s[k-1] in ' \n\t' and s[k:k+1] != ',':
                    more, i = read_str(s, k); zh += more
                else: break
            k = i
            while s[k] in ' \n\t,': k += 1
            if s[k] not in "'\"": continue
            en, i = read_str(s, k)
            while True:
                k = i
                while s[k] in ' \n\t': k += 1
                if s[k] in "'\"":
                    more, i = read_str(s, k); en += more
                else: break
            pairs[unescape(zh)] = unescape(en)
        except Exception as e:
            print('skip', f, s[m.start():m.start()+60].replace('\n',' '), e, file=sys.stderr)
json.dump([{'zh': k, 'en': v} for k, v in pairs.items()], sys.stdout, ensure_ascii=False, indent=0)
