-- Supabase setup for MiraNet: profiles table, policies, and avatars bucket policies

-- 1) Profiles table
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  username text unique,
  avatar_path text,
  updated_at timestamptz default now()
);

-- If the table already existed without some columns, patch it in place
alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists username text;
alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles add column if not exists updated_at timestamptz default now();
alter table public.profiles add column if not exists last_username_change_at timestamptz;
alter table public.profiles add column if not exists last_display_name_change_at timestamptz;
alter table public.profiles add column if not exists is_private boolean default false;
alter table public.profiles add column if not exists messages_followers_only boolean default false;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_username_key'
  ) then
    alter table public.profiles add constraint profiles_username_key unique (username);
  end if;
end $$;

alter table public.profiles enable row level security;

-- Policies: read for everyone (so search works), insert/update only by the owner
-- Profiles visibility: allow anon to read all; authenticated users cannot see users they blocked or who blocked them
drop policy if exists "Profiles are viewable by everyone" on public.profiles;
drop policy if exists "Profiles view (anon)" on public.profiles;
drop policy if exists "Profiles view (auth not blocked)" on public.profiles;
create policy "Profiles view (anon)"
  on public.profiles for select
  using (auth.uid() is null);

create policy "Profiles view (auth not blocked)"
  on public.profiles for select
  using (
    auth.uid() is not null
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = id
    )
    and not exists (
      select 1 from public.blocks b2
      where b2.blocker_id = id and b2.blocked_id = auth.uid()
    )
  );

drop policy if exists "Users can insert their own profile" on public.profiles;
create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Optional: indexes to speed up ILIKE searches
create extension if not exists pg_trgm with schema public;
create index if not exists profiles_display_name_trgm on public.profiles using gin (display_name gin_trgm_ops);
create index if not exists profiles_username_trgm on public.profiles using gin (username gin_trgm_ops);

-- Tip: If the API still reports missing columns after running this, go to
-- Project Settings -> API -> click "Reset API cache" to refresh PostgREST schema cache.

-- 2) Storage policies for avatars bucket
-- Create the bucket manually in Storage UI named: avatars (public=false recommended)

-- RLS on storage.objects is enabled by default; add policies scoped to this bucket.
-- Allow anyone to read if you want public avatars without signed URLs.
-- If you prefer signed URLs only, you can skip this select policy.
-- Note: signed URLs work even without a public select policy.
drop policy if exists "Avatars are publicly readable" on storage.objects;
create policy "Avatars are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

-- Allow authenticated users to insert/update/delete only within their own folder: <uid>/...
drop policy if exists "Users can insert their own avatars" on storage.objects;
create policy "Users can insert their own avatars"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = split_part(name, '/', 1)
  );

drop policy if exists "Users can update their own avatars" on storage.objects;
create policy "Users can update their own avatars"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = split_part(name, '/', 1)
  )
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = split_part(name, '/', 1)
  );

drop policy if exists "Users can delete their own avatars" on storage.objects;
create policy "Users can delete their own avatars"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = split_part(name, '/', 1)
  );

-- Done.

-- 3) Posts
create extension if not exists pgcrypto with schema public;
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  image_path text not null,
  caption text,
  filter_name text,
  music_path text,
  created_at timestamptz not null default now()
);

-- Patch existing posts table if columns are missing
alter table public.posts add column if not exists user_id uuid;
alter table public.posts add column if not exists image_path text;
alter table public.posts add column if not exists caption text;
alter table public.posts add column if not exists filter_name text;
alter table public.posts add column if not exists music_path text;
alter table public.posts add column if not exists created_at timestamptz default now();
-- Ensure PK exists on id
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.posts'::regclass
      and contype = 'p'
  ) then
    alter table public.posts add column if not exists id uuid;
    alter table public.posts alter column id set default gen_random_uuid();
    alter table public.posts add primary key (id);
  end if;
end $$;

alter table public.posts enable row level security;

-- Posts visibility: allow anon to read all; authenticated users cannot see posts if blocked either way with the post owner
drop policy if exists "Posts are viewable by everyone" on public.posts;
drop policy if exists "Posts view (anon)" on public.posts;
drop policy if exists "Posts view (auth not blocked)" on public.posts;
create policy "Posts view (anon)"
  on public.posts for select
  using (auth.uid() is null);

