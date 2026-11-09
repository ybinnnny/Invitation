# 분당 8선녀 송년회 모바일 초대장

정적 페이지(GitHub Pages) + Supabase(조 선택·수다공간 DB, 사진 저장소). 로그인 없이 링크로 접속.

## 페이지 구성

| 영역 | 내용 |
|---|---|
| 상단 | 제목, D-day, **공유하기**(초대장 링크 복사), 바로가기 메뉴 |
| 일정 | 날짜·시간·장소·준비물 |
| 오시는 길 | 네이버 지도 버튼, 주소 복사 |
| 드레스코드 | 색상 안내 |
| 조 선택 | 선착순 마감, 조당 4명, 내 자리 취소 |
| 프로그램 | 게임 소개(영상 링크, 소개 팝업), 경품 추첨 안내 |
| 사진첩 | 방문자가 직접 업로드, 이미지 5MB 이하 |
| 수다공간 | 제안·문의·잡담을 남기는 자유 게시판. 작성자명은 직접 입력(비우면 익명) |

```
index.html          페이지 구조 + 게임 소개 팝업 + 카카오톡 공유용 메타 태그
css/style.css       디자인
js/config.js        ★ 행사 정보·Supabase 접속값 (여기만 고치면 됨)
js/app.js           조 선택·사진 업로드·수다공간·자동 갱신 로직
img/                게임 소개 팝업의 예시 이미지 (360px)
og.jpg              카카오톡 공유 썸네일 (1200×630)
supabase/schema.sql Supabase 에 한 번 실행할 SQL (조 선택 + 사진)
supabase/chat.sql   수다공간(자유 게시판) SQL — schema.sql 다음에 실행
```

## 1. Supabase 준비 (약 10분)

1. https://supabase.com 에 개인 계정으로 가입하고 **New project** 를 만듭니다.
   - Region 은 `Northeast Asia (Seoul)`, DB 비밀번호는 아무 데도 적지 마세요.
   - 생성 화면의 보안 옵션: **Enable Data API 체크 유지**, **Automatically expose new tables 해제**, **Enable automatic RLS 체크**.
2. **SQL Editor** 에 `supabase/schema.sql` 전체를 붙여넣고 **Run** 합니다.
   - 확인: Table Editor 에 `team_slots`, Storage 에 `photos` 버킷(Public, 5MB)이 보이면 성공이에요.
   - 이어서 `supabase/chat.sql` 도 같은 방법으로 실행합니다. Table Editor 에 `chat_messages` 가 보이면 성공이에요.
3. **Project Settings → API keys**(또는 Data API)에서 다음 두 값을 `js/config.js` 의 `supabase` 에 넣습니다.
   - `url`: Project URL — `https://xxxx.supabase.co` 까지만. 끝에 `/rest/v1/` 는 붙이지 않습니다.
   - `key`: **publishable key**(`sb_publishable_…`) 또는 legacy **anon** key
   - ⚠ `service_role` / `secret` 키는 절대 넣지 마세요. 넣으면 DB 전체 권한이 공개됩니다.
4. 행사 정보(일시, 장소, 준비물, 조 이름, 게임 영상 링크)는 `js/config.js` 에 있어요. 바뀌면 그 파일만 고치면 됩니다. 문구, 드레스코드, 프로그램·게임 소개 설명은 `index.html` 에 있어요.

## 2. GitHub Pages 배포 (github.com)

> 사내 `oss.navercorp.com` 은 외부 폰에서 접속할 수 없으므로 개인 **github.com** 계정을 사용합니다.
> 무료 플랜은 **공개 레포**여야 하므로 소스와 `og.jpg`·`img/` 의 사진이 누구에게나 보입니다. 실명, 연락처, 상세 주소, 사람 얼굴 사진을 넣을지 판단해 주세요.

1. github.com 에서 새 **Public** 레포를 만듭니다. 이름은 추측하기 어렵게 짓는 걸 권장해요 (예: `ys-2026-party-x7k`).
2. 이 폴더에서 아래를 실행합니다. 공개 레포라 커밋 이메일이 노출되므로 회사 메일 대신 GitHub noreply 메일을 쓰세요 (GitHub Settings → Emails 에서 확인).
   ```bash
   git init -b main
   git config user.email "<숫자>+<username>@users.noreply.github.com"
   git add index.html css js img og.jpg supabase README.md .gitignore
   git commit -m "송년회 초대장"
   git remote add origin https://github.com/<username>/<repo>.git
   git push -u origin main
   ```
   - 처음 push 할 때 GitHub 로그인 창이 뜹니다. 개인 계정으로 로그인하세요.
