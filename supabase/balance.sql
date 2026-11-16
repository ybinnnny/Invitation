-- ═══════════════════════════════════════════════════════════════
-- GAME 3 밸런스 게임 — Supabase 스키마
-- schema.sql, chat.sql 과 같은 프로젝트의 SQL Editor 에서 이 파일 전체를 붙여넣고 Run
-- (여러 번 실행해도 안전. 진행 상태·투표는 지워지지 않는다)
--
-- 진행 방식
--   · 모두 폰으로 참가(이름 입력) → 진행자가 투표를 열면 각자 문제별로 A/B 선택
--   · 진행자가 투표를 마감한 뒤, 문제를 하나씩 '공개'한다.
--   · 공개 전에는 어떤 문제의 선택 비중도 서버가 내보내지 않는다. (남의 선택은 공개 후에도 숫자만)
--   · 내 선택이 더 많은 표를 받으면 1점 (동률이면 양쪽 모두 1점)
--
-- 보안 원칙
--   · 테이블은 anon 이 직접 읽거나 쓸 수 없다. 함수(RPC)로만 접근.
--   · 투표·참가는 참가할 때 받은 토큰(=그 폰)으로만. 진행 조작은 진행자 비밀번호(bg_admin)로만.
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.bg_admin (
  id  int  primary key default 1 check (id = 1),
  key text not null check (char_length(key) >= 6)
);

create table if not exists public.bg_state (
  id       int  primary key default 1 check (id = 1),
  status   text not null default 'ready' check (status in ('ready', 'open', 'closed')),
  revealed int  not null default 0 check (revealed between 0 and 100)
);
insert into public.bg_state (id) values (1) on conflict (id) do nothing;

create table if not exists public.bg_players (
  token      uuid        primary key default gen_random_uuid(),
  name       text        not null check (char_length(btrim(name)) between 1 and 20),
  created_at timestamptz not null default now()
);
create unique index if not exists bg_players_name_key on public.bg_players (lower(btrim(name)));

create table if not exists public.bg_votes (
  token  uuid not null references public.bg_players (token) on delete cascade,
  q      int  not null check (q between 1 and 100),
  choice text not null check (choice in ('A', 'B')),
  primary key (token, q)
);

alter table public.bg_admin   enable row level security;   -- 정책 없음 = anon 직접 접근 차단
alter table public.bg_state   enable row level security;
alter table public.bg_players enable row level security;
alter table public.bg_votes   enable row level security;
revoke all on public.bg_admin, public.bg_state, public.bg_players, public.bg_votes from anon, authenticated;


