begin;

select plan(14);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('30000000-0000-0000-0000-000000000001', 'phase2-a@example.com', '{"username":"phase2_a"}'),
    ('30000000-0000-0000-0000-000000000002', 'phase2-b@example.com', '{"username":"phase2_b"}');

select results_eq(
    $$select count(*)::bigint
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'catches'
        and column_name in (
            'weight', 'length', 'location', 'lure_text', 'rod_reel',
            'notes', 'released', 'deleted_at', 'version'
        )$$,
    array[9::bigint],
    'phase 02 catch columns exist'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"30000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select lives_ok(
    $$insert into public.catches (
        id, owner_id, species, weight, length, caught_at, location,
        lure_text, rod_reel, notes, released
      ) values (
        '30000000-0000-0000-0000-000000000099',
        '30000000-0000-0000-0000-000000000001',
        'Largemouth Bass', 4.25, 20.5, now(), 'Stockbridge Bowl',
        'Green pumpkin jig', 'Medium spinning', 'Windy', false
      )$$,
    'owner can insert every scalar catch field'
);

select results_eq(
    $$select concat_ws(
        '|', weight::text, length::text, location, lure_text, rod_reel, notes,
        released::text, version::text, (deleted_at is null)::text
      ) from public.catches
      where id = '30000000-0000-0000-0000-000000000099'$$,
    array['4.25|20.5|Stockbridge Bowl|Green pumpkin jig|Medium spinning|Windy|false|1|true'::text],
    'scalar values and initial sync metadata persist'
);

select results_eq(
    $$with changed as (
        update public.catches
        set notes = 'stale', version = 2
        where id = '30000000-0000-0000-0000-000000000099' and version = 0
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'stale optimistic update changes no row'
);

select results_eq(
    $$with changed as (
        update public.catches
        set notes = 'current', version = 2
        where id = '30000000-0000-0000-0000-000000000099' and version = 1
        returning id
      ) select count(*)::bigint from changed$$,
    array[1::bigint],
    'current optimistic update advances version'
);

select results_eq(
    $$with changed as (
        update public.catches
        set deleted_at = now(), version = 3
        where id = '30000000-0000-0000-0000-000000000099' and version = 2
        returning id
      ) select count(*)::bigint from changed$$,
    array[1::bigint],
    'owner can write a versioned tombstone'
);

select results_eq(
    $$select count(*)::bigint from public.catches
      where id = '30000000-0000-0000-0000-000000000099' and deleted_at is not null$$,
    array[1::bigint],
    'owner can observe the tombstone for recovery'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, weight)
      values (
        '30000000-0000-0000-0000-000000000098',
        '30000000-0000-0000-0000-000000000001',
        'Perch', now(), -0.1
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_weight_valid"',
    'negative weight is rejected'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, length)
      values (
        '30000000-0000-0000-0000-000000000097',
        '30000000-0000-0000-0000-000000000001',
        'Perch', now(), -0.1
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_length_valid"',
    'negative length is rejected'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, weight)
      values (
        '30000000-0000-0000-0000-000000000095',
        '30000000-0000-0000-0000-000000000001',
        'Perch', now(), 'NaN'::double precision
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_weight_valid"',
    'non-finite weight is rejected'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, length)
      values (
        '30000000-0000-0000-0000-000000000094',
        '30000000-0000-0000-0000-000000000001',
        'Perch', now(), 'Infinity'::double precision
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_length_valid"',
    'infinite length is rejected'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, location)
      values (
        '30000000-0000-0000-0000-000000000096',
        '30000000-0000-0000-0000-000000000001',
        'Perch', now(), ' padded '
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_location_valid"',
    'unnormalized location is rejected'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"30000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);

select results_eq(
    $$with changed as (
        update public.catches
        set notes = 'intrusion', deleted_at = null, version = 4
        where id = '30000000-0000-0000-0000-000000000099'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'another owner cannot edit fields or resurrect a tombstone'
);

select results_eq(
    $$select count(*)::bigint from public.catches$$,
    array[0::bigint],
    'another owner cannot read the tombstoned catch'
);

select * from finish();

rollback;