3. 레포의 **Settings → Pages → Build and deployment** 에서 Source 를 `Deploy from a branch`, `main` / `/ (root)` 로 지정합니다. 같은 화면의 Visibility(Enterprise 유료 체험)는 누르지 않습니다.
4. 1~2분 뒤 `https://<username>.github.io/<repo>/` 로 접속해 확인합니다.

## 3. 링크 공유 전 체크리스트

- [ ] 폰(LTE, 사내 와이파이 아님)으로 접속 → 일정·지도 버튼·게임 팝업 확인
- [ ] 조 선택 테스트 → 참가 → 취소. 끝나면 SQL Editor 에서 `truncate public.team_slots;`
- [ ] 사진 1장 업로드 테스트 → Storage 에서 삭제
- [ ] 수다공간 글 1개 남기기·삭제 테스트. 끝나면 SQL Editor 에서 `truncate public.chat_messages;`
- [ ] 카카오톡 나에게 보내기로 공유 썸네일 확인 (아래 4번)
- [ ] **Supabase 무료 프로젝트는 1주일간 요청이 없으면 일시정지돼요.** 링크 공유 직전과 행사 당일 아침에 대시보드에서 상태를 확인하고, Paused 면 Restore 하세요.

## 4. 카카오톡 공유 썸네일

