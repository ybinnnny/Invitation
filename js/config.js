// ─────────────────────────────────────────────────────────────
// 초대장 설정 — 이 파일만 고치면 내용이 바뀝니다.
// ─────────────────────────────────────────────────────────────
window.INVITE_CONFIG = {
  // Supabase: 대시보드 → Project Settings → API keys (Data API)
  //   url : Project URL (https://xxxx.supabase.co)
  //   key : publishable key(sb_publishable_...) 또는 legacy anon key
  // ⚠ service_role / secret key 는 절대 넣지 말 것 (DB 전체 권한)
  supabase: {
    url: "https://hceipxhhpgpdcysjjrak.supabase.co",
    key: "sb_publishable_av4GzP-9wgDEms5qkraVng_L7fvj-2q",
  },

  event: {
    title: "분당 8선녀\n2026 송년회", // \n 은 줄바꿈
    subtitle: "올 한 해도 수고했어, 우리",
    // 날짜·시간은 ISO 형식 (한국 시간 +09:00). end 를 비우면 "18:00 ~" 로 표시
    start: "2026-12-18T18:00:00+09:00",
    end: "",
    placeName: "파티앤스터디 분당정자점",
    address: "경기 성남시 분당구 정자일로 177",
    addressDetail: "상가 302호",
    directions: [],                       // (선택) 예: "신분당선 정자역 0번 출구 도보 0분"
    mapQuery: "파티앤스터디 분당정자점",   // 지도 앱 검색어
    // 네이버 지도 링크를 직접 지정하려면 입력 (비우면 mapQuery 로 검색)
    naverMapUrl: "",
  },

  // 일정 카드에 표시되는 준비물
  bring: {
    item: "2만 원 내외 경품 1개",
    note: "내용물이 보이지 않도록 쇼핑백이나 포장지로 가려주세요 🎁",
  },

  // 조 (조당 4명, 2개 조 — DB 정원과 맞춰야 하므로 개수·코드(A/B)는 바꾸지 말 것)
  teams: {
    A: { name: "장보기조", emoji: "🛒", role: "술 · 과자 · 물 · 음료" },
    B: { name: "포장배달조", emoji: "🛵", role: "회 포장 · 음식 배달" },
  },

  games: {
    telestrationsVideo: "https://www.youtube.com/watch?v=Puc_1XyP-30",
  },

  // GAME 3-1 워밍업 질문 (점수 없음, 한 문제씩 진행). [A, B, 한 줄 주제]
  // 문제 번호가 곧 순서이므로 행사 중에는 순서·개수를 바꾸지 말 것. (최대 100문제)
  balanceWarm: [
    ["평생 썸만 타기", "연애할 때마다 3개월 만에 헤어지기", "연애 난이도"],
    ["내 카톡 전체 공개", "내 인스타 DM 전체 공개", "사생활 난감 선택"],
    ["내 이상형이 나를 싫어하기", "내가 싫어하는 사람이 나를 너무 좋아하기", "최악의 상황"],
    ["평생 20대 외모", "평생 20대 체력", "인생 치트키"],
    ["친구가 내 이상형과 사귀기", "내가 친구의 이상형과 사귀기", "우정과 사랑"],
    ["평생 해외여행 무료", "평생 명품 무료", "소비 취향"],
    ["전 애인과 친구로 지내기", "전 애인과 완전히 남남 되기", "이별 이후"],
    ["나를 더 사랑하는 사람", "내가 더 사랑하는 사람", "연애의 균형"],
    ["매일 붙어 있기", "일주일에 한 번만 만나기", "연애 거리감"],
    ["내 흑역사 영상 공개", "내 검색 기록 공개", "공개 처형"],
  ],
};
