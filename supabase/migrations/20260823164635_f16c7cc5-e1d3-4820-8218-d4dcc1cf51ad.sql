CREATE TABLE public.review_items (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  lesson_id uuid,
  question_hash text NOT NULL,
  kind text NOT NULL DEFAULT 'mcq',
  prompt text NOT NULL,
  options jsonb NOT NULL DEFAULT '[]'::jsonb,
  answer_index integer NOT NULL DEFAULT 0,
  topic text NOT NULL DEFAULT '',
  grade integer,
  language text NOT NULL DEFAULT 'ar',
  ease real NOT NULL DEFAULT 2.5,
  interval_days integer NOT NULL DEFAULT 0,
  reps integer NOT NULL DEFAULT 0,
  lapses integer NOT NULL DEFAULT 0,
  due_at timestamp with time zone NOT NULL DEFAULT now(),
  last_result boolean,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (user_id, question_hash)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.review_items TO authenticated;
GRANT ALL ON public.review_items TO service_role;
ALTER TABLE public.review_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own review items" ON public.review_items FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX review_items_due_idx ON public.review_items (user_id, due_at);

CREATE TABLE public.study_plans (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  week_start date NOT NULL,
  plan jsonb NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.study_plans TO authenticated;
GRANT ALL ON public.study_plans TO service_role;
ALTER TABLE public.study_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own study plans" ON public.study_plans FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.leaderboard_entries (
  user_id uuid NOT NULL PRIMARY KEY,
  display_name text NOT NULL DEFAULT 'Student',
  points integer NOT NULL DEFAULT 0,
  quizzes integer NOT NULL DEFAULT 0,
  correct integer NOT NULL DEFAULT 0,
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.leaderboard_entries TO authenticated;
GRANT ALL ON public.leaderboard_entries TO service_role;
ALTER TABLE public.leaderboard_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Signed-in users can view the leaderboard" ON public.leaderboard_entries FOR SELECT TO authenticated USING (true);
CREATE POLICY "Users create own leaderboard row" ON public.leaderboard_entries FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own leaderboard row" ON public.leaderboard_entries FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX leaderboard_points_idx ON public.leaderboard_entries (points DESC);