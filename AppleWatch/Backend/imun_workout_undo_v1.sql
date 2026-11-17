-- Build 34: durable undo ledger for iPhone/Apple Watch.
-- No existing workout rows are changed until a signed-in athlete invokes the RPC.
create table if not exists public.health_coach_workout_undos (
    user_id uuid not null references auth.users(id) on delete cascade,
    id uuid not null,
    kind text not null check (kind in ('set','workout')),
    set_id uuid,
    workout_date date not null,
    session_key text not null,
    window_started_at timestamptz,
    window_ended_at timestamptz,
    created_at timestamptz not null default now(),
    primary key(user_id,id),
    constraint imun_undo_shape check (
        (kind='set' and set_id is not null and window_started_at is null and window_ended_at is null)
        or
        (kind='workout' and set_id is null and window_started_at is not null
         and window_ended_at is not null and window_started_at <= window_ended_at)
    )
);
create index if not exists health_coach_workout_undos_scope
  on public.health_coach_workout_undos(user_id,workout_date,session_key);
create index if not exists health_coach_workout_undos_set
  on public.health_coach_workout_undos(user_id,set_id)
  where kind='set';

alter table public.health_coach_workout_undos enable row level security;
revoke all on public.health_coach_workout_undos from anon;
grant select,insert on public.health_coach_workout_undos to authenticated;
drop policy if exists "iMun read own workout undos" on public.health_coach_workout_undos;
create policy "iMun read own workout undos" on public.health_coach_workout_undos
    for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists "iMun insert own workout undos" on public.health_coach_workout_undos;
create policy "iMun insert own workout undos" on public.health_coach_workout_undos
    for insert to authenticated with check ((select auth.uid())=user_id);
drop policy if exists "iMun delete own undone sets" on public.health_coach_watch_sets;
create policy "iMun delete own undone sets" on public.health_coach_watch_sets
    for delete to authenticated using ((select auth.uid())=user_id);
grant delete on public.health_coach_watch_sets to authenticated;

-- Prevent delayed or duplicated device uploads from recreating corrected sets.
create or replace function public.imun_ignore_undone_set()
returns trigger language plpgsql security invoker
set search_path to 'public','pg_temp' as $function$
begin
    if exists (
        select 1 from public.health_coach_workout_undos as u
        where u.user_id = new.user_id
          and (
            (u.kind='set' and u.set_id=new.id)
            or
            (u.kind='workout' and u.workout_date=new.workout_date
             and u.session_key=new.session_key
             and new.completed_at >= u.window_started_at
             and new.completed_at <= u.window_ended_at)
          )
    ) then return null; end if;
    return new;
end
$function$;
drop trigger if exists imun_block_undone_set_upsert on public.health_coach_watch_sets;
create trigger imun_block_undone_set_upsert
before insert or update on public.health_coach_watch_sets
for each row execute function public.imun_ignore_undone_set();

create or replace function public.imun_undo_workout_record(
    p_id uuid, p_kind text, p_set_id uuid, p_date date,
    p_session_key text, p_started_at timestamptz, p_ended_at timestamptz
) returns boolean language plpgsql security invoker
set search_path to 'public','pg_temp' as $function$
declare v_user uuid;
begin
    v_user := auth.uid();
    if v_user is null then raise exception 'Sign in to undo a workout'; end if;
    if p_id is null or p_date is null or p_session_key is null
       or length(p_session_key)>150 then raise exception 'Invalid workout correction'; end if;
    if p_kind='set' then
        if p_set_id is null or p_started_at is not null or p_ended_at is not null
            then raise exception 'Invalid set correction'; end if;
    elsif p_kind='workout' then
        if p_set_id is not null or p_started_at is null or p_ended_at is null
           or p_started_at>p_ended_at or p_ended_at-p_started_at>interval '24 hours'
           or p_ended_at>now()+interval '1 minute'
            then raise exception 'Invalid workout correction time'; end if;
    else
        raise exception 'Unknown correction type';
    end if;
    insert into public.health_coach_workout_undos (
        user_id,id,kind,set_id,workout_date,session_key,
        window_started_at,window_ended_at
    ) values (
        v_user,p_id,p_kind,p_set_id,p_date,p_session_key,
        p_started_at,p_ended_at
    ) on conflict(user_id,id) do nothing;

    if p_kind='set' then
        delete from public.health_coach_watch_sets
        where user_id=v_user and id=p_set_id;
    else
        delete from public.health_coach_watch_sets
        where user_id=v_user and workout_date=p_date and session_key=p_session_key
        and completed_at >= p_started_at and completed_at <= p_ended_at;
    end if;
    return true;
end
$function$;
revoke all on function public.imun_undo_workout_record(
    uuid,text,uuid,date,text,timestamptz,timestamptz) from public,anon;
grant execute on function public.imun_undo_workout_record(
    uuid,text,uuid,date,text,timestamptz,timestamptz) to authenticated;
comment on table public.health_coach_workout_undos is
'User-approved correction ledger; late iPhone/Watch retries cannot resurrect undone sets.';
