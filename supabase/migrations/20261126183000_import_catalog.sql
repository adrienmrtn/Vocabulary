-- Used by content/push_catalog.py to load the catalogue. Service role only.
create function public.import_catalog(payload jsonb)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
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
    (lemma, part_of_speech, ipa, definition, example, quote, quote_source, synonyms, origin, level, status)
  select
    w ->> 'lemma', w ->> 'part_of_speech', w ->> 'ipa', w ->> 'definition', w ->> 'example',
    nullif(w ->> 'quote', ''), nullif(w ->> 'quote_source', ''),
    array(select jsonb_array_elements_text(coalesce(w -> 'synonyms', '[]'::jsonb))),
    w ->> 'origin', (w ->> 'level')::smallint, 'published'
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

  return (select count(*)::integer from public.words where status = 'published');
end;
$$;

revoke execute on function public.import_catalog(jsonb) from public, anon, authenticated;
grant execute on function public.import_catalog(jsonb) to service_role;