- `index.html` 의 `og:title`·`og:description`·`og:type`·`og:url`·`og:image` 태그를 읽어 미리보기를 만듭니다. `og:image` 는 **전체 주소**(`https://…/og.jpg`)여야 하고, 크기는 1200×630 JPG 를 권장해요 (수백 KB 이하).
- 썸네일에는 제목·일시·장소를 크게 넣으세요. 카톡 미리보기에서는 글자가 작게 보입니다.
- 카카오톡은 **주소 단위로 미리보기를 저장**합니다. 한 번이라도 보낸 주소는 이미지를 바꿔도 예전 모습이 나와요.
  - 해결 1: 링크 끝에 이전에 안 쓴 꼬리표를 붙여 보냅니다 (`.../?v=3`). 같은 페이지가 열립니다.
  - 해결 2: 카카오 개발자 사이트의 공유 디버거(https://developers.kakao.com/tool/debugger/sharing)에서 주소를 넣고 캐시를 초기화합니다. 원래 주소를 그대로 쓸 수 있어 가장 깔끔해요.
  - 페이지의 **공유하기** 버튼은 꼬리표를 뺀 깨끗한 주소를 복사하므로, 디버거로 캐시를 초기화해 두는 편이 안전합니다.

## 5. 수정할 때 주의 (캐시)

- GitHub Pages 는 파일을 브라우저에 10분간 저장하게 합니다. 새 HTML 과 예전 JS 가 섞이면 기능이 안 되는 것처럼 보여요 (예: 「남기기」가 저장 없이 페이지만 새로고침).
  - **`css`·`js` 를 고칠 때마다 `index.html` 의 `?v=` 값(`style.css`, `config.js`, `app.js` 세 곳)을 같이 올립니다.**
- 카카오톡 같은 앱 안 브라우저는 예전 화면을 그대로 되살릴 수 있어요. 그래서 `app.js` 는
  - 화면 복원·복귀(`pageshow`, `focus`, `online`, `visibilitychange`) 때 바로 새로 불러오고(2초 안에 여러 번 와도 한 번),
  - 15초마다도 자동으로 새로 불러오며,
  - 수다공간에 「🔄 새로고침」 버튼과 「마지막 갱신」 시각을 보여줍니다.
- 앱 안 브라우저와 기본 브라우저(크롬·사파리)는 **브라우저 저장소(localStorage)가 따로**예요. 이름 자동 채우기, 조 자리 취소, 내 글 삭제 버튼은 참가·작성한 브라우저에서만 보입니다. 고장이 아닙니다.

## 6. 동작 방식 / 보안 메모

| 기능 | 방식 |
|---|---|
| 정원 초과 방지 | `join_team()` 이 전역 잠금(advisory lock)으로 요청을 하나씩 처리하고, PK(조, 좌석) + 좌석 1~4 제약이 최종 방어선 역할을 함 |
| 본인만 취소 | 참가 시 받은 토큰을 그 폰의 localStorage 에 저장하고, `leave_team(token)` 으로만 삭제 가능. 폰이나 브라우저를 바꾸면 취소할 수 없으니 관리자가 SQL 로 처리 |
| 이름 중복 | 같은 이름(대소문자·앞뒤 공백 무시)은 한 자리만 가능 |
| 사진 | 브라우저에서 긴 변 1920px JPEG 로 줄여 업로드. 버킷이 5MB 와 이미지 형식을 서버에서 강제 |
| 사진 권한 | 익명 사용자는 목록 보기와 `uploads/` 업로드만 가능(총 300장). 수정·삭제 불가 |
| 수다공간 | `post_message()` 로 글 남기기(작성자명을 비우면 '익명', 내용 1~300자), `list_messages()` 로 최신순 조회. 전체 300개 상한, 1분에 15개 초과 시 거부. 테이블은 외부에서 직접 읽거나 쓸 수 없음 |
| 내 글 삭제 | 글을 쓸 때 받은 토큰을 그 폰의 localStorage 에 저장하고, `delete_message(token)` 으로만 삭제 가능. 다른 사람 글은 관리자가 SQL 로 삭제 |
| 노출되는 키 | publishable(anon) key 만 노출되며, 위 함수와 정책 범위 밖으로는 쓸 수 없음 |

**한계**: 로그인이 없어서 링크를 아는 사람은 누구나 조를 고르고, 사진을 올리고, 글을 남길 수 있어요. 남의 이름으로 자리를 잡거나 글을 남기는 장난을 막는 장치는 없으니, 생기면 관리자가 SQL 로 정리하세요. 수다공간에는 연락처 같은 개인정보를 적지 않도록 화면에 안내합니다.

## 7. 무료 플랜 한도 (2026-11 공식 문서 기준)

한도에는 **쌓여 있는 양**(지우면 줄어듦)과 **월별 사용량**(달이 바뀌면 0으로 초기화)이 있어요. 휴대폰으로 치면 저장 공간과 데이터 요금제의 차이입니다.

| 구분 | 항목 | 한도 | 이 초대장 |
|---|---|---|---|
| 쌓여 있는 양 | Supabase 활성 프로젝트 | 2개 | 1개 |
| | 데이터베이스 | 500MB | 몇 KB |
| | 파일 저장소 | 1GB | 사진 300장 × 약 0.5MB |
| 월별 사용량 | Supabase 데이터 전송량(egress) | 5GB (+ 캐시 전송 5GB) | 8명이 사진을 모두 한 번씩 봐도 1~2GB 안팎 (추정) |
| | GitHub Pages 대역폭 | 100GB (소프트 한도) | 몇 MB |

- 한도를 넘으면 요금이 아니라 **서비스 제한**(읽기 전용, API 402 오류 등)이 걸리고 다음 주기에 풀립니다. 사진을 지워도 이미 쓴 전송량은 줄지 않아요.
- Supabase 무료 플랜은 **백업이 없고**, 1주일 요청이 없으면 프로젝트가 멈춥니다. 이미지 변환 기능이 없어 사진은 원본 크기로 내려오므로(업로드할 때 1920px 로 줄임) 사진이 많이 쌓이면 첫 화면이 느릴 수 있어요.
- 사용량은 Supabase 대시보드 Organization → Usage 에서 볼 수 있어요.
- GitHub 무료 계정은 **Pages 를 공개 레포에서만** 쓸 수 있고, 레포 개수 제한은 없습니다.

## 8. 관리자용 SQL (Supabase SQL Editor)

```sql
select * from public.team_slots order by team, seat;                      -- 조 현황
delete from public.team_slots where name = '홍길동';                       -- 한 명 빼기
truncate public.team_slots;                                               -- 조 전체 초기화

select id, name, body, created_at from public.chat_messages order by id desc;   -- 수다공간 글 보기
delete from public.chat_messages where id = 123;                          -- 글 한 개 삭제
truncate public.chat_messages;                                            -- 글 전체 초기화
```

사진은 대시보드 Storage → photos → uploads 에서 선택 삭제합니다. SQL 로 `storage.objects` 를 지우면 실제 파일이 남을 수 있어요.

## 9. 행사 후 정리

- 사진을 내려받아 보관합니다.
- Supabase 는 둘 중 하나를 고릅니다.
  - **삭제**: 프로젝트를 삭제합니다. 다음 행사 때 새로 만들고 SQL 을 다시 실행합니다.
  - **재사용**: Storage 의 사진을 지우고 `truncate public.team_slots;`, `truncate public.chat_messages;` 를 실행한 뒤 다음 행사에 그대로 씁니다. 이전 행사 페이지가 살아 있으면 같은 데이터를 보게 되므로 레포를 먼저 정리하세요.
- GitHub 레포를 삭제하거나 Private 으로 바꿉니다 (무료 플랜에서 Private 으로 바꾸면 Pages 가 내려가요). 공개 레포의 사진(`og.jpg`)을 거두는 가장 확실한 방법은 레포 삭제입니다.
