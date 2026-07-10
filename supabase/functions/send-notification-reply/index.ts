// Supabase Edge Function: send-notification-reply
// Called from the Android background notification reply action.
// Uses service role to bypass RLS (since background isolate has no auth session).
// Validates sender is a participant of the room before inserting.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing server configuration.");
    }

    // We need the anon key passed in the Authorization header to identify the caller's JWT
    // But for background replies (no session), we also accept sender_id from the notification payload.
    // Security: We verify sender_id is a participant in the room before inserting.
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const body = await req.json();
    const { room_id, sender_id, content } = body;

    // --- Input validation ---
    if (!room_id || typeof room_id !== "string") {
      return new Response(JSON.stringify({ error: "Invalid room_id." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!sender_id || typeof sender_id !== "string" || !/^[0-9a-f-]{36}$/i.test(sender_id)) {
      return new Response(JSON.stringify({ error: "Invalid sender_id." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    if (!content || typeof content !== "string" || content.trim().length === 0) {
      return new Response(JSON.stringify({ error: "Content cannot be empty." }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Max message length guard
    const trimmedContent = content.trim().substring(0, 2000);

    // --- Security: verify sender is a participant in the room ---
    const { data: room, error: roomError } = await supabase
      .from("chat_rooms")
      .select("brand_id, influencer_id")
      .eq("id", room_id)
      .maybeSingle();

    if (roomError || !room) {
      console.error("[REPLY] Room not found:", room_id, roomError);
      return new Response(JSON.stringify({ error: "Room not found." }), {
        status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const isParticipant = room.brand_id === sender_id || room.influencer_id === sender_id;
    if (!isParticipant) {
      console.error(`[REPLY] Unauthorized: sender ${sender_id} is not a participant of room ${room_id}`);
      return new Response(JSON.stringify({ error: "Unauthorized: sender is not a participant." }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // --- Insert the reply message using service role ---
    const { error: insertError } = await supabase.from("messages").insert({
      room_id: room_id,
      sender_id: sender_id,
      content: trimmedContent,
    });

    if (insertError) {
      console.error("[REPLY] Insert error:", insertError);
      throw insertError;
    }

    console.log(`[REPLY SUCCESS] Message sent by ${sender_id} to room ${room_id}`);
    return new Response(JSON.stringify({ success: true }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("[REPLY FAILURE]", error);
    return new Response(JSON.stringify({ error: error.message || "Internal error." }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
