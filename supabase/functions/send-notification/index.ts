import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')!
const ONESIGNAL_REST_API_KEY = Deno.env.get('ONESIGNAL_REST_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    const { type, title, body, excludeUserId } = await req.json()

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY)

    // Get all user IDs to notify (everyone except the sender)
    let query = supabase.from('users').select('id')
    if (excludeUserId) {
      query = query.neq('id', excludeUserId)
    }
    const { data: users, error } = await query

    if (error || !users || users.length === 0) {
      return new Response(JSON.stringify({ sent: 0, reason: 'no users' }), { status: 200 })
    }

    // Target by External ID (= Supabase user ID set via OneSignal.login())
    // This is the most reliable way — works even if subscription ID rotates
    const externalIds = users.map((u: any) => u.id)

    const payload = {
      app_id: ONESIGNAL_APP_ID,
      include_aliases: {
        external_id: externalIds
      },
      target_channel: 'push',
      headings: { en: title },
      contents: { en: body },
      data: { type },
      priority: 10,
    }

    const res = await fetch('https://onesignal.com/api/v1/notifications', {
      method: 'POST',
      headers: {
        'Authorization': `Key ${ONESIGNAL_REST_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    })

    const result = await res.json()
    return new Response(
      JSON.stringify({ sent: externalIds.length, result }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 })
  }
})
