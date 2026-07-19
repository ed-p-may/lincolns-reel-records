create schema if not exists private;

revoke all on schema private from public, anon, authenticated;

create table public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    username text not null,
    created_at timestamptz not null default now(),
    constraint profiles_username_valid check (
        username = btrim(username)
        and char_length(username) between 1 and 40
    )
);

create table public.catches (
    id uuid primary key,
    owner_id uuid not null references auth.users (id) on delete cascade,
    species text not null,
    caught_at timestamptz not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint catches_species_valid check (
        species = btrim(species)
        and char_length(species) between 1 and 80
    )
);

create index catches_owner_caught_at_idx
    on public.catches (owner_id, caught_at desc);

alter table public.profiles enable row level security;
alter table public.catches enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.catches from anon, authenticated;

grant select, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.catches to authenticated;

create policy "profiles_select_own"
    on public.profiles
    for select
    to authenticated
    using ((select auth.uid()) = id);

create policy "profiles_update_own"
    on public.profiles
    for update
    to authenticated
    using ((select auth.uid()) = id)
    with check ((select auth.uid()) = id);

create policy "catches_select_own"
    on public.catches
    for select
    to authenticated
    using ((select auth.uid()) = owner_id);

create policy "catches_insert_own"
    on public.catches
    for insert
    to authenticated
    with check ((select auth.uid()) = owner_id);

create policy "catches_update_own"
    on public.catches
    for update
    to authenticated
    using ((select auth.uid()) = owner_id)
    with check ((select auth.uid()) = owner_id);

create policy "catches_delete_own"
    on public.catches
    for delete
    to authenticated
    using ((select auth.uid()) = owner_id);

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    requested_username text := btrim(new.raw_user_meta_data ->> 'username');
begin
    if requested_username is null or char_length(requested_username) not between 1 and 40 then
        raise exception 'A username between 1 and 40 characters is required.'
            using errcode = '22023';
    end if;

    insert into public.profiles (id, username, created_at)
    values (new.id, requested_username, coalesce(new.created_at, now()));

    return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function private.handle_new_user();
