# 분당 8선녀 2026 송년회 모바일 초대장

정적 페이지(GitHub Pages) + Supabase(조 선택·수다공간 DB, 사진 저장소). 로그인 없이 링크로 접속.

> 만드는 순서, 무료 한도, 체크리스트 같은 공통 안내는 레포 밖 `초대장/README.md`(이 폴더 기준 `../../README.md`)에 있어요.

## 파일 구조

```
index.html          페이지 구조 + 게임 소개 팝업 + 카카오톡 공유용 메타 태그
css/style.css       디자인
js/config.js        ★ 행사 정보·Supabase 접속값 (여기만 고치면 됨)
js/app.js           조 선택·사진 업로드·수다공간·자동 갱신 로직
img/                게임 소개 팝업의 예시 이미지 (360px)
og.jpg              카카오톡 공유 썸네일 (1200×630)
supabase/schema.sql 조 선택 + 사진 SQL (Supabase SQL Editor 에서 먼저 실행)
supabase/chat.sql   수다공간(자유 게시판) SQL (schema.sql 다음에 실행)
```

## 고치는 곳

- 행사 정보(일시·장소·준비물·조 이름·게임 영상 링크): `js/config.js`
- 문구·드레스코드·프로그램·게임 소개: `index.html`
- 공유 썸네일: `og.jpg` (1200×630)
- Supabase 연결: 프로젝트를 만들고 `schema.sql` → `chat.sql` 순서로 실행한 뒤, Project URL(`https://xxxx.supabase.co` 까지만)과 **publishable key** 를 `js/config.js` 에 입력합니다. `secret`·`service_role` 키는 넣지 않습니다.

## 수정할 때 주의

`css`·`js` 를 고칠 때마다 `index.html` 의 `?v=` 값(`style.css`, `config.js`, `app.js` 세 곳)을 같이 올립니다. 브라우저가 예전 파일을 10분간 저장하기 때문에, 새 화면과 예전 JS 가 섞이면 기능이 안 되는 것처럼 보여요.

## 공개 레포 주의

이 레포는 Public 입니다. 소스와 `og.jpg`·`img/` 가 누구에게나 보여요. 행사가 끝나면 레포를 삭제하거나 Private 으로 바꾸세요.
