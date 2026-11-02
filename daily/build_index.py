#!/usr/bin/env python3
# daily/ 폴더의 YYYY-MM-DD.html 리포트 목록으로 daily/index.html 을 다시 만든다.
import html, pathlib, re
d = pathlib.Path(__file__).resolve().parent
days = sorted((p.stem for p in d.glob("*.html") if re.fullmatch(r"\d{4}-\d{2}-\d{2}", p.stem)), reverse=True)
PREVIEW = "https://htmlpreview.github.io/?https://github.com/hilevelblue/HBlue/blob/main/daily/"
rows = "\n".join(
    f'<li><a href="{day}.html">{day}</a> <span class="alt">· <a href="{PREVIEW}{day}.html">미리보기 링크</a></span></li>'
    for day in days)
page = f"""<!DOCTYPE html>
<html lang="ko"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>국방군수AI 일일 리포트 목록</title>
<style>
body{{font-family:'맑은 고딕','Noto Sans KR',sans-serif;max-width:720px;margin:32px auto;padding:0 16px;color:#222;background:#fff}}
h1{{color:#1F3864;border-bottom:2px solid #1F3864;padding-bottom:4px;font-size:1.4em}}
ul{{list-style:none;padding:0}} li{{padding:8px 0;border-bottom:1px solid #e3e8f0}}
a{{color:#2E74B5;font-weight:bold;text-decoration:none}} .alt a{{font-weight:normal;font-size:.9em}}
p.note{{color:#666;font-size:.9em}}
</style></head><body>
<h1>국방 군수 AI 활용 방안 연구 · 일일 리포트</h1>
<p class="note">메일 발송 여부와 관계없이 매일 자동 저장됩니다. 총 {len(days)}건 (최신순)</p>
<ul>
{rows}
</ul>
</body></html>
"""
(d / "index.html").write_text(page, encoding="utf-8")
print(f"index.html: {len(days)} reports")