create policy "Posts view (auth not blocked)"
  on public.posts for select
  using (
    auth.uid() is not null
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = auth.uid() and b.blocked_id = user_id
    )
    and not exists (
      select 1 from public.blocks b2
      where b2.blocker_id = user_id and b2.blocked_id = auth.uid()
    )
  );

drop policy if exists "Users can insert their own posts" on public.posts;
create policy "Users can insert their own posts"
  on public.posts for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own posts" on public.posts;
create policy "Users can update their own posts"
  on public.posts for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Users can delete their own posts" on public.posts;
create policy "Users can delete their own posts"
  on public.posts for delete to authenticated
  using (auth.uid() = user_id);

-- Storage bucket for posts (create in UI as: posts)
-- Optional public read; signed URLs also work without public policy
drop policy if exists "Posts are publicly readable" on storage.objects;
create policy "Posts are publicly readable"
  on storage.objects for select
  using (bucket_id = 'posts');

drop policy if exists "Users can insert their own posts files" on storage.objects;
create policy "Users can insert their own posts files"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'posts'
    and auth.uid()::text = split_part(name, '/', 1)
  );

drop policy if exists "Users can update their own posts files" on storage.objects;
create policy "Users can update their own posts files"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'posts'
    and auth.uid()::text = split_part(name, '/', 1)
  )
  with check (
    bucket_id = 'posts'
    and auth.uid()::text = split_part(name, '/', 1)
  );

drop policy if exists "Users can delete their own posts files" on storage.objects;
create policy "Users can delete their own posts files"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'posts'
    and auth.uid()::text = split_part(name, '/', 1)
  );

-- 4) Follows (followers/following)
create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint follows_pkey primary key (follower_id, following_id),
  constraint follows_self_check check (follower_id <> following_id)
);

alter table public.follows enable row level security;

drop policy if exists "Follows are viewable by everyone" on public.follows;
drop policy if exists "Follows view (anon)" on public.follows;
drop policy if exists "Follows view (auth not blocked)" on public.follows;
create policy "Follows view (anon)"
  on public.follows for select
  using (auth.uid() is null);

create policy "Follows view (auth not blocked)"
  on public.follows for select
  using (
    auth.uid() is not null
    and not exists (
      select 1 from public.blocks b
      where b.blocker_id = auth.uid() and (b.blocked_id = follower_id or b.blocked_id = following_id)
    )
    and not exists (
      select 1 from public.blocks b2
      where (b2.blocker_id = follower_id or b2.blocker_id = following_id) and b2.blocked_id = auth.uid()
    )
  );

drop policy if exists "Users can follow (insert) as themselves" on public.follows;
create policy "Users can follow (insert) as themselves"
  on public.follows for insert to authenticated
  with check (auth.uid() = follower_id);

drop policy if exists "Users can unfollow (delete) as themselves" on public.follows;
create policy "Users can unfollow (delete) as themselves"
  on public.follows for delete to authenticated
  using (auth.uid() = follower_id);

create index if not exists follows_following_idx on public.follows (following_id);
create index if not exists follows_follower_idx on public.follows (follower_id);

-- 5) RPCs for counts and follow state
create or replace function public.posts_count(p_user uuid)
returns bigint language sql stable as $$
  select count(*) from public.posts where user_id = p_user;
$$;

create or replace function public.followers_count(p_user uuid)
returns bigint language sql stable as $$
  select count(*) from public.follows where following_id = p_user;
$$;

-- 6) Blocks (user blocking)
create table if not exists public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint blocks_pkey primary key (blocker_id, blocked_id),
  constraint blocks_self_check check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

drop policy if exists "Blocks are visible to blocker" on public.blocks;
create policy "Blocks are visible to blocker"
  on public.blocks for select
  using (auth.uid() = blocker_id);

drop policy if exists "Users can block" on public.blocks;
create policy "Users can block"
  on public.blocks for insert to authenticated
  with check (auth.uid() = blocker_id);

drop policy if exists "Users can unblock" on public.blocks;
create policy "Users can unblock"
  on public.blocks for delete to authenticated
  using (auth.uid() = blocker_id);

create index if not exists blocks_blocker_idx on public.blocks (blocker_id);
create index if not exists blocks_blocked_idx on public.blocks (blocked_id);

create or replace function public.following_count(p_user uuid)
returns bigint language sql stable as $$
  select count(*) from public.follows where follower_id = p_user;
$$;

