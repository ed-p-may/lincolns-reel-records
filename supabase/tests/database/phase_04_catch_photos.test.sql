begin;

select plan(16);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('40000000-0000-0000-0000-000000000001', 'phase4-a@example.com', '{"username":"phase4_a"}'),
    ('40000000-0000-0000-0000-000000000002', 'phase4-b@example.com', '{"username":"phase4_b"}');

insert into public.catches (id, owner_id, species, caught_at)
values
    ('40000000-0000-0000-0000-000000000011', '40000000-0000-0000-0000-000000000001', 'Bass', now()),
    ('40000000-0000-0000-0000-000000000012', '40000000-0000-0000-0000-000000000002', 'Trout', now());

select results_eq(
    $$select count(*)::bigint
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'catch_photos'
        and column_name in (
            'id', 'catch_id', 'storage_path', 'position', 'created_at',
            'updated_at', 'deleted_at', 'version'
        )$$,
    array[8::bigint],
    'photo metadata and sync columns exist'
);

select results_eq(
    $$select concat_ws('|', public::text, file_size_limit::text, allowed_mime_types[1])
      from storage.buckets where id = 'catch-photos'$$,
    array['false|10485760|image/jpeg'::text],
    'private JPEG bucket has the documented limit'
);

select results_eq(
    $$select count(*)::bigint from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname like 'catch_photo_objects_%'$$,
    array[4::bigint],
    'Storage objects have owner-scoped CRUD policies'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select lives_ok(
    $$insert into public.catch_photos (
        id, catch_id, storage_path, position
      ) values (
        '40000000-0000-0000-0000-000000000021',
        '40000000-0000-0000-0000-000000000011',
        '40000000-0000-0000-0000-000000000001/40000000-0000-0000-0000-000000000011/40000000-0000-0000-0000-000000000021.jpg',
        0
      )$$,
    'owner can insert photo metadata for own Catch'
);

select throws_ok(
    $$insert into public.catch_photos (
        id, catch_id, storage_path, position
      ) values (
        '40000000-0000-0000-0000-000000000022',
        '40000000-0000-0000-0000-000000000011',
        'wrong/path/photo.jpg',
        1
      )$$,
    '23514',
    null,
    'metadata rejects a non-canonical path'
);

select throws_ok(
    $$insert into public.catch_photos (
        id, catch_id, storage_path, position
      ) values (
        '40000000-0000-0000-0000-000000000023',
        '40000000-0000-0000-0000-000000000011',
        '40000000-0000-0000-0000-000000000001/40000000-0000-0000-0000-000000000011/40000000-0000-0000-0000-000000000023.jpg',
        -1
      )$$,
    '23514',
    null,
    'negative position is rejected'
);

select lives_ok(
    $$insert into storage.objects (bucket_id, name, owner_id, metadata)
      values (
        'catch-photos',
        '40000000-0000-0000-0000-000000000001/40000000-0000-0000-0000-000000000011/40000000-0000-0000-0000-000000000021.jpg',
        '40000000-0000-0000-0000-000000000001',
        '{"mimetype":"image/jpeg"}'
      )$$,
    'owner can create canonical Storage metadata'
);

select results_eq(
    $$select count(*)::bigint from storage.objects where bucket_id = 'catch-photos'$$,
    array[1::bigint],
    'owner can list the canonical Storage object'
);

select throws_ok(
    $$insert into storage.objects (bucket_id, name, owner_id, metadata)
      values (
        'catch-photos',
        '40000000-0000-0000-0000-000000000001/40000000-0000-0000-0000-000000000012/40000000-0000-0000-0000-000000000099.jpg',
        '40000000-0000-0000-0000-000000000001',
        '{"mimetype":"image/jpeg"}'
      )$$,
    '42501',
    null,
    'owner cannot write beneath another account Catch path'
);

select results_eq(
    $$with changed as (
        update public.catch_photos
        set position = 2, version = 2, updated_at = now()
        where id = '40000000-0000-0000-0000-000000000021' and version = 1
        returning id
      ) select count(*)::bigint from changed$$,
    array[1::bigint],
    'owner can apply a versioned reorder'
);

select results_eq(
    $$with changed as (
        update public.catch_photos
        set deleted_at = now(), version = 3, updated_at = now()
        where id = '40000000-0000-0000-0000-000000000021' and version = 2
        returning id
      ) select count(*)::bigint from changed$$,
    array[1::bigint],
    'owner can apply a versioned tombstone'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"40000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);

select results_eq(
    $$select count(*)::bigint from public.catch_photos$$,
    array[0::bigint],
    'another owner cannot list photo metadata'
);

select results_eq(
    $$with changed as (
        update public.catch_photos set position = 9
        where id = '40000000-0000-0000-0000-000000000021'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'another owner cannot reorder photo metadata'
);

select results_eq(
    $$select count(*)::bigint from storage.objects where bucket_id = 'catch-photos'$$,
    array[0::bigint],
    'another owner cannot list Storage objects'
);

select results_eq(
    $$with changed as (
        update storage.objects set metadata = '{"intrusion":true}'
        where bucket_id = 'catch-photos'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'another owner cannot overwrite Storage objects'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"40000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select results_eq(
    $$select count(*)::bigint from public.catch_photos
      where deleted_at is not null and version = 3$$,
    array[1::bigint],
    'owner retains the metadata tombstone for recovery'
);

select * from finish();

rollback;
