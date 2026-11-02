#!/usr/bin/env python3
# 사용법: python3 daily/to_email_html.py report.html email.html [웹보기URL] [목록URL]
# Gmail 커넥터는 <style>·CSS background를 지우므로, 리포트를 인라인 스타일 + 표 bgcolor 형식으로 바꾼다.
import re, sys

src, dst = sys.argv[1], sys.argv[2]
web = sys.argv[3] if len(sys.argv) > 3 else ""
idx = sys.argv[4] if len(sys.argv) > 4 else ""
h = open(src, encoding="utf-8").read()
m = re.search(r"<body[^>]*>(.*)</body>", h, re.S | re.I)
body = m.group(1) if m else h

FONT = "font-family:'Malgun Gothic','맑은 고딕',sans-serif;"
body = re.sub(r"<h1>", f'<h1 style="{FONT}color:#1F3864;border-bottom:2px solid #1F3864;padding-bottom:4px;font-size:20px;margin:24px 0 8px">', body)
body = re.sub(r"<h2>", f'<h2 style="{FONT}color:#2E74B5;font-size:16px;margin:16px 0 6px">', body)
body = re.sub(r"<h3>", f'<h3 style="{FONT}color:#5B9BD5;font-size:14px">', body)
body = re.sub(r"<p>", '<p style="margin:4px 0;line-height:1.6">', body)
body = re.sub(r'<span class="label ko">(.*?)</span>', r'<b style="color:#1F5C8B">\1</b>', body)
body = re.sub(r'<span class="label">(.*?)</span>', r"<b>\1</b>", body)
body = re.sub(r'<span class="ko">(.*?)</span>', r'<span style="color:#1F5C8B">\1</span>', body, flags=re.S)
body = re.sub(r'<div class="article">(.*?)</div>',
              r'<table width="100%" cellpadding="8" cellspacing="0" border="0" style="margin:0 0 12px;border-left:3px solid #2E74B5"><tr><td bgcolor="#f5f8ff" style="font-size:14px;color:#222">\1</td></tr></table>',
              body, flags=re.S)
body = re.sub(r'<div class="summary">(.*?)</div>',
              r'<table width="100%" cellpadding="16" cellspacing="0" border="0" style="margin:16px 0;border:1px solid #2E74B5"><tr><td bgcolor="#eef4ff" style="font-size:14px;line-height:1.8;color:#222">\1</td></tr></table>',
              body, flags=re.S)
body = re.sub(r"<a href=", '<a style="color:#2E74B5;word-break:break-all" href=', body)

links = ""
if web:
    links = (f'<tr><td style="padding:10px 0 4px"><table cellpadding="0" cellspacing="0" border="0"><tr>'
             f'<td bgcolor="#1747a6" style="padding:9px 16px"><a href="{web}" style="color:#ffffff;font-weight:bold;text-decoration:none">🌐 웹에서 보기</a></td>'
             + (f'<td width="8"></td><td bgcolor="#0e7a55" style="padding:9px 16px"><a href="{idx}" style="color:#ffffff;font-weight:bold;text-decoration:none">📚 지난 리포트</a></td>' if idx else "")
             + "</tr></table></td></tr>")
out = f"""<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td align="center">
<table width="760" cellpadding="0" cellspacing="0" border="0" style="max-width:760px;width:100%;{FONT}font-size:14px;color:#222">
{links}
<tr><td style="padding:8px 4px">{body}</td></tr>
<tr><td style="padding:16px 4px;color:#888;font-size:12px">자동 수집·번역 기반 리포트입니다. 종합 요약은 분석 의견입니다.</td></tr>
</table></td></tr></table>"""
open(dst, "w", encoding="utf-8").write(out)
print(f"OK {dst} {len(out)} chars")
