import Link from "next/link";
import { signOut } from "@/app/login/actions";
import { getCurrentUser } from "@/lib/auth";

export default async function Home() {
  const user = await getCurrentUser();

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-3xl flex-col justify-center gap-4 px-4 py-10">
      <h1 className="text-3xl font-bold">수학 문제은행</h1>
      <p className="text-muted">2028학년도 수능 대비 대수 · 미적분Ⅰ · 확률과 통계 문항을 준비하고 있습니다.</p>

      {user ? (
        <div className="flex items-center gap-3">
          <span className="text-sm text-muted">{user.email}</span>
          {user.role === "admin" && (
            <Link href="/admin" className="text-sm underline">
              관리자
            </Link>
          )}
          <form action={signOut}>
            <button className="text-sm underline">로그아웃</button>
          </form>
        </div>
      ) : (
        <Link
          href="/login"
          className="w-fit rounded-md bg-foreground px-4 py-2 font-medium text-background"
        >
          로그인
        </Link>
      )}
    </main>
  );
}