create or replace function public.is_following(p_follower uuid, p_following uuid)
returns boolean language sql stable as $$
  select exists(
    select 1 from public.follows
    where follower_id = p_follower and following_id = p_following
  );
$$;

-- 7) Direct messages (chats)
create table if not exists public.chats (
  id uuid primary key default gen_random_uuid(),
  is_direct boolean not null default true,
  direct_key text unique, -- for direct chats: least(uid1,uid2)||':'||greatest(uid1,uid2)
  created_at timestamptz not null default now()
);

create table if not exists public.chat_members (
  chat_id uuid not null references public.chats(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  constraint chat_members_pkey primary key (chat_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()
);

alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;

-- Chats: visible to members
drop policy if exists "Chats view (members)" on public.chats;
create policy "Chats view (members)"
  on public.chats for select using (
    exists (
      select 1 from public.chat_members cm
      where cm.chat_id = id and cm.user_id = auth.uid()
    )
  );

-- Allow creating chats (authenticated)
drop policy if exists "Chats insert (auth)" on public.chats;
create policy "Chats insert (auth)"
  on public.chats for insert to authenticated
  with check (true);

-- Chat members: visible to members
drop policy if exists "Chat members view (self only)" on public.chat_members;
drop policy if exists "Chat members view (members)" on public.chat_members;
create policy "Chat members view (self only)"
  on public.chat_members for select using (
    user_id = auth.uid()
  );

-- Insert membership for self, and allow adding other member if already a member of the chat
drop policy if exists "Chat members insert (self or by member)" on public.chat_members;
drop policy if exists "Chat members insert (self only)" on public.chat_members;
create policy "Chat members insert (self only)"
  on public.chat_members for insert to authenticated
  with check (user_id = auth.uid());

-- Messages: visible to members and not blocked either way
drop policy if exists "Messages view (members not blocked)" on public.messages;
create policy "Messages view (members not blocked)"
  on public.messages for select using (
    exists (
      select 1 from public.chat_members cm
      where cm.chat_id = chat_id and cm.user_id = auth.uid()
    )
    and not exists (
      select 1 from public.chat_members other
      where other.chat_id = chat_id and other.user_id <> auth.uid()
        and exists (
          select 1 from public.blocks b
          where (b.blocker_id = auth.uid() and b.blocked_id = other.user_id)
             or (b.blocker_id = other.user_id and b.blocked_id = auth.uid())
        )
    )
  );

-- Messages: insert by members only and not blocked either way
drop policy if exists "Messages insert (member not blocked)" on public.messages;
create policy "Messages insert (member not blocked)"
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.chat_members cm
      where cm.chat_id = chat_id and cm.user_id = auth.uid()
    )
    and not exists (
      select 1 from public.chat_members other
      where other.chat_id = chat_id and other.user_id <> auth.uid()
        and exists (
          select 1 from public.blocks b
          where (b.blocker_id = auth.uid() and b.blocked_id = other.user_id)
             or (b.blocker_id = other.user_id and b.blocked_id = auth.uid())
        )
    )
  );

create index if not exists chat_members_user_idx on public.chat_members(user_id);
create index if not exists chat_members_chat_idx on public.chat_members(chat_id);
create index if not exists messages_chat_idx on public.messages(chat_id);
create index if not exists messages_sender_idx on public.messages(sender_id);

