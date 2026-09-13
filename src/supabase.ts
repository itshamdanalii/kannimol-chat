import { createClient, SupabaseClient } from '@supabase/supabase-js'

type ProfileRow = {
  id: string
  username: string
  display_name: string
  avatar_url: string | null
  bio: string | null
  is_online: boolean
  last_seen: string
  created_at: string
  updated_at: string
}

type ConversationRow = {
  id: string
  created_at: string
  updated_at: string
}

type ConversationMemberRow = {
  conversation_id: string
  user_id: string
  joined_at: string
}

type MessageRow = {
  id: string
  conversation_id: string
  sender_id: string
  content: string
  message_type: 'text'
  created_at: string
  updated_at: string
  is_read: boolean
}

export type Database = {
  public: {
    Tables: {
      profiles: { Row: ProfileRow; Insert: Partial<ProfileRow> & Pick<ProfileRow, 'id' | 'username' | 'display_name'>; Update: Partial<ProfileRow> }
      conversations: { Row: ConversationRow; Insert: Partial<ConversationRow>; Update: Partial<ConversationRow> }
      conversation_members: { Row: ConversationMemberRow; Insert: Partial<ConversationMemberRow> & Pick<ConversationMemberRow, 'conversation_id' | 'user_id'>; Update: Partial<ConversationMemberRow> }
      messages: { Row: MessageRow; Insert: Partial<MessageRow> & Pick<MessageRow, 'conversation_id' | 'sender_id' | 'content'>; Update: Partial<MessageRow> }
      message_reactions: { Row: { id: string; message_id: string; user_id: string; reaction: string; created_at: string }; Insert: { message_id: string; user_id: string; reaction: string }; Update: Partial<{ reaction: string }> }
      user_blocks: { Row: { blocker_id: string; blocked_id: string; created_at: string }; Insert: { blocker_id: string; blocked_id: string }; Update: never }
      app_admins: { Row: { user_id: string; created_at: string }; Insert: { user_id: string }; Update: never }
    }
    Views: Record<string, never>
    Functions: {
      get_or_create_direct_conversation: { Args: { target_user_id: string }; Returns: string }
      touch_profile_presence: { Args: { online: boolean }; Returns: undefined }
      admin_list_users: { Args: Record<string, never>; Returns: { id: string; email: string; username: string; display_name: string; provider: string }[] }
    }
    Enums: Record<string, never>
    CompositeTypes: Record<string, never>
  }
}

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

let client: SupabaseClient<Database> | null = null
if (supabaseUrl && supabaseAnonKey) {
  try {
    client = createClient<Database>(supabaseUrl, supabaseAnonKey)
  } catch (error) {
    console.error('Supabase client configuration is invalid', error)
  }
}

export const supabase = client
export const isSupabaseConfigured = Boolean(client)

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
