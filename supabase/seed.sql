insert into public.curriculum (subject, unit, sort_order) values
  ('대수', '지수함수와 로그함수', 1),
  ('대수', '삼각함수', 2),
  ('대수', '수열', 3),
  ('미적분Ⅰ', '함수의 극한과 연속', 4),
  ('미적분Ⅰ', '미분', 5),
  ('미적분Ⅰ', '적분', 6),
  ('확률과 통계', '경우의 수', 7),
  ('확률과 통계', '확률', 8),
  ('확률과 통계', '통계', 9)
on conflict (subject, unit, subunit) do nothing;
