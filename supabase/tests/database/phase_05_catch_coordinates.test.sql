begin;

select plan(10);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('50000000-0000-0000-0000-000000000001', 'phase5-a@example.com', '{"username":"phase5_a"}'),
    ('50000000-0000-0000-0000-000000000002', 'phase5-b@example.com', '{"username":"phase5_b"}');

select results_eq(
    $$select count(*)::bigint
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'catches'
        and column_name in ('latitude', 'longitude')$$,
    array[2::bigint],
    'phase 05 coordinate columns exist'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"50000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select lives_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, location, latitude, longitude)
      values (
        '50000000-0000-0000-0000-000000000099',
        '50000000-0000-0000-0000-000000000001',
        'Smallmouth Bass', now(), 'Stockbridge Bowl', 42.3169, -73.3226
      )$$,
    'owner can insert a valid coordinate pair'
);

select results_eq(
    $$select concat_ws('|', location, latitude::text, longitude::text)
      from public.catches
      where id = '50000000-0000-0000-0000-000000000099'$$,
    array['Stockbridge Bowl|42.3169|-73.3226'::text],
    'named spot and coordinates persist independently'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, latitude)
      values (
        '50000000-0000-0000-0000-000000000098',
        '50000000-0000-0000-0000-000000000001',
        'Perch', now(), 42
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_coordinate_pair_valid"',
    'latitude without longitude is rejected'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, longitude)
      values (
        '50000000-0000-0000-0000-000000000097',
        '50000000-0000-0000-0000-000000000001',
        'Perch', now(), -73
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_coordinate_pair_valid"',
    'longitude without latitude is rejected'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, latitude, longitude)
      values (
        '50000000-0000-0000-0000-000000000096',
        '50000000-0000-0000-0000-000000000001',
        'Perch', now(), 91, 0
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_latitude_valid"',
    'out-of-range latitude is rejected'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, latitude, longitude)
      values (
        '50000000-0000-0000-0000-000000000095',
        '50000000-0000-0000-0000-000000000001',
        'Perch', now(), 0, -181
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_longitude_valid"',
    'out-of-range longitude is rejected'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at, latitude, longitude)
      values (
        '50000000-0000-0000-0000-000000000094',
        '50000000-0000-0000-0000-000000000001',
        'Perch', now(), 'NaN'::double precision, 0
      )$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_latitude_valid"',
    'non-finite latitude is rejected'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"50000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);

select results_eq(
    $$select count(*)::bigint from public.catches
      where id = '50000000-0000-0000-0000-000000000099'$$,
    array[0::bigint],
    'another owner cannot read catch coordinates'
);

select results_eq(
    $$with changed as (
        update public.catches
        set latitude = 0, longitude = 0
        where id = '50000000-0000-0000-0000-000000000099'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'another owner cannot overwrite catch coordinates'
);

select * from finish();

rollback;
