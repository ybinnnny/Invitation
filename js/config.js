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
    title: "분당 8선녀 2026 송년회",
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
};
