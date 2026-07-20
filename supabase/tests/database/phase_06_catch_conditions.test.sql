begin;

select plan(10);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('60000000-0000-0000-0000-000000000001', 'phase6-a@example.com', '{"username":"phase6_a"}'),
    ('60000000-0000-0000-0000-000000000002', 'phase6-b@example.com', '{"username":"phase6_b"}');

select results_eq(
    $$select count(*)::bigint
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'catches'
        and column_name in ('air_temp_f', 'sky_condition', 'water_temp_f', 'water_clarity')$$,
    array[4::bigint],
    'phase 06 condition columns exist'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select lives_ok(
    $$insert into public.catches (
        id, owner_id, species, caught_at, air_temp_f, sky_condition, water_temp_f, water_clarity
      ) values (
        '60000000-0000-0000-0000-000000000099',
        '60000000-0000-0000-0000-000000000001',
        'Smallmouth Bass', now(), 72.5, 'partly_cloudy', 66, 'stained'
      )$$,
    'owner can insert valid observations'
);

select results_eq(
    $$select concat_ws('|', air_temp_f::text, sky_condition, water_temp_f::text, water_clarity)
      from public.catches where id = '60000000-0000-0000-0000-000000000099'$$,
    array['72.5|partly_cloudy|66|stained'::text],
    'all observations persist'
);

select throws_ok(
    $$update public.catches set sky_condition = 'hail'
      where id = '60000000-0000-0000-0000-000000000099'$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_sky_condition_valid"',
    'unsupported sky condition is rejected'
);

select throws_ok(
    $$update public.catches set water_clarity = 'opaque'
      where id = '60000000-0000-0000-0000-000000000099'$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_water_clarity_valid"',
    'unsupported water clarity is rejected'
);

select throws_ok(
    $$update public.catches set air_temp_f = 'NaN'::double precision
      where id = '60000000-0000-0000-0000-000000000099'$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_air_temp_f_finite"',
    'non-finite air temperature is rejected'
);

select throws_ok(
    $$update public.catches set water_temp_f = 'Infinity'::double precision
      where id = '60000000-0000-0000-0000-000000000099'$$,
    '23514',
    'new row for relation "catches" violates check constraint "catches_water_temp_f_finite"',
    'non-finite water temperature is rejected'
);

select lives_ok(
    $$insert into public.catches (id, owner_id, species, caught_at)
      values (
        '60000000-0000-0000-0000-000000000098',
        '60000000-0000-0000-0000-000000000001',
        'Perch', now()
      )$$,
    'all observations remain optional'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"60000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);

select results_eq(
    $$select count(*)::bigint from public.catches
      where id = '60000000-0000-0000-0000-000000000099'$$,
    array[0::bigint],
    'another owner cannot read observations'
);

select results_eq(
    $$with changed as (
        update public.catches set air_temp_f = 0
        where id = '60000000-0000-0000-0000-000000000099'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'another owner cannot overwrite observations'
);

select * from finish();

rollback;
