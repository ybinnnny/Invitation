# 분당 8선녀 송년회 모바일 초대장

정적 페이지(GitHub Pages) + Supabase(조 선택 DB, 사진 저장소). 로그인 없이 링크로 접속.

```
index.html          페이지 구조 + 게임 안내 팝업
css/style.css       디자인
js/config.js        ★ 행사 정보·Supabase 접속값 (여기만 고치면 됨)
js/app.js           조 선택·사진 업로드 로직
supabase/schema.sql Supabase 에 한 번 실행할 SQL
```

## 1. Supabase 준비 (약 10분)

1. https://supabase.com 에 개인 계정으로 가입하고 **New project** 를 만듭니다. Region 은 `Northeast Asia (Seoul)` 를 고르고, DB 비밀번호는 아무 데도 적지 마세요.
2. **SQL Editor** 에 `supabase/schema.sql` 전체를 붙여넣고 **Run** 합니다.
   - 확인: Table Editor 에 `team_slots`, Storage 에 `photos` 버킷(Public, 5MB)이 보이면 성공이에요.
3. **Project Settings → API keys**(또는 Data API)에서 다음 두 값을 `js/config.js` 의 `supabase` 에 넣습니다.
   - `url`: Project URL (`https://xxxx.supabase.co`)
   - `key`: **publishable key**(`sb_publishable_…`) 또는 legacy **anon** key
   - ⚠ `service_role` / `secret` 키는 절대 넣지 마세요. 넣으면 DB 전체 권한이 공개됩니다.
4. 행사 정보(일시, 장소, 준비물, 조 이름, 게임 영상 링크)는 `js/config.js` 에 있어요. 바뀌면 그 파일만 고치면 됩니다. 초대 문구, 드레스코드, 프로그램 설명은 `index.html` 에 있어요.

## 2. GitHub Pages 배포 (github.com)

> 사내 `oss.navercorp.com` 은 외부 폰에서 접속할 수 없으므로 개인 **github.com** 계정을 사용합니다.
> 무료 플랜은 **공개 레포**여야 하므로 소스가 공개됩니다. 실명, 연락처, 상세 주소를 넣을지 판단해 주세요.

1. github.com 에서 새 **Public** 레포를 만듭니다. 이름은 추측하기 어렵게 짓는 걸 권장해요 (예: `ys-2026-party-x7k`).
2. 이 폴더에서 아래를 실행합니다. 공개 레포라 커밋 이메일이 노출되므로 회사 메일 대신 GitHub noreply 메일을 쓰세요.
   ```bash
   git init -b main
   git config user.email "<ID>+<username>@users.noreply.github.com"
   git add index.html css js supabase README.md
   git commit -m "송년회 초대장"
   git remote add origin https://github.com/<username>/<repo>.git
   git push -u origin main
   ```
3. 레포의 **Settings → Pages → Build and deployment** 에서 Source 를 `Deploy from a branch`, `main` / `/ (root)` 로 지정합니다.
4. 1~2분 뒤 `https://<username>.github.io/<repo>/` 로 접속해 확인합니다.

## 3. 링크 공유 전 체크리스트

- [ ] 폰(LTE, 사내 와이파이 아님)으로 접속 → 일정·지도 버튼·게임 팝업 확인
- [ ] 조 선택 테스트 → 참가 → 취소. 끝나면 SQL Editor 에서 `truncate public.team_slots;`
- [ ] 사진 1장 업로드 테스트 → Storage 에서 삭제
- [ ] **Supabase 무료 프로젝트는 1주일간 요청이 없으면 일시정지돼요.** 링크 공유 직전과 행사 당일 아침에 대시보드에서 상태를 확인하고, Paused 면 Restore 하세요.

## 4. 동작 방식 / 보안 메모

| 기능 | 방식 |
|---|---|
| 정원 초과 방지 | `join_team()` 이 전역 잠금(advisory lock)으로 요청을 하나씩 처리하고, PK(조, 좌석) + 좌석 1~4 제약이 최종 방어선 역할을 함 |
| 본인만 취소 | 참가 시 받은 토큰을 그 폰의 localStorage 에 저장하고, `leave_team(token)` 으로만 삭제 가능. 폰이나 브라우저를 바꾸면 취소할 수 없으니 관리자가 SQL 로 처리 |
| 이름 중복 | 같은 이름(대소문자·앞뒤 공백 무시)은 한 자리만 가능 |
| 사진 | 브라우저에서 긴 변 1920px JPEG 로 줄여 업로드. 버킷이 5MB 와 이미지 형식을 서버에서 강제 |
| 사진 권한 | 익명 사용자는 목록 보기와 `uploads/` 업로드만 가능(총 300장). 수정·삭제 불가 |
| 노출되는 키 | publishable(anon) key 만 노출되며, 위 함수와 정책 범위 밖으로는 쓸 수 없음 |

**한계**: 로그인이 없어서 링크를 아는 사람은 누구나 조를 고르고 사진을 올릴 수 있어요. 남의 이름으로 자리를 잡는 장난을 막는 장치는 없으니, 생기면 관리자가 SQL 로 정리하세요.

## 5. 행사 후 정리

- Storage → photos 에서 사진을 내려받은 뒤 삭제하거나, Supabase 프로젝트를 삭제
- GitHub 레포를 Private 으로 바꾸거나 삭제 (무료 플랜에서 Private 으로 바꾸면 Pages 가 내려가요)
