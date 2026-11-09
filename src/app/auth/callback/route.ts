import { NextResponse, type NextRequest } from "next/server";
import { safeNextPath } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = safeNextPath(searchParams.get("next"));

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);

    if (!error) {
      return NextResponse.redirect(new URL(next, origin));
    }
  }

  const loginUrl = new URL("/login", origin);
  loginUrl.searchParams.set("error", "callback_failed");
  return NextResponse.redirect(loginUrl);
}
