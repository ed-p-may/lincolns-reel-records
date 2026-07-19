create table public.catch_photos (
    id uuid primary key,
    catch_id uuid not null references public.catches (id) on delete cascade,
    storage_path text not null unique,
    position integer not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    version bigint not null default 1,
    constraint catch_photos_position_valid check (position >= 0),
    constraint catch_photos_version_valid check (version > 0)
);

create index catch_photos_catch_position_idx
    on public.catch_photos (catch_id, position, created_at, id)
    where deleted_at is null;

create index catch_photos_catch_updated_at_idx
    on public.catch_photos (catch_id, updated_at desc);

create function private.catch_photo_path_is_valid(
    photo_id uuid,
    parent_catch_id uuid,
    object_path text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.catches
        where id = parent_catch_id
          and object_path = concat(
              lower(owner_id::text), '/',
              lower(parent_catch_id::text), '/',
              lower(photo_id::text), '.jpg'
          )
    );
$$;

revoke all on function private.catch_photo_path_is_valid(uuid, uuid, text)
    from public, anon;
grant execute on function private.catch_photo_path_is_valid(uuid, uuid, text)
    to authenticated;

alter table public.catch_photos
    add constraint catch_photos_storage_path_valid check (
        private.catch_photo_path_is_valid(id, catch_id, storage_path)
    );

alter table public.catch_photos enable row level security;

revoke all on table public.catch_photos from anon, authenticated;
grant select, insert, update, delete on table public.catch_photos to authenticated;

create policy "catch_photos_select_own"
    on public.catch_photos
    for select
    to authenticated
    using (
        exists (
            select 1 from public.catches
            where catches.id = catch_photos.catch_id
              and catches.owner_id = (select auth.uid())
        )
    );

create policy "catch_photos_insert_own"
    on public.catch_photos
    for insert
    to authenticated
    with check (
        exists (
            select 1 from public.catches
            where catches.id = catch_photos.catch_id
              and catches.owner_id = (select auth.uid())
        )
    );

create policy "catch_photos_update_own"
    on public.catch_photos
    for update
    to authenticated
    using (
        exists (
            select 1 from public.catches
            where catches.id = catch_photos.catch_id
              and catches.owner_id = (select auth.uid())
        )
    )
    with check (
        exists (
            select 1 from public.catches
            where catches.id = catch_photos.catch_id
              and catches.owner_id = (select auth.uid())
        )
    );

create policy "catch_photos_delete_own"
    on public.catch_photos
    for delete
    to authenticated
    using (
        exists (
            select 1 from public.catches
            where catches.id = catch_photos.catch_id
              and catches.owner_id = (select auth.uid())
        )
    );

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('catch-photos', 'catch-photos', false, 10485760, array['image/jpeg'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create function private.owns_catch_photo_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select case
        when object_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
        then exists (
            select 1
            from public.catches
            where owner_id = (select auth.uid())
              and lower(owner_id::text) = split_part(object_name, '/', 1)
              and lower(id::text) = split_part(object_name, '/', 2)
        )
        else false
    end;
$$;

revoke all on function private.owns_catch_photo_object(text) from public, anon;
grant execute on function private.owns_catch_photo_object(text) to authenticated;

create policy "catch_photo_objects_select_own"
    on storage.objects
    for select
    to authenticated
    using (bucket_id = 'catch-photos' and private.owns_catch_photo_object(name));

create policy "catch_photo_objects_insert_own"
    on storage.objects
    for insert
    to authenticated
    with check (bucket_id = 'catch-photos' and private.owns_catch_photo_object(name));

create policy "catch_photo_objects_update_own"
    on storage.objects
    for update
    to authenticated
    using (bucket_id = 'catch-photos' and private.owns_catch_photo_object(name))
    with check (bucket_id = 'catch-photos' and private.owns_catch_photo_object(name));

create policy "catch_photo_objects_delete_own"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'catch-photos' and private.owns_catch_photo_object(name));
