import { redirect } from "next/navigation";
import { cache } from "react";
import { createClient } from "@/lib/supabase/server";

export type UserRole = "admin" | "teacher" | "student";

export type AppUser = {
  id: string;
  email: string | null;
  name: string | null;
  role: UserRole;
};

export const getCurrentUser = cache(async (): Promise<AppUser | null> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return null;
  }

  const { data } = await supabase
    .from("users")
    .select("id, email, name, role")
    .eq("id", user.id)
    .maybeSingle();

  return data as AppUser | null;
});

export async function requireAdmin() {
  const user = await getCurrentUser();

  if (!user) {
    redirect("/login?next=/admin");
  }
  if (user.role !== "admin") {
    redirect("/");
  }

  return user;
}

export function safeNextPath(next: string | null | undefined) {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.includes("\\")) {
    return "/";
  }
  return next;
}
