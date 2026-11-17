-- iMun Build 31: authenticated planner-only completion marker.
-- Not a HealthKit workout or a record of completed exercise sets.
create or replace function public.imun_mark_planned_workout_complete(
    p_item_id uuid,
    p_completed boolean default true
) returns boolean
language plpgsql
security invoker
set search_path to 'public', 'pg_temp'
as $function$
declare
    v_updated integer := 0;
begin
    if auth.uid() is null then
        raise exception 'Sign in to update a planned workout';
    end if;
    if p_item_id is null or p_completed is null then
        raise exception 'Choose an existing workout and a completion state';
    end if;

    update public.planner_state as ps
    set data = jsonb_set(
        ps.data, '{items}',
        (
            select coalesce(jsonb_agg(
                case when event.item->>'id' = p_item_id::text
                          and event.item->>'category' = 'workout'
                     then jsonb_set(
                         jsonb_set(event.item, '{completed}',
                                   to_jsonb(p_completed), true),
                         '{imunManualCompletion}', to_jsonb(p_completed), true
                     )
                     else event.item
                end order by event.ordinality
            ), '[]'::jsonb)
            from jsonb_array_elements(coalesce(ps.data->'items', '[]'::jsonb))
                with ordinality as event(item, ordinality)
        ),
        true
    ), updated_at = now()
    where ps.user_id = (select auth.uid())
      and exists (
          select 1
          from jsonb_array_elements(coalesce(ps.data->'items', '[]'::jsonb))
               as item(e)
          where e->>'id' = p_item_id::text
            and e->>'category' = 'workout'
      );

    get diagnostics v_updated = row_count;
    return v_updated = 1;
end;
$function$;

revoke all on function public.imun_mark_planned_workout_complete(uuid, boolean)
    from public, anon;
grant execute on function public.imun_mark_planned_workout_complete(uuid, boolean)
    to authenticated;

comment on function public.imun_mark_planned_workout_complete(uuid, boolean)
is $$Explicit user-confirmed planner completion; records no health or workout performance measurements.$$;
