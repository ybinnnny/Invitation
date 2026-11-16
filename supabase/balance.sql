-- ═══════════════════════════════════════════════════════════════
-- GAME 3 밸런스 게임 — Supabase 스키마 (v3: 3-1 워밍업 + 3-2 황금밸런스)
-- schema.sql, chat.sql 과 같은 프로젝트의 SQL Editor 에서 이 파일 전체를 붙여넣고 Run
-- (여러 번 실행해도 안전. 이전 버전(다수파 1점) 위에 그대로 실행 가능)
--
-- 진행 방식 (참가 8명 고정)
--   · 3-1 워밍업(warm): 고정 질문(config.js)을 한 문제씩, 점수 없음, 투표 비율은 바로 공개.
--   · 3-2 진행: 대기(ready) → 질문 제출(submit) → 투표(open) → 마감(closed) → 한 문제씩 공개
--   · 각자 현장에서 질문(주제 + A/B) 1개를 낸다. 진행자가 '질문 제출'을 열기 전에는 낼 수 없다.
--   · 모두(출제자 포함) 모든 문제에 투표한다. 투표자는 점수가 없다.
--   · 출제자 점수: 8표가 4:4 → 2점, 3:5 → 1점, 그 외 0점. (표 차이 0~1 → 2점, 2 → 1점)
--   · 출제자는 공개되기 전까지 서버가 내보내지 않는다. 선택 비중도 공개 전에는 내보내지 않는다.
--
-- 보안 원칙
--   · 테이블은 anon 이 직접 읽거나 쓸 수 없다. 함수(RPC)로만 접근.
--   · 질문·투표·참가는 참가할 때 받은 토큰(=그 폰)으로만. 진행 조작은 진행자 비밀번호(bg_admin)로만.
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.bg_admin (
  id  int  primary key default 1 check (id = 1),
  key text not null check (char_length(key) >= 6)
);

create table if not exists public.bg_state (
  id       int  primary key default 1 check (id = 1),
  status   text not null default 'ready',
  revealed int  not null default 0 check (revealed between 0 and 100)
);
alter table public.bg_state add column if not exists warm_q int not null default 0 check (warm_q between 0 and 100);
-- 상태에 'submit' 추가 (이전 버전 테이블 대응)
alter table public.bg_state drop constraint if exists bg_state_status_check;
alter table public.bg_state add constraint bg_state_status_check
  check (status in ('ready', 'warm', 'submit', 'open', 'closed'));
insert into public.bg_state (id) values (1) on conflict (id) do nothing;

create table if not exists public.bg_players (
  token      uuid        primary key default gen_random_uuid(),
  name       text        not null check (char_length(btrim(name)) between 1 and 20),
  created_at timestamptz not null default now()
);
create unique index if not exists bg_players_name_key on public.bg_players (lower(btrim(name)));

-- 출제 질문: 한 사람당 1개. q 는 투표가 열릴 때 무작위 순서로 붙는다.
create table if not exists public.bg_questions (
  token      uuid        primary key references public.bg_players (token) on delete cascade,
  title      text        not null check (char_length(btrim(title)) between 1 and 40),
  a          text        not null check (char_length(btrim(a)) between 1 and 30),
  b          text        not null check (char_length(btrim(b)) between 1 and 30),
  q          int         unique check (q between 1 and 100),
  created_at timestamptz not null default now()
);

create table if not exists public.bg_votes (
  token  uuid not null references public.bg_players (token) on delete cascade,
  q      int  not null check (q between 1 and 100),
  choice text not null check (choice in ('A', 'B')),
  primary key (token, q)
);

-- 3-1 워밍업 투표 (점수 없음)
create table if not exists public.bg_warm_votes (
  token  uuid not null references public.bg_players (token) on delete cascade,
  q      int  not null check (q between 1 and 100),
  choice text not null check (choice in ('A', 'B')),
  primary key (token, q)
);

alter table public.bg_warm_votes enable row level security;
revoke all on public.bg_warm_votes from anon, authenticated;

alter table public.bg_admin     enable row level security;   -- 정책 없음 = anon 직접 접근 차단
alter table public.bg_state     enable row level security;
alter table public.bg_players   enable row level security;
alter table public.bg_questions enable row level security;
alter table public.bg_votes     enable row level security;
revoke all on public.bg_admin, public.bg_state, public.bg_players, public.bg_questions, public.bg_votes from anon, authenticated;


