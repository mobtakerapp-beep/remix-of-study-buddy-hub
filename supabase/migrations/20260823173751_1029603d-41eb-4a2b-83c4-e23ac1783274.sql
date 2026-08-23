CREATE TABLE public.profiles (
  id uuid NOT NULL PRIMARY KEY,
  teacher_name text NOT NULL DEFAULT '',
  school text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own profile" ON public.profiles FOR ALL TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id) VALUES (NEW.id) ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE TYPE public.app_role AS ENUM ('admin', 'moderator', 'user');
CREATE TABLE public.user_roles (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  role public.app_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own roles" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE TABLE public.user_lessons (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  title text NOT NULL,
  package jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_lessons TO authenticated;
GRANT ALL ON public.user_lessons TO service_role;
ALTER TABLE public.user_lessons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own lessons" ON public.user_lessons FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX user_lessons_user_idx ON public.user_lessons (user_id, updated_at DESC);

CREATE TABLE public.lesson_shares (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  token text NOT NULL UNIQUE,
  title text NOT NULL,
  package jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, DELETE ON public.lesson_shares TO authenticated;
GRANT ALL ON public.lesson_shares TO service_role;
ALTER TABLE public.lesson_shares ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own shares" ON public.lesson_shares FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE,
  plan text NOT NULL DEFAULT 'free',
  status text NOT NULL DEFAULT 'active',
  generations_used integer NOT NULL DEFAULT 0,
  reset_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.subscriptions TO authenticated;
GRANT ALL ON public.subscriptions TO service_role;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own subscription" ON public.subscriptions FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE public.activation_codes (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  code text NOT NULL UNIQUE,
  plan text NOT NULL DEFAULT 'monthly',
  duration_days integer NOT NULL DEFAULT 30,
  max_uses integer NOT NULL DEFAULT 1,
  used_count integer NOT NULL DEFAULT 0,
  note text,
  active boolean NOT NULL DEFAULT true,
  expires_at timestamptz,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.activation_codes TO service_role;
ALTER TABLE public.activation_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins manage activation codes" ON public.activation_codes FOR ALL TO authenticated USING (public.has_role(auth.uid(), 'admin')) WITH CHECK (public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.code_redemptions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  code_id uuid NOT NULL REFERENCES public.activation_codes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  device_fingerprint text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.code_redemptions TO authenticated;
GRANT ALL ON public.code_redemptions TO service_role;
ALTER TABLE public.code_redemptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users view own redemptions" ON public.code_redemptions FOR SELECT TO authenticated USING (auth.uid() = user_id);

CREATE TABLE public.study_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  lesson_id uuid,
  topic text NOT NULL DEFAULT '',
  grade integer,
  seconds integer NOT NULL DEFAULT 0,
  correct integer NOT NULL DEFAULT 0,
  total integer NOT NULL DEFAULT 0,
  kind text NOT NULL DEFAULT 'study',
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT ON public.study_sessions TO authenticated;
GRANT ALL ON public.study_sessions TO service_role;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own study sessions" ON public.study_sessions FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX study_sessions_user_idx ON public.study_sessions (user_id, created_at DESC);