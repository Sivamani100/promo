// Supabase Edge Function: mcp-gateway
// Location: supabase/functions/mcp-gateway/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(
      JSON.stringify({ error: "Server configuration error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // Create a service role client to bypass standard RLS (Edge Function acts as Gateway)
  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: { persistSession: false },
  });

  // 1. Authenticate via Authorization Bearer Header
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing or invalid Authorization header. Expected Bearer token." }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const rawKey = authHeader.substring(7).trim();

  // 2. Hash the raw key using SHA-256
  const hashBuffer = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(rawKey));
  const keyHash = Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  // 3. Call validate_and_increment_mcp_key RPC
  const { data: authResult, error: authRpcError } = await supabase.rpc("validate_and_increment_mcp_key", {
    p_key_hash: keyHash,
  });

  if (authRpcError || !authResult || authResult.length === 0) {
    return new Response(
      JSON.stringify({ error: "Authentication RPC failure", details: authRpcError }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const { valid, key_id, user_id, role, scopes, error_message } = authResult[0];

  if (!valid) {
    // If rate limit exceeded (429) or revoked/expired (403/401)
    const status = error_message.includes("limit") ? 429 : 403;
    
    // Log the failed transaction if key_id exists
    if (key_id) {
      await supabase.from("mcp_key_logs").insert({
        key_id,
        action_name: "auth_validation",
        success: false,
        description: `Validation failed: ${error_message}`,
      });
    }

    return new Response(
      JSON.stringify({ error: error_message }),
      { status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 4. Resolve Route and Execute Action
  const url = new URL(req.url);
  const path = url.pathname.replace(/\/+$/, "");
  const action = path.substring(path.lastIndexOf("/") + 1).toLowerCase();

  try {
    if (action === "cards") {
      // Fetch Campaigns
      let query = supabase
        .from("cards")
        .select("id, title, description, category, budget_range, preferred_location, status, created_at")
        .is("deleted_at", null);

      if (role === "influencer") {
        query = query.eq("status", "active");
      } else if (role === "brand") {
        query = query.eq("brand_id", user_id);
      }

      const { data: cards, error } = await query;
      if (error) throw error;

      await logMcpAction(supabase, key_id, "get_cards", true, `Successfully fetched ${cards.length} cards`);
      return new Response(JSON.stringify({ role, cards }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "applications") {
      // Fetch Applications
      let query = supabase
        .from("applications")
        .select(`
          id,
          pitch_message,
          proposed_rate,
          status,
          created_at,
          card:cards!applications_card_id_fkey(id, title, budget_range)
        `)
        .is("deleted_at", null);

      if (role === "influencer") {
        query = query.eq("influencer_id", user_id);
      } else if (role === "brand") {
        query = query.filter("cards.brand_id", "eq", user_id);
      }

      const { data: applications, error } = await query;
      if (error) throw error;

      // Filter null card objects (e.g. if brand joins on cards of other brands)
      const filteredApps = applications.filter((app) => app.card !== null);

      await logMcpAction(supabase, key_id, "get_applications", true, `Successfully fetched ${filteredApps.length} applications`);
      return new Response(JSON.stringify({ role, applications: filteredApps }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "chats") {
      // Fetch Chat Rooms
      let query = supabase
        .from("rooms")
        .select(`
          id,
          created_at,
          card:cards!rooms_card_id_fkey(id, title),
          brand:profiles!rooms_brand_id_fkey(id, display_name),
          influencer:profiles!rooms_influencer_id_fkey(id, display_name)
        `)
        .is("deleted_at", null);

      if (role === "influencer") {
        query = query.eq("influencer_id", user_id);
      } else if (role === "brand") {
        query = query.eq("brand_id", user_id);
      }

      const { data: rooms, error } = await query;
      if (error) throw error;

      await logMcpAction(supabase, key_id, "get_chats", true, `Successfully fetched ${rooms.length} chat rooms`);
      return new Response(JSON.stringify({ role, chats: rooms }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "apply") {
      // Submit Application (Write Action)
      if (req.method !== "POST") {
        return new Response(JSON.stringify({ error: "Method not allowed. Use POST for /apply" }), {
          status: 405,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Check Scopes for Write Actions
      if (!scopes.includes("full_access")) {
        await logMcpAction(supabase, key_id, "submit_application", false, "Write action rejected: read_only scope");
        return new Response(
          JSON.stringify({ error: "Forbidden: Write actions require a 'full_access' scoped key." }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      if (role !== "influencer") {
        return new Response(JSON.stringify({ error: "Forbidden: Only influencers can apply to campaigns" }), {
          status: 403,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const body = await req.json().catch(() => ({}));
      const { card_id, pitch, rate } = body;

      if (!card_id || !pitch || !rate) {
        return new Response(JSON.stringify({ error: "Missing required fields: card_id, pitch, rate" }), {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Rates numeric validation
      const numRate = parseFloat(rate);
      if (isNaN(numRate) || numRate <= 0 || numRate > 1000000) {
        return new Response(
          JSON.stringify({ error: "Validation failed: proposed rate must be a positive numeric value up to $1,000,000" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Pitch text sanitization
      const sanitizedPitch = pitch
        .replace(/<[^>]*>/g, "") // Strip HTML tags
        .replace(/\b(fuck|shit|bitch|asshole|cunt|bastard|dick|pussy|scam|fraud|abuse|fake)\b/gi, (match: string) => "*".repeat(match.length))
        .trim();

      // Check if already applied
      const { data: existingApps } = await supabase
        .from("applications")
        .select("id")
        .eq("card_id", card_id)
        .eq("influencer_id", user_id)
        .is("deleted_at", null);

      if (existingApps && existingApps.length > 0) {
        return new Response(JSON.stringify({ error: "Conflict: You have already applied to this campaign" }), {
          status: 409,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // Insert application
      const { data: newApp, error: insertError } = await supabase
        .from("applications")
        .insert({
          card_id,
          influencer_id: user_id,
          pitch_message: sanitizedPitch,
          proposed_rate: numRate.toString(),
          status: "pending",
        })
        .select()
        .single();

      if (insertError) throw insertError;

      await logMcpAction(supabase, key_id, "submit_application", true, `Applied to card ${card_id} with rate ${numRate}`);
      return new Response(JSON.stringify({ success: true, application: newApp }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: `Not found: action '${action}'` }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    await logMcpAction(supabase, key_id, action, false, `Internal Error: ${errorMsg}`);
    return new Response(JSON.stringify({ error: "Internal Gateway Error", details: errorMsg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function logMcpAction(supabase: any, keyId: string, actionName: string, success: boolean, description: string) {
  try {
    await supabase.from("mcp_key_logs").insert({
      key_id: keyId,
      action_name: actionName,
      success,
      description,
    });
  } catch (e) {
    console.error(`[MCP GATEWAY] Failed to log action: ${e}`);
  }
}