-- 참가: 이름 1~20자, 같은 이름 불가, 최대 8명
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
  if (select count(*) from public.bg_players) >= 8 then
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


-- 질문 내기: 진행자가 '질문 제출'을 연 동안만. 그 동안은 고칠 수 있다.
create or replace function public.bg_submit(p_token uuid, p_title text, p_a text, p_b text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_title text := btrim(coalesce(p_title, ''));
  v_a     text := btrim(coalesce(p_a, ''));
  v_b     text := btrim(coalesce(p_b, ''));
begin
  if (select status from public.bg_state where id = 1) <> 'submit' then
    raise exception 'NOT_SUBMIT';
  end if;
  if not exists (select 1 from public.bg_players where token = p_token) then
    raise exception 'NO_PLAYER';
  end if;
  if char_length(v_title) not between 1 and 40
     or char_length(v_a) not between 1 and 30
     or char_length(v_b) not between 1 and 30 then
    raise exception 'INVALID_QUESTION';
  end if;
  insert into public.bg_questions (token, title, a, b) values (p_token, v_title, v_a, v_b)
  on conflict (token) do update set title = excluded.title, a = excluded.a, b = excluded.b;
  return true;
end;
$$;


-- 3-1 워밍업 질문 목록 (관리자가 화면에서 수정). 비어 있으면 화면(config.js)의 기본 질문을 쓴다.
create table if not exists public.bg_warm_questions (
  q     int  primary key check (q between 1 and 100),
  a     text not null check (char_length(btrim(a)) between 1 and 60),
  b     text not null check (char_length(btrim(b)) between 1 and 60),
  topic text not null default '' check (char_length(topic) <= 40)
);
alter table public.bg_warm_questions enable row level security;
revoke all on public.bg_warm_questions from anon, authenticated;

-- 워밍업 투표: 워밍업 중에 지금 보이는 문제에만. 바꿀 수 있다.
create or replace function public.bg_warm_vote(p_token uuid, p_q int, p_choice text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select status from public.bg_state where id = 1) <> 'warm' then
    raise exception 'NOT_WARM';
  end if;
  if p_q is distinct from (select warm_q from public.bg_state where id = 1) then
    raise exception 'NOT_WARM';
  end if;
  if not exists (select 1 from public.bg_players where token = p_token) then
    raise exception 'NO_PLAYER';
  end if;
  if p_choice not in ('A', 'B') then
    raise exception 'INVALID_VOTE';
  end if;
  insert into public.bg_warm_votes (token, q, choice) values (p_token, p_q, p_choice)
  on conflict (token, q) do update set choice = excluded.choice;
  return true;
end;
$$;


-- 투표: 투표가 열려 있을 때만, 존재하는 문제에만. 열려 있는 동안은 바꿀 수 있다.
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
  if p_choice not in ('A', 'B') or not exists (select 1 from public.bg_questions where q = p_q) then
    raise exception 'INVALID_VOTE';
  end if;
  insert into public.bg_votes (token, q, choice) values (p_token, p_q, p_choice)
  on conflict (token, q) do update set choice = excluded.choice;
  return true;
end;
$$;


-- 화면 전체 상태 (한 번에 조회)
--   questions : 투표·마감 단계에서만, 출제자 없이 (q, 주제, A, B)
--   results   : 공개된 문제(q <= revealed)만 A/B 표 수
--   authors   : 공개된 문제만 출제자 이름
--   scores    : 공개된 문제까지의 출제 점수 (표 차이 0~1 → 2점, 2 → 1점)
--   mine/myq  : 내 선택 / 내가 낸 질문 (내 토큰으로만)
create or replace function public.bg_overview(p_token uuid default null)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_status    text;
  v_revealed  int;
  v_questions json := '[]'::json;
  v_progress  json;
  v_results   json;
  v_authors   json;
  v_scores    json;
  v_myq       json;
  v_warm_q    int;
  v_warm      json := '{"A":0,"B":0}'::json;
  v_warm_n    int;
  v_warm_cur  json;
begin
  select status, revealed, warm_q into v_status, v_revealed, v_warm_q from public.bg_state where id = 1;

  select count(*) into v_warm_n from public.bg_warm_questions;
  if v_status = 'warm' and v_warm_q > 0 then
    select json_build_object('a', a, 'b', b, 'topic', topic) into v_warm_cur
    from public.bg_warm_questions where q = v_warm_q;
  end if;

  if v_status = 'warm' and v_warm_q > 0 then
    select json_build_object('A', count(*) filter (where choice = 'A'), 'B', count(*) filter (where choice = 'B'))
    into v_warm from public.bg_warm_votes where q = v_warm_q;
  end if;

  if v_status in ('open', 'closed') then
    select coalesce(json_agg(json_build_object('q', q, 'title', title, 'a', a, 'b', b) order by q), '[]'::json)
    into v_questions
    from public.bg_questions where q is not null;
  end if;

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

  select coalesce(json_object_agg(qs.q, p.name), '{}'::json) into v_authors
  from public.bg_questions qs join public.bg_players p on p.token = qs.token
  where qs.q is not null and qs.q <= v_revealed;

  select coalesce(json_agg(json_build_object('name', name, 'score', score) order by score desc, name), '[]'::json)
  into v_scores
  from (
    select p.name,
           coalesce(sum(case
             when r.q is null then 0
             when abs(r.a - r.b) <= 1 then 2
             when abs(r.a - r.b) = 2 then 1
             else 0 end), 0) as score
    from public.bg_players p
    left join public.bg_questions qs on qs.token = p.token and qs.q is not null and qs.q <= v_revealed
    left join (
      select q,
             count(*) filter (where choice = 'A') as a,
             count(*) filter (where choice = 'B') as b
      from public.bg_votes
      where q <= v_revealed
      group by q
    ) r on r.q = qs.q
    group by p.token, p.name
  ) s;

  select json_build_object('q', q, 'title', title, 'a', a, 'b', b) into v_myq
  from public.bg_questions where token = p_token;

  return json_build_object(
    'status',    v_status,
    'revealed',  v_revealed,
    'warm_q',    v_warm_q,
    'warm_n',    v_warm_n,
    'warm_cur',  v_warm_cur,
    'warm',      v_warm,
    'warm_mine', (select choice from public.bg_warm_votes where token = p_token and q = v_warm_q),
    'players',   (select count(*) from public.bg_players),
    'submitted', (select count(*) from public.bg_questions),
    'questions', v_questions,
    'progress',  v_progress,
    'results',   v_results,
    'authors',   v_authors,
    'scores',    v_scores,
    'me',        (select name from public.bg_players where token = p_token),
    'myq',       v_myq,
    'mine',      (select coalesce(json_object_agg(q, choice), '{}'::json) from public.bg_votes where token = p_token)
  );
end;
$$;


-- 관리자: 상태 바꾸기. p_status = ready|warm|submit|open|closed, p_revealed = 공개한 문제 수, p_warm_q = 워밍업 문제 번호 (비우면 그대로)
--   open 으로 바뀔 때 질문에 무작위 순서로 번호(q)를 붙인다.
drop function if exists public.bg_admin_set(text, text, int);
create or replace function public.bg_admin_set(p_key text, p_status text default null, p_revealed int default null, p_warm_q int default null)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key  text;
  v_prev text;
begin
  select key into v_key from public.bg_admin where id = 1;
  if v_key is null then
    raise exception 'ADMIN_NOT_SET';
  end if;
  if p_key is distinct from v_key then
    raise exception 'BAD_KEY';
  end if;
  if p_status is not null and p_status not in ('ready', 'warm', 'submit', 'open', 'closed') then
    raise exception 'INVALID_STATUS';
  end if;

  select status into v_prev from public.bg_state where id = 1;

  if p_status = 'open' and v_prev <> 'open' then
    if (select count(*) from public.bg_questions) = 0 then
      raise exception 'NO_QUESTIONS';
    end if;
    if not exists (select 1 from public.bg_votes) then
      update public.bg_questions set q = null where true;   -- 투표 전이면 처음부터 다시 섞음
    end if;
    update public.bg_questions bq
       set q = o.rn + (select coalesce(max(q), 0) from public.bg_questions)
      from (select token, row_number() over (order by random()) as rn
              from public.bg_questions where q is null) o
     where bq.token = o.token;
  end if;

  update public.bg_state
     set status   = coalesce(p_status, status),
         revealed = least(greatest(coalesce(p_revealed, revealed), 0), 100),
         warm_q   = least(greatest(coalesce(p_warm_q, warm_q), 0), 100)
   where id = 1;
  return public.bg_overview(null);
end;
$$;


-- 관리자: 워밍업 질문 목록 보기 / 저장(전체 교체). [{"a":..,"b":..,"topic":..}, ...] 최대 100개
create or replace function public.bg_admin_warm_list(p_key text)
returns json
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  select key into v_key from public.bg_admin where id = 1;
  if v_key is null then raise exception 'ADMIN_NOT_SET'; end if;
  if p_key is distinct from v_key then raise exception 'BAD_KEY'; end if;
  return (select coalesce(json_agg(json_build_object('a', a, 'b', b, 'topic', topic) order by q), '[]'::json)
          from public.bg_warm_questions);
end;
$$;

create or replace function public.bg_admin_warm_save(p_key text, p_list json)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
begin
  select key into v_key from public.bg_admin where id = 1;
  if v_key is null then raise exception 'ADMIN_NOT_SET'; end if;
  if p_key is distinct from v_key then raise exception 'BAD_KEY'; end if;
  if p_list is null or json_typeof(p_list) <> 'array' or json_array_length(p_list) not between 1 and 100 then
    raise exception 'INVALID_LIST';
  end if;
  begin
    delete from public.bg_warm_questions where true;
    insert into public.bg_warm_questions (q, a, b, topic)
    select ord::int, btrim(coalesce(e->>'a', '')), btrim(coalesce(e->>'b', '')), btrim(coalesce(e->>'topic', ''))
    from json_array_elements(p_list) with ordinality as t(e, ord);
  exception when check_violation then
    raise exception 'INVALID_LIST';
  end;
  return public.bg_admin_warm_list(p_key);
end;
$$;


-- 관리자: 참가자·질문·투표 전부 지우고 처음 상태로 (리허설 후 초기화용)
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
  delete from public.bg_warm_votes where true;
  delete from public.bg_votes     where true;
  delete from public.bg_questions where true;
  delete from public.bg_players   where true;
  update public.bg_state set status = 'ready', revealed = 0, warm_q = 0 where id = 1;
  return true;
end;
$$;

revoke all on function public.bg_join(text)                       from public;
revoke all on function public.bg_submit(uuid, text, text, text)   from public;
revoke all on function public.bg_vote(uuid, int, text)            from public;
revoke all on function public.bg_overview(uuid)                   from public;
revoke all on function public.bg_warm_vote(uuid, int, text)       from public;
revoke all on function public.bg_admin_set(text, text, int, int)  from public;
revoke all on function public.bg_admin_reset(text)                from public;
revoke all on function public.bg_admin_warm_list(text)            from public;
revoke all on function public.bg_admin_warm_save(text, json)      from public;
grant execute on function public.bg_join(text)                      to anon, authenticated;
grant execute on function public.bg_submit(uuid, text, text, text)  to anon, authenticated;
grant execute on function public.bg_vote(uuid, int, text)           to anon, authenticated;
grant execute on function public.bg_overview(uuid)                  to anon, authenticated;
grant execute on function public.bg_warm_vote(uuid, int, text)      to anon, authenticated;
grant execute on function public.bg_admin_set(text, text, int, int) to anon, authenticated;
grant execute on function public.bg_admin_reset(text)               to anon, authenticated;
grant execute on function public.bg_admin_warm_list(text)           to anon, authenticated;
grant execute on function public.bg_admin_warm_save(text, json)     to anon, authenticated;


-- ── 진행자 비밀번호 (이미 설정했다면 다시 할 필요 없음) ──
-- ⚠ 6자 이상. 이 레포는 공개이므로 비밀번호를 파일·채팅에 남기지 말 것.
-- insert into public.bg_admin (id, key) values (1, '여기에_진행자_비밀번호') on conflict (id) do update set key = excluded.key;

-- ── 관리자용 (필요할 때 SQL Editor 에서 직접 실행) ─────────────
-- 상태 보기   : select * from public.bg_state;
-- 질문 보기   : select q, title, a, b, (select name from public.bg_players p where p.token = bg_questions.token) as author from public.bg_questions order by q;
-- 워밍업 목록 : select * from public.bg_warm_questions order by q;   (화면의 관리자 메뉴에서 수정하는 것을 권장)
-- 질문 삭제   : delete from public.bg_questions where title = '지울 질문 주제';
-- 전체 초기화 : update public.bg_state set status = 'ready', revealed = 0, warm_q = 0; truncate public.bg_warm_votes; truncate public.bg_votes; delete from public.bg_questions where true; delete from public.bg_players where true;