-- RPC: ensure_direct_chat - creates or returns a direct chat between auth.uid() and p_other
create or replace function public.ensure_direct_chat(p_other uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_key text;
  v_chat uuid;
begin
  if v_me is null then
    raise exception 'not signed in';
  end if;
  if p_other is null or p_other = v_me then
    raise exception 'invalid target';
  end if;
  if v_me < p_other then
    v_key := v_me::text || ':' || p_other::text;
  else
    v_key := p_other::text || ':' || v_me::text;
  end if;
  select id into v_chat from public.chats where direct_key = v_key;
  if v_chat is null then
    insert into public.chats (is_direct, direct_key) values (true, v_key) returning id into v_chat;
    insert into public.chat_members (chat_id, user_id) values (v_chat, v_me) on conflict do nothing;
    insert into public.chat_members (chat_id, user_id) values (v_chat, p_other) on conflict do nothing;
  end if;
  return v_chat;
end;
$$;

grant execute on function public.ensure_direct_chat(uuid) to authenticated;

-- RPC: get_chat_peer - returns the other member's user_id for a direct chat
create or replace function public.get_chat_peer(p_chat uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_peer uuid;
begin
  if v_me is null then
    return null;
  end if;
  if not exists (
    select 1 from public.chat_members m where m.chat_id = p_chat and m.user_id = v_me
  ) then
    return null;
  end if;
  select user_id into v_peer from public.chat_members where chat_id = p_chat and user_id <> v_me limit 1;
  return v_peer;
end;
$$;

grant execute on function public.get_chat_peer(uuid) to authenticated;

-- 8) Post tags (tag people) and Polls
create table if not exists public.post_tags (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint post_tags_pkey primary key (post_id, user_id)
);

alter table public.post_tags enable row level security;

-- Tag rows are visible when the post is visible
drop policy if exists "Post tags view (post visible)" on public.post_tags;
create policy "Post tags view (post visible)"
  on public.post_tags for select using (
    exists (
      select 1 from public.posts p
      where p.id = post_id
        and (
          auth.uid() is null
          or (
            auth.uid() is not null
            and not exists (
              select 1 from public.blocks b
              where b.blocker_id = auth.uid() and b.blocked_id = p.user_id
            )
            and not exists (
              select 1 from public.blocks b2
              where b2.blocker_id = p.user_id and b2.blocked_id = auth.uid()
            )
          )
        )
    )
  );

-- Only post owner can add/remove tags
drop policy if exists "Post tags insert (owner)" on public.post_tags;
create policy "Post tags insert (owner)"
  on public.post_tags for insert to authenticated
  with check (
    exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid())
  );

drop policy if exists "Post tags delete (owner)" on public.post_tags;
create policy "Post tags delete (owner)"
  on public.post_tags for delete to authenticated
  using (
    exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid())
  );

create table if not exists public.posts_polls (
  post_id uuid primary key references public.posts(id) on delete cascade,
  question text not null
);

create table if not exists public.posts_poll_options (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  text text not null
);

create table if not exists public.posts_poll_votes (
  post_id uuid not null references public.posts(id) on delete cascade,
  option_id uuid not null references public.posts_poll_options(id) on delete cascade,
  voter_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint posts_poll_votes_pkey primary key (post_id, voter_id)
);

alter table public.posts_polls enable row level security;
alter table public.posts_poll_options enable row level security;
alter table public.posts_poll_votes enable row level security;

-- Visibility mirrors post visibility
drop policy if exists "Poll view (post visible)" on public.posts_polls;
create policy "Poll view (post visible)"
  on public.posts_polls for select using (
    exists (select 1 from public.posts p where p.id = post_id)
  );

drop policy if exists "Poll options view (post visible)" on public.posts_poll_options;
create policy "Poll options view (post visible)"
  on public.posts_poll_options for select using (
    exists (select 1 from public.posts p where p.id = post_id)
  );

drop policy if exists "Poll votes view (post visible)" on public.posts_poll_votes;
create policy "Poll votes view (post visible)"
  on public.posts_poll_votes for select using (
    exists (select 1 from public.posts p where p.id = post_id)
  );

-- Create/modify poll by post owner
drop policy if exists "Poll create (owner)" on public.posts_polls;
create policy "Poll create (owner)"
  on public.posts_polls for insert to authenticated
  with check (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));

drop policy if exists "Poll options insert (owner)" on public.posts_poll_options;
create policy "Poll options insert (owner)"
  on public.posts_poll_options for insert to authenticated
  with check (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));

drop policy if exists "Poll options delete (owner)" on public.posts_poll_options;
create policy "Poll options delete (owner)"
  on public.posts_poll_options for delete to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id and p.user_id = auth.uid()));

-- Vote: one per user per post
drop policy if exists "Poll vote (auth)" on public.posts_poll_votes;
create policy "Poll vote (auth)"
  on public.posts_poll_votes for insert to authenticated
  with check (
    auth.uid() = voter_id
    and not exists (
      select 1 from public.posts_poll_votes v where v.post_id = post_id and v.voter_id = auth.uid()
    )
  );

create index if not exists post_tags_post_idx on public.post_tags(post_id);
create index if not exists post_tags_user_idx on public.post_tags(user_id);
create index if not exists poll_options_post_idx on public.posts_poll_options(post_id);
create index if not exists poll_votes_post_idx on public.posts_poll_votes(post_id);

