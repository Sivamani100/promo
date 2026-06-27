// Supabase Edge Function: send-push-notification
// Location: supabase/functions/send-push-notification/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import { GoogleAuth } from "npm:google-auth-library@9.11.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const firebaseConfigString = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase URL or Service Role Key.");
    }
    if (!firebaseConfigString) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT environment variable.");
    }

    const firebaseConfig = JSON.parse(firebaseConfigString);
    if (firebaseConfig.private_key) {
      firebaseConfig.private_key = firebaseConfig.private_key.replace(/\\n/g, "\n");
    }
    const projectId = firebaseConfig.project_id;
    if (!projectId) {
      throw new Error("Missing project_id in FIREBASE_SERVICE_ACCOUNT.");
    }

    // Initialize Supabase Client with Service Role Key to bypass RLS
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse Notification payload
    const body = await req.json();
    const record = body.record; // The notification record inserted into database

    // HARDENING: sec-agent 2026-06-24
    if (!record || typeof record !== "object") {
      return new Response(JSON.stringify({ error: "Invalid webhook payload." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!record.user_id || typeof record.user_id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(record.user_id)) {
      return new Response(JSON.stringify({ error: "Missing or invalid user_id format." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (record.title && typeof record.title !== "string") {
      return new Response(JSON.stringify({ error: "Invalid title field." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (record.body && typeof record.body !== "string") {
      return new Response(JSON.stringify({ error: "Invalid body field." }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const title = record.title || "New Notification";
    const content = record.body || "";
    const type = record.type || "generic";
    const refId = record.reference_id || "";

    console.log(`[PUSH] Fetching tokens for user: ${record.user_id}`);

    // Fetch active device push tokens for the recipient user
    const { data: pushTokens, error: tokenError } = await supabase
      .from("user_push_tokens")
      .select("fcm_token")
      .eq("user_id", record.user_id);

    if (tokenError) {
      throw tokenError;
    }

    if (!pushTokens || pushTokens.length === 0) {
      console.log(`[PUSH] No active push tokens found for user: ${record.user_id}`);
      return new Response(JSON.stringify({ message: "No push tokens available." }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`[PUSH] Found ${pushTokens.length} token(s). Obtaining Google OAuth2 access token.`);

    // Authenticate with Google / Firebase API using NPM package in Deno
    const auth = new GoogleAuth({
      credentials: firebaseConfig,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    const client = await auth.getClient();
    const credentials = await client.getAccessToken();
    const accessToken = credentials.token;

    if (!accessToken) {
      throw new Error("Failed to retrieve Google OAuth2 access token.");
    }

    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const results: any[] = [];
    
    const pushPromises = pushTokens.map(async (t) => {
      const fcmToken = t.fcm_token;
      
      const messagePayload: any = {
        token: fcmToken,
        data: {
          type: type,
          reference_id: refId,
          title: title,
          body: content,
          recipient_id: record.user_id,
        },
        android: {
          priority: "HIGH",
        },
        apns: {
          payload: {
            aps: {
              "content-available": 1,
            },
          },
        },
      };

      // For non-message notifications (e.g. general updates, approvals, campaign details),
      // we include the notification block so the OS displays it automatically with max reliability.
      // For message notifications (type = new_message), we omit it so the app can show it manually
      // with custom action buttons (Reply, Mark as Read).
      if (type !== "new_message") {
        messagePayload.notification = {
          title: title,
          body: content,
        };
      }

      const payload = {
        message: messagePayload,
      };

      try {
        const response = await fetch(fcmEndpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify(payload),
        });

        const resData = await response.json();
        
        if (!response.ok) {
          console.error(`[PUSH ERROR] Failed sending to token ${fcmToken.substring(0, 10)}...:`, resData);
          results.push({
            token: fcmToken.substring(0, 15) + "...",
            success: false,
            status: response.status,
            error: resData,
          });
          
          // If the token is unregistered/invalid, remove it from the DB
          if (
            response.status === 404 || 
            response.status === 410 || 
            (resData.error && resData.error.status === "UNREGISTERED")
          ) {
            console.log(`[PUSH CLEANUP] Deleting stale/unregistered token: ${fcmToken.substring(0, 10)}...`);
            await supabase
              .from("user_push_tokens")
              .delete()
              .eq("fcm_token", fcmToken);
          }
        } else {
          console.log(`[PUSH SUCCESS] Message sent to device with token prefix: ${fcmToken.substring(0, 10)}...`);
          results.push({
            token: fcmToken.substring(0, 15) + "...",
            success: true,
            messageId: resData.name,
          });
        }
      } catch (err) {
        console.error(`[PUSH CRITICAL] Error invoking FCM for token ${fcmToken.substring(0, 10)}...:`, err);
        results.push({
          token: fcmToken.substring(0, 15) + "...",
          success: false,
          error: err.message || err,
        });
      }
    });

    await Promise.all(pushPromises);

    const successCount = results.filter(r => r.success).length;
    const failureCount = results.length - successCount;

    return new Response(JSON.stringify({ 
      success: true, 
      devicesPushed: pushTokens.length,
      successCount,
      failureCount,
      details: results 
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[PUSH FAILURE] Error in send-push-notification:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
