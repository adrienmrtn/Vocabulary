-- The same spelling can now be a word in several languages (Portuguese of Brazil
-- and of Portugal share most of theirs). A word is identified by its language
-- and its lemma together.
--
-- The member's tables keep pointing to words by lemma alone: a favorite is a
-- spelling, shown in whichever catalogue has it. They therefore lose their
-- foreign key to words(lemma), which needed the lemma to be unique;
-- sync_user_state still checks that the lemma exists.

alter table public.favorites drop constraint favorites_lemma_fkey;
alter table public.collection_words drop constraint collection_words_lemma_fkey;
alter table public.review_state drop constraint review_state_lemma_fkey;
alter table public.word_history drop constraint word_history_lemma_fkey;

alter table public.words drop constraint words_lemma_key;
alter table public.words add constraint words_language_lemma_key unique (language, lemma);
create index words_lemma_idx on public.words (lemma);

create or replace function public.import_catalog(payload jsonb)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  lang text := coalesce(payload ->> 'language', 'en');
begin
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
  on conflict (language, lemma) do update set
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
    and w.language = lang
    and w.lemma in (select x ->> 'lemma' from jsonb_array_elements(coalesce(payload -> 'words', '[]'::jsonb)) as x);

  insert into public.word_topics (word_id, topic_id)
  select w.id, t.id
  from jsonb_array_elements(coalesce(payload -> 'words', '[]'::jsonb)) as x
  cross join lateral jsonb_array_elements_text(coalesce(x -> 'topics', '[]'::jsonb)) as s(slug)
  join public.words w on w.lemma = x ->> 'lemma' and w.language = lang
  join public.topics t on t.slug = s.slug
  on conflict do nothing;

  return (select count(*)::integer from public.words where status = 'published' and language = lang);
end;
$$;

revoke execute on function public.import_catalog(jsonb) from public, anon, authenticated;
grant execute on function public.import_catalog(jsonb) to service_role;
