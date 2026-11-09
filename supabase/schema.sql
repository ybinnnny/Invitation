-- ═══════════════════════════════════════════════════════════════
-- 분당 8선녀 송년회 초대장 — Supabase 스키마
-- Supabase 대시보드 → SQL Editor 에 전체 붙여넣고 Run (여러 번 실행해도 안전)
--
-- 보안 원칙
--   · 브라우저에는 publishable(anon) key 만 노출된다. 이 키로 할 수 있는 일을
--     아래 함수·정책으로 "필요한 만큼만" 허용한다.
--   · team_slots 테이블은 anon 이 직접 읽거나 쓸 수 없다. 함수(RPC)로만 접근.
--   · 사진은 "올리기"와 "보기"만 허용. 수정·삭제는 대시보드(관리자)에서만.
-- ═══════════════════════════════════════════════════════════════


-- ── 1. 조 선택 ─────────────────────────────────────────────────
create table if not exists public.team_slots (
  team        text        not null check (team in ('A', 'B')),
  seat        smallint    not null check (seat between 1 and 4),   -- 조당 정원 4
  name        text        not null check (char_length(btrim(name)) between 1 and 20),
  claim_token uuid        not null default gen_random_uuid(),      -- 본인 취소용 비밀값
  created_at  timestamptz not null default now(),
  primary key (team, seat)                                          -- 같은 자리 중복 불가
);
create unique index if not exists team_slots_name_key  on public.team_slots (lower(btrim(name)));
create unique index if not exists team_slots_token_key on public.team_slots (claim_token);

alter table public.team_slots enable row level security;          -- 정책 없음 = anon 직접 접근 차단
revoke all on public.team_slots from anon, authenticated;


-- 현황 조회 (claim_token 은 내보내지 않음)
create or replace function public.list_slots()
returns table (team text, seat smallint, name text, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select team, seat, name, created_at from public.team_slots order by team, seat;
$$;


-- 참가: 전역 잠금으로 직렬화 → 동시에 눌러도 정원(4) 초과 불가
--       (잠금이 없더라도 PK(team, seat) + seat 1~4 CHECK 가 최종 방어선)
create or replace function public.join_team(p_team text, p_name text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name  text := btrim(coalesce(p_name, ''));
  v_seat  smallint;
  v_token uuid;
begin
  if p_team is null or p_team not in ('A', 'B') then
    raise exception 'INVALID_TEAM';
  end if;
  if char_length(v_name) not between 1 and 20 then
    raise exception 'INVALID_NAME';
  end if;

  perform pg_advisory_xact_lock(hashtext('team_slots'));         -- 트랜잭션 끝나면 자동 해제

  if exists (select 1 from public.team_slots t where lower(btrim(t.name)) = lower(v_name)) then
    raise exception 'NAME_TAKEN';
  end if;

  select s::smallint into v_seat
  from generate_series(1, 4) as s
  where not exists (select 1 from public.team_slots t where t.team = p_team and t.seat = s)
  order by s
  limit 1;

  if v_seat is null then
    raise exception 'TEAM_FULL';
  end if;

  insert into public.team_slots (team, seat, name)
  values (p_team, v_seat, v_name)
  returning claim_token into v_token;

  return json_build_object('team', p_team, 'seat', v_seat, 'token', v_token);
end;
$$;


-- 취소: 참가할 때 받은 토큰을 가진 사람(=그 폰)만 자기 자리를 지울 수 있음
create or replace function public.leave_team(p_token uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.team_slots where claim_token = p_token;
  return found;
end;
$$;

revoke all on function public.list_slots()             from public;
revoke all on function public.join_team(text, text)    from public;
revoke all on function public.leave_team(uuid)         from public;
grant execute on function public.list_slots()          to anon, authenticated;
grant execute on function public.join_team(text, text) to anon, authenticated;
grant execute on function public.leave_team(uuid)      to anon, authenticated;


-- ── 2. 사진 ────────────────────────────────────────────────────
-- 공개 버킷: 5MB 제한 + 이미지 형식만 (서버가 강제, 위반 시 업로드 거부)
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('photos', 'photos', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/heic', 'image/heif'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 장난·폭주 방지용 총 장수 상한 (필요하면 숫자만 조정)
create or replace function public.photo_count()
returns bigint
language sql
stable
security definer
set search_path = public, storage
as $$
  select count(*) from storage.objects where bucket_id = 'photos';
$$;
revoke all on function public.photo_count() from public;
grant execute on function public.photo_count() to anon, authenticated;

drop policy if exists "photos: anyone can list"   on storage.objects;
drop policy if exists "photos: anyone can upload" on storage.objects;

-- 갤러리 목록 조회
create policy "photos: anyone can list"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'photos');

-- 업로드: uploads/ 폴더에만, 총 300장까지. UPDATE/DELETE 정책은 만들지 않음 → 덮어쓰기·삭제 불가
create policy "photos: anyone can upload"
  on storage.objects for insert
  to anon, authenticated
  with check (
    bucket_id = 'photos'
    and (storage.foldername(name))[1] = 'uploads'
    and public.photo_count() < 300
  );


-- ── 관리자용 (필요할 때 SQL Editor 에서 직접 실행) ─────────────
-- 조 현황 보기 : select * from public.team_slots order by team, seat;
-- 한 명 빼기   : delete from public.team_slots where name = '홍길동';
-- 전체 초기화  : truncate public.team_slots;
-- 사진 삭제    : 대시보드 → Storage → photos 에서 선택 삭제
