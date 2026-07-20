create type public.tackle_item_type as enum (
    'soft_plastic',
    'crankbait',
    'spinnerbait',
    'jig',
    'topwater',
    'spoon',
    'fly',
    'live_bait',
    'other'
);

create table public.tackle_items (
    id uuid primary key,
    owner_id uuid not null references auth.users (id) on delete cascade,
    name text not null,
    type public.tackle_item_type not null,
    size text,
    color text,
    brand text,
    photo_storage_path text unique,
    archived boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    deleted_at timestamptz,
    version bigint not null default 1,
    constraint tackle_items_identity_owner_unique unique (id, owner_id),
    constraint tackle_items_name_valid check (
        name = btrim(name) and char_length(name) between 1 and 160
    ),
    constraint tackle_items_size_valid check (
        size is null or (size = btrim(size) and char_length(size) between 1 and 80)
    ),
    constraint tackle_items_color_valid check (
        color is null or (color = btrim(color) and char_length(color) between 1 and 80)
    ),
    constraint tackle_items_brand_valid check (
        brand is null or (brand = btrim(brand) and char_length(brand) between 1 and 120)
    ),
    constraint tackle_items_photo_path_valid check (
        photo_storage_path is null or (
            photo_storage_path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
            and split_part(photo_storage_path, '/', 1) = lower(owner_id::text)
            and split_part(photo_storage_path, '/', 2) = lower(id::text)
        )
    ),
    constraint tackle_items_version_valid check (version > 0)
);

create index tackle_items_owner_active_idx
    on public.tackle_items (owner_id, archived, updated_at desc)
    where deleted_at is null;

create index tackle_items_owner_deleted_idx
    on public.tackle_items (owner_id, deleted_at)
    where deleted_at is not null;

alter table public.tackle_items enable row level security;

revoke all on table public.tackle_items from anon, authenticated;
grant select, insert, update, delete on table public.tackle_items to authenticated;

create policy "tackle_items_select_own"
    on public.tackle_items
    for select
    to authenticated
    using (owner_id = (select auth.uid()));

create policy "tackle_items_insert_own"
    on public.tackle_items
    for insert
    to authenticated
    with check (owner_id = (select auth.uid()));

create policy "tackle_items_update_own"
    on public.tackle_items
    for update
    to authenticated
    using (owner_id = (select auth.uid()))
    with check (owner_id = (select auth.uid()));

create policy "tackle_items_delete_own"
    on public.tackle_items
    for delete
    to authenticated
    using (owner_id = (select auth.uid()));

alter table public.catches
    add column tackle_item_id uuid,
    add constraint catches_tackle_item_owner_fkey
        foreign key (tackle_item_id, owner_id)
        references public.tackle_items (id, owner_id)
        on delete restrict;

create index catches_tackle_item_idx
    on public.catches (owner_id, tackle_item_id)
    where tackle_item_id is not null and deleted_at is null;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('tackle-photos', 'tackle-photos', false, 10485760, array['image/jpeg'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create function private.owns_tackle_photo_object(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select object_name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$'
       and split_part(object_name, '/', 1) = lower((select auth.uid())::text);
$$;

revoke all on function private.owns_tackle_photo_object(text) from public, anon;
grant execute on function private.owns_tackle_photo_object(text) to authenticated;

create policy "tackle_photo_objects_select_own"
    on storage.objects
    for select
    to authenticated
    using (bucket_id = 'tackle-photos' and private.owns_tackle_photo_object(name));

create policy "tackle_photo_objects_insert_own"
    on storage.objects
    for insert
    to authenticated
    with check (bucket_id = 'tackle-photos' and private.owns_tackle_photo_object(name));

create policy "tackle_photo_objects_update_own"
    on storage.objects
    for update
    to authenticated
    using (bucket_id = 'tackle-photos' and private.owns_tackle_photo_object(name))
    with check (bucket_id = 'tackle-photos' and private.owns_tackle_photo_object(name));

create policy "tackle_photo_objects_delete_own"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'tackle-photos' and private.owns_tackle_photo_object(name));
