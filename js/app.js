(() => {
  "use strict";

  const CFG = window.INVITE_CONFIG;
  const EV = CFG.event;
  const $ = (id) => document.getElementById(id);
  const MAX_BYTES = 5 * 1024 * 1024;   // 서버(버킷)에서도 같은 값으로 강제
  const RESIZE_EDGE = 1920;             // 업로드 전 긴 변 최대 px
  const BUCKET = "photos";
  const FOLDER = "uploads";

  // ── localStorage (실패해도 동작하도록) ─────────────────────────
  const store = {
    get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch { return null; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch { /* 무시 */ } },
    del(k) { try { localStorage.removeItem(k); } catch { /* 무시 */ } },
  };

  let toastTimer;
  function toast(msg) {
    const t = $("toast");
    t.textContent = msg;
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { t.hidden = true; }, 2600);
  }

  function el(tag, props = {}, ...children) {
    const n = document.createElement(tag);
    Object.assign(n, props);
    for (const c of children) if (c != null) n.append(c);
    return n;
  }

  // ── 정적 정보 ────────────────────────────────────────────────
  function renderStatic() {
    const start = new Date(EV.start);
    const dateFmt = new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", year: "numeric", month: "long", day: "numeric", weekday: "short" });
    const timeFmt = new Intl.DateTimeFormat("ko-KR", { timeZone: "Asia/Seoul", hour: "numeric", minute: "2-digit" });

    $("ev-title").textContent = EV.title;
    $("ev-subtitle").textContent = EV.subtitle || "";
    $("ev-date").textContent = dateFmt.format(start);
    $("ev-time").textContent = EV.end
      ? `${timeFmt.format(start)} ~ ${timeFmt.format(new Date(EV.end))}`
      : `${timeFmt.format(start)} ~`;
    $("ev-place").textContent = EV.placeName;
    $("ev-place2").textContent = EV.placeName;
    $("ev-address").textContent = EV.address;
    $("ev-address-detail").textContent = EV.addressDetail || "";

    // D-day (한국 날짜 기준)
    const ymd = (d) => new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Seoul" }).format(d);
    const days = Math.round((Date.parse(ymd(start)) - Date.parse(ymd(new Date()))) / 86400000);
    $("ev-dday").textContent = days > 0 ? `D-${days}` : days === 0 ? "D-DAY 🎉" : "즐거웠어요, 고마워요 💛";

    const q = encodeURIComponent(EV.mapQuery || EV.address || EV.placeName);
    $("map-naver").href = EV.naverMapUrl || `https://map.naver.com/p/search/${q}`;
    $("copy-addr").addEventListener("click", async () => {
      const text = `${EV.address} ${EV.addressDetail || ""}`.trim();
      try { await navigator.clipboard.writeText(text); toast("주소를 복사했어요"); }
      catch { window.prompt("주소를 길게 눌러 복사하세요", text); }
    });
    // 공유하기: 이 초대장의 링크(쿼리·해시 제외)를 복사
    $("share-btn").addEventListener("click", async () => {
      const url = location.origin + location.pathname;
      try { await navigator.clipboard.writeText(url); toast("링크를 복사했어요. 단톡방에 붙여넣기 하세요"); }
      catch { window.prompt("링크를 길게 눌러 복사하세요", url); }
    });
    $("ev-directions").replaceChildren(...(EV.directions || []).map((d) => el("li", { textContent: d })));

    // 준비물 (일정 카드 안)
    $("bring-item").textContent = CFG.bring.item;
    $("bring-note").textContent = CFG.bring.note || "";

    $("video-telestrations").href = CFG.games.telestrationsVideo;
  }

  // ── 팝업 ─────────────────────────────────────────────────────
  function setupModals() {
    let lastFocus = null;
    const open = (m) => { lastFocus = document.activeElement; m.hidden = false; document.body.style.overflow = "hidden"; m.querySelector(".modal-x")?.focus(); };
    const close = (m) => { m.hidden = true; document.body.style.overflow = ""; lastFocus?.focus?.(); };

    document.querySelectorAll("[data-open]").forEach((b) =>
      b.addEventListener("click", () => open($(b.dataset.open))));
    document.querySelectorAll(".modal").forEach((m) =>
      m.querySelectorAll("[data-close]").forEach((b) => b.addEventListener("click", () => close(m))));

    const lb = $("lightbox");
    lb.addEventListener("click", () => close(lb));
    document.addEventListener("keydown", (e) => {
      if (e.key !== "Escape") return;
      document.querySelectorAll(".modal:not([hidden]), .lightbox:not([hidden])").forEach(close);
    });
    window.openLightbox = (src) => { lb.querySelector("img").src = src; open(lb); };
  }

  // ── Supabase ─────────────────────────────────────────────────
  const configured = !!(CFG.supabase.url && CFG.supabase.key && window.supabase);
  const sb = configured ? window.supabase.createClient(CFG.supabase.url, CFG.supabase.key, {
    auth: { persistSession: false, autoRefreshToken: false },
  }) : null;

  function showNotConfigured() {
    for (const k of ["teams", "photos"]) {
      const n = $(`${k}-notice`);
      n.textContent = window.supabase
        ? "아직 서버 설정 전이에요. (js/config.js 의 supabase url·key 를 입력하세요)"
        : "서버 라이브러리를 불러오지 못했어요. 네트워크를 확인하고 새로고침해 주세요.";
      n.hidden = false;
      $(`${k}-body`).querySelectorAll("button, input").forEach((x) => { x.disabled = true; });
    }
  }

  // ── 조 선택 ──────────────────────────────────────────────────
  const ERR = {
    TEAM_FULL: "앗, 방금 그 조가 마감됐어요. 다른 조를 골라주세요!",
    NAME_TAKEN: "이미 같은 이름으로 자리가 있어요. 다른 이름(예: 성까지)으로 입력해 주세요.",
    INVALID_NAME: "이름을 1~20자로 입력해 주세요.",
    INVALID_TEAM: "알 수 없는 조예요.",
  };
  const errMsg = (e) => {
    const m = String(e?.message || e || "");
    const key = Object.keys(ERR).find((k) => m.includes(k));
    return key ? ERR[key] : "연결이 불안정해요. 잠시 후 다시 시도해 주세요.";
  };

  let slots = [];
  let busy = false;
  const mySeat = () => store.get("my-seat"); // { team, seat, name, token }

  async function loadSlots() {
    const { data, error } = await sb.rpc("list_slots");
    if (error) throw error;
    slots = data || [];
    // 내 자리가 DB에서 사라졌으면(관리자 초기화 등) 로컬 기록도 정리
    const mine = mySeat();
    if (mine && !slots.some((s) => s.team === mine.team && s.seat === mine.seat && s.name === mine.name)) {
      store.del("my-seat");
    }
    renderTeams();
  }

  function renderTeams() {
    const mine = mySeat();
    const box = $("my-seat");
    if (mine) {
      const t = CFG.teams[mine.team];
      const cancel = el("button", { className: "btn", type: "button", textContent: "자리 취소" });
      cancel.addEventListener("click", leaveTeam);
      box.replaceChildren(el("span", {}, "✅ ", el("b", { textContent: mine.name }), ` 님은 ${t.emoji} ${t.name} ${mine.seat}번 자리예요`), cancel);
      box.hidden = false;
      $("name-field").hidden = true;
    } else {
      box.hidden = true;
      $("name-field").hidden = false;
    }

    $("team-grid").replaceChildren(...Object.entries(CFG.teams).map(([code, t]) => {
      const taken = slots.filter((s) => s.team === code);
      const full = taken.length >= 4;
      const seats = [1, 2, 3, 4].map((n) => {
        const s = taken.find((x) => x.seat === n);
        const isMe = s && mine && mine.team === code && mine.seat === n;
        return el("li", { className: s ? (isMe ? "me" : "") : "empty", textContent: s ? `${n}. ${s.name}` : `${n}. 빈 자리` });
      });
      const btn = el("button", {
        className: "btn primary", type: "button",
        textContent: full ? "마감" : mine ? (mine.team === code ? "내 조" : "참가 중") : "이 조로 참가",
        disabled: full || !!mine || busy,
      });
      btn.addEventListener("click", () => joinTeam(code));
      return el("div", { className: `team ${code.toLowerCase()}` },
        el("div", { className: "team-head" }, `${t.emoji} ${t.name}`, el("span", { className: "count", textContent: `${taken.length}/4` })),
        t.role ? el("p", { className: "team-role", textContent: t.role }) : null,
        el("ul", { className: "seats" }, ...seats),
        btn);
    }));
  }

  async function joinTeam(code) {
    const name = $("my-name").value.trim();
    if (!name) { toast("이름을 먼저 입력해 주세요"); $("my-name").focus(); return; }
    if (busy) return;
    busy = true; renderTeams();
    try {
      const { data, error } = await sb.rpc("join_team", { p_team: code, p_name: name });
      if (error) throw error;
      store.set("my-name", name);
      store.set("my-seat", { team: data.team, seat: data.seat, name, token: data.token });
      toast(`${CFG.teams[code].name} 참가 완료! 🎉`);
    } catch (e) {
      toast(errMsg(e));
    } finally {
      busy = false;
      await loadSlots().catch(() => renderTeams());
    }
  }

  async function leaveTeam() {
    const mine = mySeat();
    if (!mine || busy) return;
    if (!window.confirm("내 자리를 취소할까요? 다른 사람이 바로 가져갈 수 있어요.")) return;
    busy = true;
    try {
      const { error } = await sb.rpc("leave_team", { p_token: mine.token });
      if (error) throw error;
      store.del("my-seat");
      toast("자리를 취소했어요");
    } catch (e) {
      toast(errMsg(e));
    } finally {
      busy = false;
      await loadSlots().catch(() => renderTeams());
    }
  }

  // ── 사진 ─────────────────────────────────────────────────────
  // 큰 사진은 긴 변 1920px JPEG 로 줄여서 올림 (용량·데이터 절약). GIF 는 그대로.
  async function shrink(file) {
    if (file.type === "image/gif") return file;
    try {
      const bmp = await createImageBitmap(file, { imageOrientation: "from-image" });
      const scale = Math.min(1, RESIZE_EDGE / Math.max(bmp.width, bmp.height));
      if (scale === 1 && file.size <= 1.5 * 1024 * 1024 && file.type === "image/jpeg") return file;
      const c = document.createElement("canvas");
      c.width = Math.round(bmp.width * scale);
      c.height = Math.round(bmp.height * scale);
      c.getContext("2d").drawImage(bmp, 0, 0, c.width, c.height);
      const blob = await new Promise((r) => c.toBlob(r, "image/jpeg", 0.85));
      return blob && blob.size < file.size ? blob : file;
    } catch {
      return file; // 브라우저가 디코딩 못하는 형식(일부 HEIC 등)은 원본 그대로 시도
    }
  }

  const extOf = (type) => ({ "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif", "image/heic": "heic", "image/heif": "heif" }[type] || "img");

  async function uploadFiles(files) {
    const list = [...files];
    let ok = 0;
    const status = $("upload-status");
    for (let i = 0; i < list.length; i++) {
      const f = list[i];
      status.textContent = `올리는 중… (${i + 1}/${list.length})`;
      if (!f.type.startsWith("image/")) { toast(`${f.name}: 이미지 파일만 올릴 수 있어요`); continue; }
      const blob = await shrink(f);
      if (blob.size > MAX_BYTES) { toast(`${f.name}: 5MB를 넘어서 올릴 수 없어요`); continue; }
      const type = blob.type || f.type;
      const path = `${FOLDER}/${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${extOf(type)}`;
      const { error } = await sb.storage.from(BUCKET).upload(path, blob, { contentType: type, upsert: false, cacheControl: "31536000" });
      if (error) {
        const m = String(error.message || "");
        toast(/size|large/i.test(m) ? "5MB를 넘는 파일은 올릴 수 없어요"
          : /mime|type/i.test(m) ? "지원하지 않는 이미지 형식이에요 (JPG·PNG 권장)"
          : /policy|security|row-level/i.test(m) ? "사진 보관함이 가득 찼어요. 주최자에게 알려주세요"
          : "업로드에 실패했어요. 잠시 후 다시 시도해 주세요");
        continue;
      }
      ok++;
    }
    status.textContent = ok ? `사진 ${ok}장을 올렸어요 💛` : "";
    await loadGallery();
  }

  async function loadGallery() {
    const { data, error } = await sb.storage.from(BUCKET).list(FOLDER, { limit: 300, sortBy: { column: "created_at", order: "desc" } });
    if (error) { $("upload-status").textContent = "사진 목록을 불러오지 못했어요."; return; }
    const files = (data || []).filter((f) => f.id && f.name !== ".emptyFolderPlaceholder");
    $("gallery-empty").hidden = files.length > 0;
    $("gallery").replaceChildren(...files.map((f) => {
      const { data: { publicUrl } } = sb.storage.from(BUCKET).getPublicUrl(`${FOLDER}/${f.name}`);
      const b = el("button", { type: "button", ariaLabel: "사진 크게 보기" },
        el("img", { src: publicUrl, alt: "", loading: "lazy", decoding: "async" }));
      b.addEventListener("click", () => window.openLightbox(publicUrl));
      return b;
    }));
  }

  // ── 시작 ─────────────────────────────────────────────────────
  renderStatic();
  setupModals();
  $("my-name").value = store.get("my-name") || "";

  if (!configured) { showNotConfigured(); renderTeamsPreview(); return; }

  $("photo-input").addEventListener("change", async (e) => {
    const input = e.target;
    if (!input.files.length) return;
    input.disabled = true;
    try { await uploadFiles(input.files); } finally { input.value = ""; input.disabled = false; }
  });

  loadSlots().catch(() => { $("teams-notice").textContent = "조 현황을 불러오지 못했어요. 새로고침해 주세요."; $("teams-notice").hidden = false; renderTeams(); });
  loadGallery();

  // 다른 사람의 선택을 반영하기 위해 화면이 보일 때 15초마다 새로고침
  setInterval(() => { if (!document.hidden && !busy) loadSlots().catch(() => {}); }, 15000);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) { loadSlots().catch(() => {}); loadGallery(); }
  });

  // 설정 전에도 조 화면 모양은 보이도록
  function renderTeamsPreview() {
    renderTeams();
    $("team-grid").querySelectorAll("button").forEach((b) => { b.disabled = true; });
  }
})();
