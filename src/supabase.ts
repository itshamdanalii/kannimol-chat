import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey)
export const supabase = isSupabaseConfigured
  ? createClient(supabaseUrl, supabaseAnonKey)
  : null

export type Profile = {
  id: string
  username: string
  display_name: string
  avatar_url: string | null
  bio: string | null
  is_online: boolean
  last_seen: string
}

export type Conversation = {
  id: string
  updated_at: string
  other: Profile
  lastMessage?: Message
  unreadCount?: number
}

export type Message = {
  id: string
  conversation_id: string
  sender_id: string
  content: string
  message_type: 'text'
  created_at: string
  is_read: boolean
}