-- 참가: 이름 1~20자, 같은 이름 불가, 최대 60명
create or replace function public.bg_join(p_name text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name  text := btrim(coalesce(p_name, ''));
  v_token uuid;
begin
  if char_length(v_name) not between 1 and 20 then
    raise exception 'INVALID_NAME';
  end if;
  if (select count(*) from public.bg_players) >= 60 then
    raise exception 'GAME_FULL';
  end if;
  begin
    insert into public.bg_players (name) values (v_name) returning token into v_token;
  exception when unique_violation then
    raise exception 'NAME_TAKEN';
  end;
  return json_build_object('token', v_token, 'name', v_name);
end;
$$;


-- 투표: 투표가 열려 있을 때만. 열려 있는 동안은 바꿀 수 있다.
create or replace function public.bg_vote(p_token uuid, p_q int, p_choice text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select status from public.bg_state where id = 1) <> 'open' then
    raise exception 'NOT_OPEN';
  end if;
  if not exists (select 1 from public.bg_players where token = p_token) then
    raise exception 'NO_PLAYER';
  end if;
  if p_q is null or p_q not between 1 and 100 or p_choice not in ('A', 'B') then
    raise exception 'INVALID_VOTE';
  end if;
  insert into public.bg_votes (token, q, choice) values (p_token, p_q, p_choice)
  on conflict (token, q) do update set choice = excluded.choice;
  return true;
end;
$$;


-- 화면 전체 상태 (한 번에 조회)
--   results : 공개된 문제(q <= revealed)만 A/B 표 수
--   scores  : 공개된 문제까지의 점수 (동률이면 양쪽 모두 1점)
--   mine    : 내 선택 (내 토큰으로만)
create or replace function public.bg_overview(p_token uuid default null)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_status   text;
  v_revealed int;
  v_progress json;
  v_results  json;
  v_scores   json;
begin
  select status, revealed into v_status, v_revealed from public.bg_state where id = 1;

  select coalesce(json_object_agg(q, n), '{}'::json) into v_progress
  from (select q, count(*) as n from public.bg_votes group by q) t;

  select coalesce(json_object_agg(q, json_build_object('A', a, 'B', b)), '{}'::json) into v_results
  from (
    select q,
           count(*) filter (where choice = 'A') as a,
           count(*) filter (where choice = 'B') as b
    from public.bg_votes
    where q <= v_revealed
    group by q
  ) t;

  select coalesce(json_agg(json_build_object('name', name, 'score', score) order by score desc, name), '[]'::json)
  into v_scores
  from (
    select p.name,
           count(v.q) filter (where (v.choice = 'A' and r.a >= r.b) or (v.choice = 'B' and r.b >= r.a)) as score
    from public.bg_players p
    left join public.bg_votes v on v.token = p.token and v.q <= v_revealed
    left join (
      select q,
             count(*) filter (where choice = 'A') as a,
             count(*) filter (where choice = 'B') as b
      from public.bg_votes
      where q <= v_revealed
      group by q
    ) r on r.q = v.q
    group by p.token, p.name
  ) s;

  return json_build_object(
    'status',   v_status,
    'revealed', v_revealed,
    'players',  (select count(*) from public.bg_players),
    'progress', v_progress,
    'results',  v_results,
    'scores',   v_scores,
    'me',       (select name from public.bg_players where token = p_token),
    'mine',     (select coalesce(json_object_agg(q, choice), '{}'::json) from public.bg_votes where token = p_token)
  );
end;
$$;


-- 진행자: 상태 바꾸기. p_status = ready|open|closed, p_revealed = 공개한 문제 수 (비우면 그대로)
create or replace function public.bg_admin_set(p_key text, p_status text default null, p_revealed int default null)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  select key into v_key from public.bg_admin where id = 1;
  if v_key is null then
    raise exception 'ADMIN_NOT_SET';
  end if;
  if p_key is distinct from v_key then
    raise exception 'BAD_KEY';
  end if;
  if p_status is not null and p_status not in ('ready', 'open', 'closed') then
    raise exception 'INVALID_STATUS';
  end if;
  update public.bg_state
     set status   = coalesce(p_status, status),
         revealed = least(greatest(coalesce(p_revealed, revealed), 0), 100)
   where id = 1;
  return public.bg_overview(null);
end;
$$;


-- 진행자: 참가자·투표 전부 지우고 처음 상태로 (리허설 후 초기화용)
create or replace function public.bg_admin_reset(p_key text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  select key into v_key from public.bg_admin where id = 1;
  if v_key is null then
    raise exception 'ADMIN_NOT_SET';
  end if;
  if p_key is distinct from v_key then
    raise exception 'BAD_KEY';
  end if;
  delete from public.bg_votes   where true;
  delete from public.bg_players where true;
  update public.bg_state set status = 'ready', revealed = 0 where id = 1;
  return true;
end;
$$;

revoke all on function public.bg_join(text)                  from public;
revoke all on function public.bg_vote(uuid, int, text)       from public;
revoke all on function public.bg_overview(uuid)              from public;
revoke all on function public.bg_admin_set(text, text, int)  from public;
revoke all on function public.bg_admin_reset(text)           from public;
grant execute on function public.bg_join(text)                 to anon, authenticated;
grant execute on function public.bg_vote(uuid, int, text)      to anon, authenticated;
grant execute on function public.bg_overview(uuid)             to anon, authenticated;
grant execute on function public.bg_admin_set(text, text, int) to anon, authenticated;
grant execute on function public.bg_admin_reset(text)          to anon, authenticated;


-- ── 진행자 비밀번호 (이 파일에 쓰지 말고, SQL Editor 에서 아래 한 줄만 따로 실행) ──
-- ⚠ 6자 이상. 이 레포는 공개이므로 비밀번호를 파일·채팅에 남기지 말 것.
-- insert into public.bg_admin (id, key) values (1, '여기에_진행자_비밀번호') on conflict (id) do update set key = excluded.key;

-- ── 관리자용 (필요할 때 SQL Editor 에서 직접 실행) ─────────────
-- 상태 보기   : select * from public.bg_state;
-- 참가자 보기 : select name, created_at from public.bg_players order by created_at;
-- 전체 초기화 : update public.bg_state set status = 'ready', revealed = 0; truncate public.bg_votes; delete from public.bg_players where true;
