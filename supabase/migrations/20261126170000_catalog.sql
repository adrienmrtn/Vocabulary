-- Bovary word catalogue.
-- The app reads published rows with the public (anon) key.
-- Only the service role, used by the content pipeline, can write.

create table public.words (
  id uuid primary key default gen_random_uuid(),
  lemma text not null unique,
  part_of_speech text not null,
  ipa text,
  definition text not null,
  example text,
  -- A sentence from a public-domain book that uses the word, with its author and title.
  quote text,
  quote_source text,
  synonyms text[] not null default '{}',
  origin text,
  -- 1 = beginner, 2 = intermediate, 3 = advanced.
  level smallint not null check (level between 1 and 3),
  frequency_rank integer,
  -- draft: generated, not checked. reviewed: checked. published: visible in the app.
  status text not null default 'draft' check (status in ('draft', 'reviewed', 'published')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.topics (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  image_path text,
  is_premium boolean not null default true,
  position integer not null default 0
);

create table public.word_topics (
  word_id uuid not null references public.words (id) on delete cascade,
  topic_id uuid not null references public.topics (id) on delete cascade,
  primary key (word_id, topic_id)
);

create index words_status_level_idx on public.words (status, level);
create index word_topics_topic_idx on public.word_topics (topic_id);

create function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger words_touch_updated_at
before update on public.words
for each row execute function public.touch_updated_at();

alter table public.words enable row level security;
alter table public.topics enable row level security;
alter table public.word_topics enable row level security;

create policy "Published words are readable by everyone"
on public.words for select
to anon, authenticated
using (status = 'published');

create policy "Topics are readable by everyone"
on public.topics for select
to anon, authenticated
using (true);

create policy "Links to published words are readable by everyone"
on public.word_topics for select
to anon, authenticated
using (
  exists (
    select 1 from public.words w
    where w.id = word_topics.word_id and w.status = 'published'
  )
);
