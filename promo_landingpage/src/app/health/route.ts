import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export async function GET() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "";
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "";

  let dbStatus = "disconnected";
  try {
    if (supabaseUrl && supabaseAnonKey) {
      const supabase = createClient(supabaseUrl, supabaseAnonKey);
      // Try to fetch a simple request from profiles (limit 1) to verify connection
      const { error } = await supabase
        .from("profiles")
        .select("id")
        .limit(1)
        .maybeSingle();

      if (!error) {
        dbStatus = "connected";
      } else {
        dbStatus = `error: ${error.message}`;
      }
    } else {
      dbStatus = "error: missing environment variables";
    }
  } catch (e: any) {
    dbStatus = `error: ${e?.message || e}`;
  }

  const isHealthy = dbStatus === "connected";

  return NextResponse.json(
    {
      status: isHealthy ? "healthy" : "unhealthy",
      version: "1.0.4",
      database: dbStatus,
      timestamp: new Date().toISOString(),
    },
    {
      status: isHealthy ? 200 : 503,
      headers: {
        "Cache-Control": "no-store, max-age=0",
      },
    }
  );
}
