begin;

select plan(19);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('80000000-0000-0000-0000-000000000001', 'phase8-a@example.com', '{"username":"phase8_a"}'),
    ('80000000-0000-0000-0000-000000000002', 'phase8-b@example.com', '{"username":"phase8_b"}');

select results_eq(
    $$select count(*)::bigint
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'tackle_items'
        and column_name in (
            'id', 'owner_id', 'name', 'type', 'size', 'color', 'brand',
            'photo_storage_path', 'archived', 'created_at', 'updated_at',
            'deleted_at', 'version'
        )$$,
    array[13::bigint],
    'TackleItem data, archive, photo, and sync columns exist'
);

select is(
    (select string_agg(enumlabel::text, ',' order by enumsortorder)
     from pg_enum
     join pg_type on pg_type.oid = pg_enum.enumtypid
     where pg_type.typname = 'tackle_item_type') collate "C",
    'soft_plastic,crankbait,spinnerbait,jig,topwater,spoon,fly,live_bait,other'::text collate "C",
    'the fixed TackleItem type list is enforced'
);

select results_eq(
    $$select concat_ws('|', public::text, file_size_limit::text, allowed_mime_types[1])
      from storage.buckets where id = 'tackle-photos'$$,
    array['false|10485760|image/jpeg'::text],
    'private JPEG bucket has the documented limit'
);

select results_eq(
    $$select count(*)::bigint from pg_policies
      where schemaname = 'public'
        and tablename = 'tackle_items'
        and policyname like 'tackle_items_%_own'$$,
    array[4::bigint],
    'TackleItem rows have owner-scoped CRUD policies'
);

select results_eq(
    $$select count(*)::bigint from pg_policies
      where schemaname = 'storage'
        and tablename = 'objects'
        and policyname like 'tackle_photo_objects_%_own'$$,
    array[4::bigint],
    'TackleItem photos have owner-scoped Storage policies'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"80000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select lives_ok(
    $$insert into public.tackle_items (
        id, owner_id, name, type, size, color, brand, photo_storage_path
      ) values (
        '80000000-0000-0000-0000-000000000011',
        '80000000-0000-0000-0000-000000000001',
        'Green Pumpkin Senko', 'soft_plastic', '5"', 'Green Pumpkin', 'Yamamoto',
        '80000000-0000-0000-0000-000000000001/80000000-0000-0000-0000-000000000011/80000000-0000-0000-0000-000000000021.jpg'
      )$$,
    'owner can create a complete TackleItem'
);

select throws_ok(
    $$insert into public.tackle_items (id, owner_id, name, type)
      values (
        '80000000-0000-0000-0000-000000000012',
        '80000000-0000-0000-0000-000000000001',
        ' untrimmed ', 'jig'
      )$$,
    '23514',
    null,
    'item names must be nonblank and trimmed'
);

select throws_ok(
    $$update public.tackle_items
      set photo_storage_path = 'wrong/path/photo.jpg'
      where id = '80000000-0000-0000-0000-000000000011'$$,
    '23514',
    null,
    'photo metadata rejects a noncanonical path'
);

select lives_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, tackle_item_id)
      values (
        '80000000-0000-0000-0000-000000000031',
        '80000000-0000-0000-0000-000000000001',
        'Bass', now(), '80000000-0000-0000-0000-000000000011'
      )$$,
    'a Catch can reference its owners item'
);

select throws_ok(
    $$delete from public.tackle_items
      where id = '80000000-0000-0000-0000-000000000011'$$,
    '23503',
    null,
    'a historically referenced item cannot be hard deleted'
);

select results_eq(
    $$with changed as (
        update public.tackle_items set archived = true, version = 2, updated_at = now()
        where id = '80000000-0000-0000-0000-000000000011'
        returning id
      ) select count(*)::bigint from changed$$,
    array[1::bigint],
    'archive preserves the referenced item row'
);

select lives_ok(
    $$insert into storage.objects (bucket_id, name, owner_id, metadata)
      values (
        'tackle-photos',
        '80000000-0000-0000-0000-000000000001/80000000-0000-0000-0000-000000000011/80000000-0000-0000-0000-000000000021.jpg',
        '80000000-0000-0000-0000-000000000001',
        '{"mimetype":"image/jpeg"}'
      )$$,
    'owner can create canonical tackle photo metadata'
);

select results_eq(
    $$select count(*)::bigint from storage.objects where bucket_id = 'tackle-photos'$$,
    array[1::bigint],
    'owner can list the private tackle photo'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"80000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);

select results_eq(
    $$select count(*)::bigint from public.tackle_items$$,
    array[0::bigint],
    'another owner cannot list TackleItems'
);

select results_eq(
    $$with changed as (
        update public.tackle_items set archived = false
        where id = '80000000-0000-0000-0000-000000000011'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'another owner cannot edit a TackleItem'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, tackle_item_id)
      values (
        '80000000-0000-0000-0000-000000000032',
        '80000000-0000-0000-0000-000000000002',
        'Trout', now(), '80000000-0000-0000-0000-000000000011'
      )$$,
    '23503',
    null,
    'the composite foreign key rejects a cross-owner item reference'
);

select throws_ok(
    $$insert into storage.objects (bucket_id, name, owner_id, metadata)
      values (
        'tackle-photos',
        '80000000-0000-0000-0000-000000000001/80000000-0000-0000-0000-000000000011/80000000-0000-0000-0000-000000000022.jpg',
        '80000000-0000-0000-0000-000000000002',
        '{"mimetype":"image/jpeg"}'
      )$$,
    '42501',
    null,
    'another owner cannot write beneath the first owners photo path'
);

select throws_ok(
    $$insert into public.tackle_items (id, owner_id, name, type)
      values (
        '80000000-0000-0000-0000-000000000013',
        '80000000-0000-0000-0000-000000000001',
        'Stolen item', 'other'
      )$$,
    '42501',
    null,
    'RLS rejects creating an item for another owner'
);

select results_eq(
    $$select count(*)::bigint from storage.objects where bucket_id = 'tackle-photos'$$,
    array[0::bigint],
    'another owner cannot list tackle photo objects'
);

select * from finish();

rollback;
