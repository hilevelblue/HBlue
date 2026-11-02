# Routine「국방군수AI 일일 뉴스 리포트」에 추가할 단계

Routine 편집 화면(https://claude.ai/code/routines/trig_019925H1QEdS5tYVb3arK7p8)에서 프롬프트의 **`## STEP 3: 이메일 발송` 바로 위**에 아래 블록을 붙여넣으세요. 기존 STEP 1·2·3은 그대로 두면 됩니다.

---

```
## STEP 2.5: 웹 파일로 저장 (필수, 메일 발송보다 먼저)

메일 발송 성공 여부와 관계없이 리포트를 GitHub 저장소 hilevelblue/HBlue의 daily/ 폴더에 웹 파일로 저장합니다. 이 단계를 반드시 메일보다 먼저 끝내세요.

1) /tmp/report.html 의 <head>에 <meta name="viewport" content="width=device-width, initial-scale=1"> 가 없으면 <meta charset="UTF-8"> 바로 뒤에 추가하세요(휴대폰에서 보기 위함).
2) mcp__claude-code-remote__add_repo 도구를 owner="hilevelblue", repo="HBlue", access="push"로 호출하고, 결과가 알려주는 clone 명령으로 /tmp/HBlue 에 clone 하세요.
3) Bash로 실행:
   set -e
   cd /tmp/HBlue
   git checkout main && (git pull -q origin main || true)
   DAY="$(TZ=Asia/Seoul date +%F)"
   mkdir -p daily
   cp /tmp/report.html "daily/$DAY.html"
   if [ ! -f daily/build_index.py ]; then
     git fetch -q origin ccr-3313595f-s2zvik && git checkout origin/ccr-3313595f-s2zvik -- daily/build_index.py daily/README.md
   fi
   python3 daily/build_index.py
   git add daily
   git -c user.name="Claude" -c user.email="noreply@anthropic.com" commit -qm "daily report $DAY"
   git push origin main
4) push가 거부되면 git push origin HEAD:claude/daily-reports 로 대신 push 하고, 아래 링크의 main 을 claude/daily-reports 로 바꿔 보고하세요.
5) 최종 보고에 다음 링크를 넣으세요:
   - 오늘 리포트: https://htmlpreview.github.io/?https://github.com/hilevelblue/HBlue/blob/main/daily/{DAY}.html
   - 전체 목록:  https://htmlpreview.github.io/?https://github.com/hilevelblue/HBlue/blob/main/daily/index.html

STEP 3(메일)은 SMTP 포트가 막혀 실패할 수 있습니다. 실패하면 한 번만 시도하고 우회 방법을 찾지 말고 "메일 발송 실패(SMTP 차단) — 웹 파일로 저장됨"이라고 보고하세요.
```
