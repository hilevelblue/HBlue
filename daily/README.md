# 국방군수AI 일일 뉴스 리포트 보관함

Routine「국방군수AI 일일 뉴스 리포트」가 매일 만든 HTML 리포트를 `daily/YYYY-MM-DD.html`에 저장합니다. 메일 발송(SMTP)이 실패한 날에도 저장됩니다.

- 목록: [daily/index.html](https://htmlpreview.github.io/?https://github.com/hilevelblue/HBlue/blob/main/daily/index.html)
- 특정 날짜: `https://htmlpreview.github.io/?https://github.com/hilevelblue/HBlue/blob/main/daily/YYYY-MM-DD.html`
- GitHub Pages를 켜면(Settings → Pages → Branch `main` / root) `https://hilevelblue.github.io/HBlue/daily/`에서 바로 볼 수 있습니다.
- `python3 daily/build_index.py`를 실행하면 `index.html` 목록을 다시 만듭니다.
