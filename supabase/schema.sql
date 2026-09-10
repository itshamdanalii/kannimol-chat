-- Kanni Mol Chat database contract
-- Run this in Supabase SQL editor. Never put a service-role key in the frontend.
extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username = lower(username) and username ~ '^[a-z0-9_.]{3,24}$'),
  display_name text not null check (char_length(display_name) between 1 and 80),
  avatar_url text,
  bio text check (char_length(coalesce(bio, '')) <= 280),
  is_online boolean not null default false,
  last_seen timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists profiles_username_idx on public.profiles (username);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create index if not exists conversation_members_user_idx on public.conversation_members (user_id);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  content text not null check (char_length(content) between 1 and 4000),
  message_type text not null default 'text' check (message_type in ('text')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  is_read boolean not null default false
);
create index if not exists messages_conversation_idx on public.messages (conversation_id, created_at);

create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reaction text not null check (char_length(reaction) between 1 and 16),
  created_at timestamptz not null default now(),
  unique(message_id, user_id, reaction)
);

create table if not exists public.user_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid());
$$;

create or replace function public.is_conversation_member(target_conversation_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.conversation_members where conversation_id = target_conversation_id and user_id = auth.uid());
$$;

create or replace function public.get_or_create_direct_conversation(target_user_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare conversation_id uuid;
begin
  if auth.uid() is null or target_user_id = auth.uid() then raise exception 'Invalid user'; end if;
  if exists (select 1 from public.user_blocks where (blocker_id = auth.uid() and blocked_id = target_user_id) or (blocker_id = target_user_id and blocked_id = auth.uid())) then raise exception 'This user is unavailable'; end if;
  select cm.conversation_id into conversation_id from public.conversation_members cm where cm.user_id = auth.uid() and exists (select 1 from public.conversation_members other where other.conversation_id = cm.conversation_id and other.user_id = target_user_id) limit 1;
  if conversation_id is null then
    insert into public.conversations default values returning id into conversation_id;
    insert into public.conversation_members(conversation_id, user_id) values (conversation_id, auth.uid()), (conversation_id, target_user_id);
  end if;
  return conversation_id;
end;
$$;
grant execute on function public.get_or_create_direct_conversation(uuid) to authenticated;

create or replace function public.touch_profile_presence(online boolean)
returns void language sql security invoker as $$ update public.profiles set is_online = online, last_seen = now(), updated_at = now() where id = auth.uid(); $$;
grant execute on function public.touch_profile_presence(boolean) to authenticated;

create or replace function public.admin_list_users()
returns table(id uuid, email text, username text, display_name text, provider text)
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'Not authorized'; end if;
  return query select u.id, u.email::text, p.username, p.display_name,
    coalesce(u.raw_app_meta_data->>'provider', 'email')::text
    from auth.users u join public.profiles p on p.id = u.id order by p.created_at desc;
end;
$$;
grant execute on function public.admin_list_users() to authenticated;

create or replace function public.update_conversation_timestamp()
returns trigger language plpgsql as $$ begin update public.conversations set updated_at = now() where id = new.conversation_id; return new; end; $$;
drop trigger if exists messages_update_conversation on public.messages;
create trigger messages_update_conversation after insert on public.messages for each row execute procedure public.update_conversation_timestamp();

alter table public.profiles enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.user_blocks enable row level security;
alter table public.app_admins enable row level security;

drop policy if exists profiles_public_read on public.profiles;
create policy profiles_public_read on public.profiles for select to authenticated using (true);
drop policy if exists profiles_self_update on public.profiles;
create policy profiles_self_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists profiles_self_insert on public.profiles;
create policy profiles_self_insert on public.profiles for insert to authenticated with check (id = auth.uid());

drop policy if exists member_read on public.conversation_members;
create policy member_read on public.conversation_members for select to authenticated using (user_id = auth.uid() or exists (select 1 from public.conversation_members own where own.conversation_id = conversation_id and own.user_id = auth.uid()));
drop policy if exists conversation_read on public.conversations;
drop policy if exists member_read on public.conversation_members;
create policy member_read on public.conversation_members for select to authenticated using (public.is_conversation_member(conversation_id));
drop policy if exists conversation_read on public.conversations;
create policy conversation_read on public.conversations for select to authenticated using (public.is_conversation_member(id));
drop policy if exists message_read on public.messages;
create policy message_read on public.messages for select to authenticated using (public.is_conversation_member(conversation_id));
drop policy if exists message_send on public.messages;
create policy message_send on public.messages for insert to authenticated with check (sender_id = auth.uid() and public.is_conversation_member(conversation_id) and not exists (select 1 from public.conversation_members other join public.user_blocks b on b.blocked_id = other.user_id and b.blocker_id = auth.uid() where other.conversation_id = messages.conversation_id));
drop policy if exists message_read_update on public.messages;
revoke update on public.messages from authenticated;
grant update (is_read) on public.messages to authenticated;
create policy message_read_update on public.messages for update to authenticated using (public.is_conversation_member(conversation_id)) with check (public.is_conversation_member(conversation_id));

drop policy if exists reactions_member on public.message_reactions;
create policy reactions_member on public.message_reactions for all to authenticated using (user_id = auth.uid() and exists (select 1 from public.messages m join public.conversation_members cm on cm.conversation_id = m.conversation_id where m.id = message_id and cm.user_id = auth.uid())) with check (user_id = auth.uid());
drop policy if exists blocks_self on public.user_blocks;
create policy blocks_self on public.user_blocks for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());
create policy admins_self_read on public.app_admins for select to authenticated using (user_id = auth.uid());

-- Storage: create a public bucket named avatars in the dashboard, then apply these policies.
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
create policy avatar_read on storage.objects for select to authenticated using (bucket_id = 'avatars');
create policy avatar_upload on storage.objects for insert to authenticated with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatar_update on storage.objects for update to authenticated using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Admin access is backend-enforced: insert an admin user id manually from a trusted SQL session.
-- insert into public.app_admins(user_id) values ('AUTH_USER_UUID');
