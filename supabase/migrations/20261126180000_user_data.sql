-- The catalogue in the exact shape the app decodes, and each member's own data.
-- Members read and write only their own rows. The app does not touch the user
-- tables directly: it sends its whole state to sync_user_state and reads it
-- back with get_user_state, so a sync is one call and all-or-nothing.

grant select on public.words, public.topics, public.word_topics to anon, authenticated;

create view public.catalog
with (security_invoker = true) as
select
  w.lemma,
  w.level,
  w.part_of_speech,
  coalesce(w.ipa, '') as ipa,
  w.definition,
  coalesce(w.example, '') as example,
  w.synonyms,
  coalesce(w.origin, '') as origin,
  coalesce(w.quote, '') as quote,
  coalesce(w.quote_source, '') as quote_source,
  coalesce(
    (
      select array_agg(t.slug order by t.position)
      from public.word_topics wt
      join public.topics t on t.id = wt.topic_id
      where wt.word_id = w.id
    ),
    '{}'
  ) as topics
from public.words w
where w.status = 'published';

grant select on public.catalog to anon, authenticated;

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  -- Onboarding answers: question title -> chosen options.
  onboarding jsonb not null default '{}',
  theme smallint not null default 0,
  icon_character smallint not null default 0,
  icon_background smallint not null default 0,
  updated_at timestamptz not null default now()
);

create table public.favorites (
  user_id uuid not null references auth.users (id) on delete cascade,
  lemma text not null references public.words (lemma) on update cascade on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, lemma)
);

create table public.collections (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);

create table public.collection_words (
  collection_id uuid not null references public.collections (id) on delete cascade,
  lemma text not null references public.words (lemma) on update cascade on delete cascade,
  added_at timestamptz not null default now(),
  primary key (collection_id, lemma)
);

create table public.custom_words (
  id uuid primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  word text not null,
  part_of_speech text not null default '',
  definition text not null default '',
  created_at timestamptz not null default now()
);

create table public.word_history (
  user_id uuid not null references auth.users (id) on delete cascade,
  lemma text not null references public.words (lemma) on update cascade on delete cascade,
  seen_at timestamptz not null default now(),
  primary key (user_id, lemma)
);

-- Spaced review: box 0 is "missed, ask again soon", box 5 is "known".
create table public.review_state (
  user_id uuid not null references auth.users (id) on delete cascade,
  lemma text not null references public.words (lemma) on update cascade on delete cascade,
  box smallint not null check (box between 0 and 5),
  updated_at timestamptz not null default now(),
  primary key (user_id, lemma)
);

-- One row per day the member used the app; the streak is computed from these.
create table public.activity_days (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  primary key (user_id, day)
);

create index favorites_lemma_idx on public.favorites (lemma);
create index collections_user_idx on public.collections (user_id);
create index collection_words_lemma_idx on public.collection_words (lemma);
create index custom_words_user_idx on public.custom_words (user_id);
create index word_history_lemma_idx on public.word_history (lemma);
create index review_state_lemma_idx on public.review_state (lemma);

alter table public.profiles enable row level security;
alter table public.favorites enable row level security;
alter table public.collections enable row level security;
alter table public.collection_words enable row level security;
alter table public.custom_words enable row level security;
alter table public.word_history enable row level security;
alter table public.review_state enable row level security;
alter table public.activity_days enable row level security;

grant select, insert, update, delete on
  public.profiles, public.favorites, public.collections, public.collection_words,
  public.custom_words, public.word_history, public.review_state, public.activity_days
to authenticated;

create policy "Members manage their own profile" on public.profiles
for all to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Members manage their own favorites" on public.favorites
for all to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Members manage their own collections" on public.collections
for all to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Members manage the words of their own collections" on public.collection_words
for all to authenticated
using (
  exists (
    select 1 from public.collections c
    where c.id = collection_words.collection_id and c.user_id = (select auth.uid())
  )
)
with check (
  exists (
    select 1 from public.collections c
    where c.id = collection_words.collection_id and c.user_id = (select auth.uid())
  )
);

create policy "Members manage their own words" on public.custom_words
for all to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Members manage their own history" on public.word_history
for all to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Members manage their own review state" on public.review_state
for all to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy "Members manage their own activity days" on public.activity_days
for all to authenticated
using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- Replace the member's stored state with the document the app sends.
create function public.sync_user_state(state jsonb)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  sent_collections jsonb := coalesce(state -> 'collections', '[]'::jsonb);
  sent_custom jsonb := coalesce(state -> 'custom_words', '[]'::jsonb);
  sent_history jsonb := coalesce(state -> 'history', '[]'::jsonb);
  sent_review jsonb := coalesce(state -> 'review', '{}'::jsonb);
