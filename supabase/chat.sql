-- ═══════════════════════════════════════════════════════════════
-- 수다공간(자유 게시판) — Supabase 스키마
-- schema.sql 을 먼저 실행한 프로젝트의 SQL Editor 에서 이 파일 전체를 붙여넣고 Run
-- (여러 번 실행해도 안전)
--
-- 보안 원칙
--   · chat_messages 테이블은 anon 이 직접 읽거나 쓸 수 없다. 함수(RPC)로만 접근.
--   · 글 삭제는 글을 쓸 때 받은 토큰을 가진 사람(=그 폰)만 가능.
--   · 도배 방지: 전체 300개 상한, 1분에 15개 초과 시 거부.
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.chat_messages (
  id          bigint      generated always as identity primary key,
  name        text        not null check (char_length(btrim(name)) between 1 and 20),
  body        text        not null check (char_length(btrim(body)) between 1 and 300),
  claim_token uuid        not null default gen_random_uuid(),   -- 본인 삭제용 비밀값
  created_at  timestamptz not null default now()
);
create unique index if not exists chat_messages_token_key   on public.chat_messages (claim_token);
create index        if not exists chat_messages_created_idx on public.chat_messages (created_at desc);

alter table public.chat_messages enable row level security;    -- 정책 없음 = anon 직접 접근 차단
revoke all on public.chat_messages from anon, authenticated;


-- 목록 조회 (최신순, claim_token 은 내보내지 않음)
create or replace function public.list_messages(p_limit int default 100)
returns table (id bigint, name text, body text, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select m.id, m.name, m.body, m.created_at
  from public.chat_messages m
  order by m.created_at desc, m.id desc
  limit least(greatest(coalesce(p_limit, 100), 1), 200);
$$;


-- 글 남기기: 작성자명을 비우면 '익명'
create or replace function public.post_message(p_name text, p_body text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name  text := btrim(coalesce(p_name, ''));
  v_body  text := btrim(coalesce(p_body, ''));
  v_id    bigint;
  v_token uuid;
begin
  if v_name = '' then
    v_name := '익명';
  end if;
  if char_length(v_name) > 20 then
    raise exception 'INVALID_NAME';
  end if;
  if char_length(v_body) not between 1 and 300 then
    raise exception 'INVALID_BODY';
  end if;
  if (select count(*) from public.chat_messages) >= 300 then
    raise exception 'CHAT_FULL';
  end if;
  if (select count(*) from public.chat_messages where created_at > now() - interval '1 minute') >= 15 then
    raise exception 'TOO_FAST';
  end if;

  insert into public.chat_messages (name, body)
  values (v_name, v_body)
  returning id, claim_token into v_id, v_token;

  return json_build_object('id', v_id, 'token', v_token);
end;
$$;


-- 내 글 삭제: 글을 쓸 때 받은 토큰을 가진 사람만
create or replace function public.delete_message(p_token uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.chat_messages where claim_token = p_token;
  return found;
end;
$$;

revoke all on function public.list_messages(int)          from public;
revoke all on function public.post_message(text, text)    from public;
revoke all on function public.delete_message(uuid)        from public;
grant execute on function public.list_messages(int)       to anon, authenticated;
grant execute on function public.post_message(text, text) to anon, authenticated;
grant execute on function public.delete_message(uuid)     to anon, authenticated;


-- ── 관리자용 (필요할 때 SQL Editor 에서 직접 실행) ─────────────
-- 글 보기       : select id, name, body, created_at from public.chat_messages order by id desc;
-- 글 한 개 삭제 : delete from public.chat_messages where id = 123;
-- 전체 초기화   : truncate public.chat_messages;
