begin;

select plan(5);

insert into auth.users (id, email, raw_user_meta_data)
values
    ('a0000000-0000-0000-0000-000000000001', 'phase10-a@example.com', '{"username":"phase10_a"}'),
    ('a0000000-0000-0000-0000-000000000002', 'phase10-b@example.com', '{"username":"phase10_b"}');

set local role authenticated;
select set_config(
    'request.jwt.claims',
    '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);

select lives_ok(
    $$insert into public.catches (id, owner_id, species, caught_at)
      values (
        'a0000000-0000-0000-0000-000000000011',
        'a0000000-0000-0000-0000-000000000001',
        'Brook Trout', now()
      )$$,
    'bookmark defaults without changing catch creation'
);

select results_eq(
    $$select bookmarked from public.catches
      where id = 'a0000000-0000-0000-0000-000000000011'$$,
    array[false],
    'bookmark defaults false'
);

select lives_ok(
    $$update public.catches set bookmarked = true, version = 2
      where id = 'a0000000-0000-0000-0000-000000000011' and version = 1$$,
    'owner can save a catch through existing optimistic update behavior'
);

select results_eq(
    $$select bookmarked from public.catches
      where id = 'a0000000-0000-0000-0000-000000000011'$$,
    array[true],
    'saved state persists'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"a0000000-0000-0000-0000-000000000002","role":"authenticated"}',
    true
);

select results_eq(
    $$with changed as (
        update public.catches set bookmarked = false, version = 3
        where id = 'a0000000-0000-0000-0000-000000000011'
        returning id
      ) select count(*)::bigint from changed$$,
    array[0::bigint],
    'another owner cannot change saved state'
);

select * from finish();

rollback;
