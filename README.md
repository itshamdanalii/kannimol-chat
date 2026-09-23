# Kanni Mol Chat

A mobile-first, real-time one-to-one chat app built with React, Vite, TypeScript, and Supabase.

## Local setup

1. Install Node.js 20+.
2. Run `npm install`.
3. Copy `.env.example` to `.env.local` and add the Supabase project URL and anon key.
4. Run `supabase/schema.sql` in the Supabase SQL editor.
5. In Supabase Auth, enable Email and Google providers. For Google, add the callback URL shown under Auth > URL Configuration and add your Render URL as an allowed redirect URL.
6. Run `npm run dev`.

The browser only receives the public anon key. Never expose a service-role key in Vite environment variables.

## Supabase requirements

- Enable Realtime for `messages` and `profiles` if presence updates are needed.
- Create/configure the `avatars` Storage bucket; the SQL file includes scoped object policies.
- Add an administrator with a trusted SQL session using `insert into public.app_admins(user_id) values ('...');`. Do not implement admin access with a frontend email check.
- Email confirmation can be enabled in Auth settings. Set Supabase Auth > URL Configuration > Site URL to your deployed URL, for example `https://kanni-mol-chat.vercel.app`, and add `https://kanni-mol-chat.vercel.app/**` under Redirect URLs. Signup explicitly redirects confirmation links to the current site origin. Google users without a profile are sent through username setup.

## Render deployment

The included `render.yaml` defines a static site. Connect this repository in Render, add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` as environment variables, and deploy. The rewrite keeps client-side routes working. Add the deployed Render URL to Supabase Auth redirect URLs.

## Verification

Use two real Supabase accounts to search by username, open a direct conversation, and send messages in two browser sessions. Verify RLS with a non-admin session and confirm email addresses never appear in the normal client UI.
