# 국방군수AI 일일 뉴스 리포트 보관함

Routine「국방군수AI 일일 뉴스 리포트 (Gmail)」(매일 08:53 KST)이 만든 HTML 리포트를 `daily/YYYY-MM-DD.html`에 저장합니다. 저장은 메일 발송보다 먼저 하므로 메일이 실패한 날에도 리포트가 남습니다. 메일은 Gmail 커넥터로 보냅니다.

- 목록: [daily/index.html](https://htmlpreview.github.io/?https://github.com/hilevelblue/HBlue/blob/main/daily/index.html)
- 특정 날짜: `https://htmlpreview.github.io/?https://github.com/hilevelblue/HBlue/blob/main/daily/YYYY-MM-DD.html`
- GitHub Pages를 켜면(Settings → Pages → Branch `main` / root) `https://hilevelblue.github.io/HBlue/daily/`에서 바로 볼 수 있습니다.

## 스크립트
- `build_index.py` — `daily/` 안의 리포트로 `index.html` 목록을 다시 만듭니다.
- `to_email_html.py report.html email.html [웹URL] [목록URL]` — Gmail 커넥터가 `<style>`과 CSS 배경을 지우기 때문에, 리포트를 인라인 스타일과 표 `bgcolor` 형식의 메일 본문으로 바꿉니다.
