import { requireAdmin } from "@/lib/auth";

export default async function AdminPage() {
  const user = await requireAdmin();

  return (
    <main className="mx-auto w-full max-w-3xl px-4 py-10">
      <h1 className="text-2xl font-bold">관리자</h1>
      <p className="mt-2 text-muted">{user.email} 계정으로 접속했습니다. 문항 관리 기능은 준비 중입니다.</p>
    </main>
  );
}
