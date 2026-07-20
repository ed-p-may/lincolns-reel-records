alter table public.profiles
    add column display_name text,
    add column home_water text,
    add column avatar_storage_path text unique,
    add column angler_since integer,
    add column updated_at timestamptz not null default now(),
    add column version bigint not null default 1;

alter table public.profiles
    add constraint profiles_display_name_valid check (
        display_name is null or (
            display_name = btrim(display_name)
            and char_length(display_name) between 1 and 80
        )
    ),
    add constraint profiles_home_water_valid check (
        home_water is null or (
            home_water = btrim(home_water)
            and char_length(home_water) between 1 and 120
        )
    ),
    add constraint profiles_angler_since_valid check (
        angler_since is null or angler_since between 1900 and extract(year from current_date)::integer
    ),
    add constraint profiles_avatar_storage_path_valid check (
        avatar_storage_path is null or (
            avatar_storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
            and split_part(avatar_storage_path, '/', 1) = lower(id::text)
        )
    ),
    add constraint profiles_version_valid check (version > 0);

create function private.prevent_profile_identity_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    if new.id is distinct from old.id
        or new.username is distinct from old.username
        or new.created_at is distinct from old.created_at
    then
        raise exception 'Profile identity fields are server-managed.'
            using errcode = '42501';
    end if;
    return new;
end;
$$;

revoke all on function private.prevent_profile_identity_update() from public, anon, authenticated;

create trigger prevent_profile_identity_update
    before update on public.profiles
    for each row execute function private.prevent_profile_identity_update();

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 10485760, array['image/jpeg'])
on conflict (id) do update set
    public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create function private.avatar_object_is_owned(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select
        object_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
        and split_part(object_name, '/', 1) = lower((select auth.uid())::text)
$$;

revoke all on function private.avatar_object_is_owned(text) from public, anon;
grant execute on function private.avatar_object_is_owned(text) to authenticated;

create policy "avatar_objects_select_own"
    on storage.objects
    for select
    to authenticated
    using (
        bucket_id = 'avatars'
        and private.avatar_object_is_owned(name)
    );

create policy "avatar_objects_insert_own"
    on storage.objects
    for insert
    to authenticated
    with check (
        bucket_id = 'avatars'
        and private.avatar_object_is_owned(name)
    );

create policy "avatar_objects_update_own"
    on storage.objects
    for update
    to authenticated
    using (
        bucket_id = 'avatars'
        and private.avatar_object_is_owned(name)
    )
    with check (
        bucket_id = 'avatars'
        and private.avatar_object_is_owned(name)
    );

create policy "avatar_objects_delete_own"
    on storage.objects
    for delete
    to authenticated
    using (
        bucket_id = 'avatars'
        and private.avatar_object_is_owned(name)
    );
