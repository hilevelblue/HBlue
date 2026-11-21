국방 군수 AI 일일 리포트 - HTML 전용판
==========================================

바뀐 점
- 메일을 보내지 않습니다. 비밀번호를 묻지 않습니다(입력 창 없음).
- Word / PowerPoint / HWP 는 만들지 않고, HTML 파일 하나만 만듭니다.
- 매일 정해진 시각에 창 없이(cmd/PowerShell 창 안 뜸) 조용히 실행됩니다.

설치 (한 번만)
1. 이 폴더를 원하는 곳에 둡니다. (예: C:\defense_ai_research - 기존 폴더에 덮어써도 됩니다)
2. setup_scheduler.bat 를 더블클릭합니다.
   - 비밀번호를 묻던 기존 예약 작업을 찾아 지우고, 새 작업(DefenseAI_DailyReport)을 등록합니다.
   - 지운 작업과 남아 있는 작업 목록이 화면에 나옵니다.
3. 바로 확인하려면 run_now.bat 를 더블클릭합니다. (이건 수동 실행이라 창이 보입니다)

리포트 보는 곳 (config.json 의 report_directory, 기본값 D:\@Down\defense_ai_reports)
- index.html  : 날짜별 리포트 목록
- latest.html : 가장 최근 리포트
- defense_ai_report_YYYYMMDD_HHMMSS.html : 날짜별 리포트
- last_run.log : 마지막 실행 기록(문제가 있을 때 확인)

설정 바꾸기
- 실행 시각: config.json 의 schedule_time 을 고친 뒤 setup_scheduler.bat 를 다시 실행
- 저장 폴더/검색어: config.json 수정 (다음 실행부터 적용)

그래도 비밀번호 창이 뜨면
- setup_scheduler.bat 실행 화면 끝의 '현재 등록된 사용자 작업' 목록에서 해당 작업을 찾아
  작업 스케줄러(taskschd.msc)에서 '사용 안 함' 또는 삭제하세요.
- 시작프로그램 폴더(Win+R → shell:startup)에 관련 바로가기가 있는지도 확인하세요.

작업 제거
- PowerShell: Unregister-ScheduledTask -TaskName 'DefenseAI_DailyReport' -Confirm:$false
