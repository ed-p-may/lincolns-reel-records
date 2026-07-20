begin;

select plan(16);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('90000000-0000-0000-0000-000000000001', 'phase9-a@example.com', '{"username":"phase9_a"}'),
    ('90000000-0000-0000-0000-000000000002', 'phase9-b@example.com', '{"username":"phase9_b"}');

select results_eq(
    $$select count(*)::bigint from information_schema.columns
      where table_schema = 'public' and table_name = 'profiles'
        and column_name in (
          'id', 'username', 'display_name', 'home_water', 'avatar_storage_path',
          'angler_since', 'created_at', 'updated_at', 'version'
        )$$,
    array[9::bigint],
    'profile identity, editable fields, and sync columns exist'
);

select results_eq(
    $$select concat_ws('|', public::text, file_size_limit::text, allowed_mime_types[1])
      from storage.buckets where id = 'avatars'$$,
    array['false|10485760|image/jpeg'::text],
    'private avatar JPEG bucket has the documented limit'
);

select results_eq(
    $$select count(*)::bigint from pg_policies
      where schemaname = 'storage' and tablename = 'objects'
        and policyname like 'avatar_objects_%_own'$$,
    array[4::bigint],
    'avatar objects have owner-scoped CRUD policies'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select lives_ok(
    $$update public.profiles set
        display_name = 'Lincoln Fisher',
        home_water = 'Stockbridge Bowl',
        angler_since = 2019,
        avatar_storage_path = '90000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000011.jpg',
        version = 2,
        updated_at = now()
      where id = '90000000-0000-0000-0000-000000000001'$$,
    'owner can update editable profile fields'
);

select throws_ok(
    $$update public.profiles set username = 'renamed'
      where id = '90000000-0000-0000-0000-000000000001'$$,
    '42501',
    'Profile identity fields are server-managed.',
    'username remains immutable'
);

select throws_ok(
    $$update public.profiles set angler_since = 1899
      where id = '90000000-0000-0000-0000-000000000001'$$,
    '23514',
    null,
    'angler-since rejects an implausibly early year'
);

select throws_ok(
    $$update public.profiles set angler_since = extract(year from current_date)::integer + 1
      where id = '90000000-0000-0000-0000-000000000001'$$,
    '23514',
    null,
    'angler-since rejects a future year'
);

select throws_ok(
    $$update public.profiles set display_name = ' untrimmed '
      where id = '90000000-0000-0000-0000-000000000001'$$,
    '23514',
    null,
    'display name must be trimmed'
);

select throws_ok(
    $$update public.profiles set avatar_storage_path = 'wrong/path.jpg'
      where id = '90000000-0000-0000-0000-000000000001'$$,
    '23514',
    null,
    'avatar metadata rejects a noncanonical path'
);

select results_eq(
    $$select display_name from public.profiles$$,
    array['Lincoln Fisher'::text],
    'owner sees only their profile'
);

select lives_ok(
    $$insert into storage.objects (bucket_id, name, owner_id, metadata)
      values (
        'avatars',
        '90000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000011.jpg',
        '90000000-0000-0000-0000-000000000001',
        '{"mimetype":"image/jpeg"}'
      )$$,
    'owner can create canonical avatar metadata'
);

select results_eq(
    $$select count(*)::bigint from storage.objects where bucket_id = 'avatars'$$,
    array[1::bigint],
    'owner can list their avatar object'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"90000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);

select results_eq(
    $$select count(*)::bigint from public.profiles$$,
    array[1::bigint],
    'another owner sees only their own profile'
);

select results_eq(
    $$with changed as (
        update public.profiles set display_name = 'Intruder'
        where id = '90000000-0000-0000-0000-000000000001'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'another owner cannot edit the first profile'
);

select throws_ok(
    $$insert into storage.objects (bucket_id, name, owner_id, metadata)
      values (
        'avatars',
        '90000000-0000-0000-0000-000000000001/90000000-0000-0000-0000-000000000012.jpg',
        '90000000-0000-0000-0000-000000000002',
        '{"mimetype":"image/jpeg"}'
      )$$,
    '42501',
    null,
    'another owner cannot write beneath the first owner avatar path'
);

select results_eq(
    $$select count(*)::bigint from storage.objects where bucket_id = 'avatars'$$,
    array[0::bigint],
    'another owner cannot list the first avatar object'
);

select * from finish();

rollback;
