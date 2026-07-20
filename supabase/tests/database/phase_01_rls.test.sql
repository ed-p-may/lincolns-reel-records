begin;

select plan(9);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('10000000-0000-0000-0000-000000000001', 'angler-a@example.com', '{"username":"angler_a"}'),
    ('20000000-0000-0000-0000-000000000002', 'angler-b@example.com', '{"username":"angler_b"}');

insert into public.catches (id, owner_id, species, caught_at)
values (
    '20000000-0000-0000-0000-000000000099',
    '20000000-0000-0000-0000-000000000002',
    'Smallmouth Bass',
    now()
);

select results_eq(
    $$select count(*)::bigint from public.profiles$$,
    array[2::bigint],
    'signup trigger creates both profiles'
);

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select results_eq(
    $$select username from public.profiles order by username$$,
    array['angler_a'::text],
    'a user sees only their profile'
);

select lives_ok(
    $$insert into public.catches (id, owner_id, species, caught_at)
      values (
        '10000000-0000-0000-0000-000000000099',
        '10000000-0000-0000-0000-000000000001',
        'Largemouth Bass',
        now()
      )$$,
    'a user can insert their own catch'
);

select throws_ok(
    $$insert into public.catches (id, owner_id, species, caught_at)
      values (
        '10000000-0000-0000-0000-000000000098',
        '20000000-0000-0000-0000-000000000002',
        'Walleye',
        now()
      )$$,
    '42501',
    'new row violates row-level security policy for table "catches"',
    'a user cannot insert a catch for another owner'
);

select results_eq(
    $$select species from public.catches order by species$$,
    array['Largemouth Bass'::text],
    'a user sees only their catches'
);

select results_eq(
    $$with changed as (
        update public.catches set species = 'Changed'
        where id = '20000000-0000-0000-0000-000000000099'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'a user cannot update another user catch'
);

select results_eq(
    $$with removed as (
        delete from public.catches
        where id = '20000000-0000-0000-0000-000000000099'
        returning id
      ) select count(*)::bigint from removed$$,
    array[0::bigint],
    'a user cannot delete another user catch'
);

select throws_ok(
    $$update public.catches
      set owner_id = '20000000-0000-0000-0000-000000000002'
      where id = '10000000-0000-0000-0000-000000000099'$$,
    '42501',
    'new row violates row-level security policy for table "catches"',
    'a user cannot transfer catch ownership'
);

select lives_ok(
    $$update public.profiles set display_name = 'Angler A'
      where id = '10000000-0000-0000-0000-000000000001'$$,
    'a user can update their own profile'
);

select * from finish();

rollback;
