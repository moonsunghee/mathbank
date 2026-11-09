import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser, safeNextPath } from "@/lib/auth";
import { signIn, signInWithGoogle, signUp } from "./actions";

const ERROR_MESSAGES: Record<string, string> = {
  invalid_credentials: "이메일 또는 비밀번호가 올바르지 않습니다.",
  email_not_confirmed: "이메일 인증을 먼저 완료해 주세요.",
  user_already_exists: "이미 가입된 이메일입니다.",
  weak_password: "비밀번호가 너무 약합니다. 더 길고 복잡하게 입력해 주세요.",
  oauth_failed: "구글 로그인을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.",
  callback_failed: "로그인을 완료하지 못했습니다. 다시 시도해 주세요.",
};

const inputClass =
  "w-full rounded-md border border-line bg-background px-3 py-2 text-base outline-none focus:border-foreground";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ next?: string; error?: string; message?: string }>;
}) {
  const params = await searchParams;
  const next = safeNextPath(params.next);

  if (await getCurrentUser()) {
    redirect(next);
  }

  const error = params.error
    ? (ERROR_MESSAGES[params.error] ?? "요청을 처리하지 못했습니다. 다시 시도해 주세요.")
    : null;

  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-sm flex-col justify-center gap-6 px-4 py-10">
      <div>
        <Link href="/" className="text-sm text-muted">
          수학 문제은행
        </Link>
        <h1 className="mt-1 text-2xl font-bold">로그인</h1>
      </div>

      {error && (
        <p role="alert" className="rounded-md border border-line px-3 py-2 text-sm">
          {error}
        </p>
      )}
      {params.message === "check_email" && (
        <p role="status" className="rounded-md border border-line px-3 py-2 text-sm">
          인증 메일을 보냈습니다. 메일의 링크를 눌러 가입을 완료해 주세요.
        </p>
      )}

      <form className="flex flex-col gap-3">
        <input type="hidden" name="next" value={next} />
        <label className="flex flex-col gap-1 text-sm">
          이메일
          <input name="email" type="email" autoComplete="email" required className={inputClass} />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          비밀번호
          <input
            name="password"
            type="password"
            autoComplete="current-password"
            required
            minLength={8}
            className={inputClass}
          />
        </label>
        <div className="mt-1 flex gap-2">
          <button
            formAction={signIn}
            className="flex-1 rounded-md bg-foreground px-3 py-2 font-medium text-background"
          >
            로그인
          </button>
          <button formAction={signUp} className="flex-1 rounded-md border border-line px-3 py-2">
            회원가입
          </button>
        </div>
      </form>

      <form action={signInWithGoogle}>
        <input type="hidden" name="next" value={next} />
        <button className="w-full rounded-md border border-line px-3 py-2">구글로 계속하기</button>
      </form>
    </main>
  );
}
