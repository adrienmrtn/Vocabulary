-- One catalogue per language. A word belongs to the language it is taught in.
-- The lemma stays unique across languages: it is the key the member's data
-- points to, so the content pipeline refuses a word spelled like an existing one.

alter table public.words add column language text not null default 'en';
create index words_language_idx on public.words (language);

-- Builds released before languages existed read this view: it stays English only.
create or replace view public.catalog
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
where w.status = 'published' and w.language = 'en';

-- The same shape with the language, which the app filters on.
create view public.catalog_localized
with (security_invoker = true) as
select
  w.language,
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

grant select on public.catalog_localized to anon, authenticated;

-- import_catalog now takes the language of the words it loads ("en" when absent).
create or replace function public.import_catalog(payload jsonb)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  lang text := coalesce(payload ->> 'language', 'en');
begin
  -- A word of another language with the same spelling would be overwritten.
  if exists (
    select 1
    from jsonb_array_elements(coalesce(payload -> 'words', '[]'::jsonb)) as x
    join public.words w on w.lemma = x ->> 'lemma'
    where w.language <> lang
  ) then
    raise exception 'a word is already in the catalogue of another language';
  end if;

  insert into public.topics (slug, name, image_path, is_premium, position)
  select t ->> 'slug', t ->> 'name', t ->> 'image', (t ->> 'premium')::boolean, (t ->> 'position')::integer
  from jsonb_array_elements(coalesce(payload -> 'topics', '[]'::jsonb)) as t
  on conflict (slug) do update set
    name = excluded.name,
    image_path = excluded.image_path,
    is_premium = excluded.is_premium,
    position = excluded.position;

  insert into public.words
    (lemma, part_of_speech, ipa, definition, example, quote, quote_source, synonyms, origin, level, status, language)
  select
    w ->> 'lemma', w ->> 'part_of_speech', w ->> 'ipa', w ->> 'definition', w ->> 'example',
    nullif(w ->> 'quote', ''), nullif(w ->> 'quote_source', ''),
    array(select jsonb_array_elements_text(coalesce(w -> 'synonyms', '[]'::jsonb))),
    w ->> 'origin', (w ->> 'level')::smallint, 'published', lang
  from jsonb_array_elements(coalesce(payload -> 'words', '[]'::jsonb)) as w
  on conflict (lemma) do update set
    part_of_speech = excluded.part_of_speech,
    ipa = excluded.ipa,
    definition = excluded.definition,
    example = excluded.example,
    quote = excluded.quote,
    quote_source = excluded.quote_source,
    synonyms = excluded.synonyms,
    origin = excluded.origin,
    level = excluded.level,
    status = 'published';

  delete from public.word_topics wt
  using public.words w
  where w.id = wt.word_id
    and w.lemma in (select x ->> 'lemma' from jsonb_array_elements(coalesce(payload -> 'words', '[]'::jsonb)) as x);

  insert into public.word_topics (word_id, topic_id)
  select w.id, t.id
  from jsonb_array_elements(coalesce(payload -> 'words', '[]'::jsonb)) as x
  cross join lateral jsonb_array_elements_text(coalesce(x -> 'topics', '[]'::jsonb)) as s(slug)
  join public.words w on w.lemma = x ->> 'lemma'
  join public.topics t on t.slug = s.slug
  on conflict do nothing;

  return (select count(*)::integer from public.words where status = 'published' and language = lang);
end;
$$;

revoke execute on function public.import_catalog(jsonb) from public, anon, authenticated;
grant execute on function public.import_catalog(jsonb) to service_role;
