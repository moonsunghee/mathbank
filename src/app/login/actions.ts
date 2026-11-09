"use server";

import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { safeNextPath } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

function textField(formData: FormData, name: string) {
  const value = formData.get(name);
  return typeof value === "string" ? value : "";
}

function loginUrl(next: string, params: Record<string, string>) {
  return `/login?${new URLSearchParams({ next, ...params })}`;
}

async function callbackUrl(next: string) {
  const origin = (await headers()).get("origin");
  return `${origin}/auth/callback?${new URLSearchParams({ next })}`;
}

export async function signIn(formData: FormData) {
  const next = safeNextPath(textField(formData, "next"));
  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({
    email: textField(formData, "email"),
    password: textField(formData, "password"),
  });

  if (error) {
    redirect(loginUrl(next, { error: error.code ?? "auth_failed" }));
  }
  redirect(next);
}

export async function signUp(formData: FormData) {
  const next = safeNextPath(textField(formData, "next"));
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email: textField(formData, "email"),
    password: textField(formData, "password"),
    options: { emailRedirectTo: await callbackUrl(next) },
  });

  if (error) {
    redirect(loginUrl(next, { error: error.code ?? "auth_failed" }));
  }
  if (data.session) {
    redirect(next);
  }
  redirect(loginUrl(next, { message: "check_email" }));
}

export async function signInWithGoogle(formData: FormData) {
  const next = safeNextPath(textField(formData, "next"));
  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: "google",
    options: { redirectTo: await callbackUrl(next) },
  });

  if (error || !data.url) {
    redirect(loginUrl(next, { error: "oauth_failed" }));
  }
  redirect(data.url);
}

export async function signOut() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/");
}