begin
  if me is null then
    raise exception 'Not signed in';
  end if;

  insert into public.profiles (user_id, display_name, onboarding, theme, icon_character, icon_background, updated_at)
  values (
    me,
    coalesce(state ->> 'display_name', ''),
    coalesce(state -> 'onboarding', '{}'::jsonb),
    coalesce((state ->> 'theme')::smallint, 0),
    coalesce((state ->> 'icon_character')::smallint, 0),
    coalesce((state ->> 'icon_background')::smallint, 0),
    now()
  )
  on conflict (user_id) do update set
    display_name = excluded.display_name,
    onboarding = excluded.onboarding,
    theme = excluded.theme,
    icon_character = excluded.icon_character,
    icon_background = excluded.icon_background,
    updated_at = now();

  -- Favorites
  delete from public.favorites f
  where f.user_id = me
    and f.lemma not in (select jsonb_array_elements_text(coalesce(state -> 'favorites', '[]'::jsonb)));
  insert into public.favorites (user_id, lemma)
  select me, v.lemma
  from jsonb_array_elements_text(coalesce(state -> 'favorites', '[]'::jsonb)) as v(lemma)
  where exists (select 1 from public.words w where w.lemma = v.lemma)
  on conflict do nothing;

  -- Collections and their words
  delete from public.collections c
  where c.user_id = me
    and c.id not in (select (e ->> 'id')::uuid from jsonb_array_elements(sent_collections) as e);
  insert into public.collections (id, user_id, name)
  select (e ->> 'id')::uuid, me, coalesce(e ->> 'name', '')
  from jsonb_array_elements(sent_collections) as e
  on conflict (id) do update set name = excluded.name
  where public.collections.user_id = me;
  delete from public.collection_words cw
  using public.collections c
  where c.id = cw.collection_id and c.user_id = me;
  insert into public.collection_words (collection_id, lemma)
  select (e ->> 'id')::uuid, l.lemma
  from jsonb_array_elements(sent_collections) as e
  cross join lateral jsonb_array_elements_text(coalesce(e -> 'words', '[]'::jsonb)) as l(lemma)
  where exists (select 1 from public.words w where w.lemma = l.lemma)
    and exists (select 1 from public.collections k where k.id = (e ->> 'id')::uuid and k.user_id = me)
  on conflict do nothing;

  -- The member's own words
  delete from public.custom_words k
  where k.user_id = me
    and k.id not in (select (e ->> 'id')::uuid from jsonb_array_elements(sent_custom) as e);
  insert into public.custom_words (id, user_id, word, part_of_speech, definition)
  select (e ->> 'id')::uuid, me, coalesce(e ->> 'word', ''), coalesce(e ->> 'part_of_speech', ''),
         coalesce(e ->> 'definition', '')
  from jsonb_array_elements(sent_custom) as e
  on conflict (id) do update set
    word = excluded.word,
    part_of_speech = excluded.part_of_speech,
    definition = excluded.definition
  where public.custom_words.user_id = me;

  -- History
  delete from public.word_history h
  where h.user_id = me
    and h.lemma not in (select e ->> 'lemma' from jsonb_array_elements(sent_history) as e);
  insert into public.word_history (user_id, lemma, seen_at)
  select me, e ->> 'lemma', (e ->> 'seen_at')::timestamptz
  from jsonb_array_elements(sent_history) as e
  where exists (select 1 from public.words w where w.lemma = e ->> 'lemma')
  on conflict (user_id, lemma) do update set seen_at = excluded.seen_at;

  -- Review boxes
  delete from public.review_state r
  where r.user_id = me
    and r.lemma not in (select k from jsonb_object_keys(sent_review) as k);
  insert into public.review_state (user_id, lemma, box, updated_at)
  select me, e.key, least(greatest(e.value::smallint, 0), 5), now()
  from jsonb_each_text(sent_review) as e
  where exists (select 1 from public.words w where w.lemma = e.key)
  on conflict (user_id, lemma) do update set box = excluded.box, updated_at = now();

  -- Activity days are only ever added.
  insert into public.activity_days (user_id, day)
  select me, v.day::date
  from jsonb_array_elements_text(coalesce(state -> 'activity_days', '[]'::jsonb)) as v(day)
  on conflict do nothing;
end;
$$;

-- The member's stored state, as one document in the shape sync_user_state takes.
create function public.get_user_state()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'display_name', coalesce((select p.display_name from public.profiles p where p.user_id = (select auth.uid())), ''),
    'onboarding', coalesce((select p.onboarding from public.profiles p where p.user_id = (select auth.uid())), '{}'::jsonb),
    'theme', coalesce((select p.theme from public.profiles p where p.user_id = (select auth.uid())), 0),
    'icon_character', coalesce((select p.icon_character from public.profiles p where p.user_id = (select auth.uid())), 0),
    'icon_background', coalesce((select p.icon_background from public.profiles p where p.user_id = (select auth.uid())), 0),
    'favorites', coalesce(
      (select jsonb_agg(f.lemma order by f.created_at) from public.favorites f where f.user_id = (select auth.uid())),
      '[]'::jsonb),
    'collections', coalesce(
      (select jsonb_agg(
         jsonb_build_object(
           'id', c.id,
           'name', c.name,
           'words', coalesce(
             (select jsonb_agg(cw.lemma order by cw.added_at) from public.collection_words cw where cw.collection_id = c.id),
             '[]'::jsonb)
         ) order by c.created_at)
       from public.collections c where c.user_id = (select auth.uid())),
      '[]'::jsonb),
    'custom_words', coalesce(
      (select jsonb_agg(
         jsonb_build_object('id', k.id, 'word', k.word, 'part_of_speech', k.part_of_speech, 'definition', k.definition)
         order by k.created_at)
       from public.custom_words k where k.user_id = (select auth.uid())),
      '[]'::jsonb),
    'history', coalesce(
      (select jsonb_agg(
         jsonb_build_object(
           'lemma', h.lemma,
           'seen_at', to_char(h.seen_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
         order by h.seen_at desc)
       from public.word_history h where h.user_id = (select auth.uid())),
      '[]'::jsonb),
    'review', coalesce(
      (select jsonb_object_agg(r.lemma, r.box) from public.review_state r where r.user_id = (select auth.uid())),
      '{}'::jsonb),
    'activity_days', coalesce(
      (select jsonb_agg(to_char(a.day, 'YYYY-MM-DD') order by a.day) from public.activity_days a where a.user_id = (select auth.uid())),
      '[]'::jsonb)
  );
$$;

revoke execute on function public.sync_user_state(jsonb) from public, anon;
revoke execute on function public.get_user_state() from public, anon;
grant execute on function public.sync_user_state(jsonb) to authenticated;
grant execute on function public.get_user_state() to authenticated;
