-- ==========================================
-- 1. Enable Extensions
-- ==========================================
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 2. Create Tables
-- ==========================================

CREATE TABLE institutions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text NOT NULL,
  domain text,
  admin_id uuid,
  contact_email text,
  contact_phone text,
  address text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE profiles (
  id uuid PRIMARY KEY,
  full_name text,
  email text,
  role text,
  institution_id uuid REFERENCES institutions(id),
  requires_password_change boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE courses (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  subject text,
  join_code text,
  owner_id uuid REFERENCES profiles(id),
  institution_id uuid REFERENCES institutions(id),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE units (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id uuid REFERENCES courses(id),
  name text NOT NULL,
  unit_code text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE classes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  unit_id uuid REFERENCES units(id),
  lecturer_id uuid REFERENCES profiles(id),
  name text NOT NULL,
  class_code text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE enrollments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id uuid REFERENCES profiles(id),
  class_id uuid REFERENCES classes(id),
  course_id uuid REFERENCES courses(id),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE materials (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id uuid REFERENCES profiles(id),
  course_id uuid REFERENCES courses(id),
  unit_id uuid REFERENCES units(id),
  title text,
  file_path text,
  content text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE material_chunks (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  material_id uuid REFERENCES materials(id) ON DELETE CASCADE,
  course_id uuid REFERENCES courses(id),
  content text NOT NULL,
  embedding vector(768)
);

CREATE TABLE questions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id uuid REFERENCES profiles(id),
  course_id uuid REFERENCES courses(id),
  question text NOT NULL,
  options jsonb,
  correct_index integer,
  published boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE quiz_attempts (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id uuid REFERENCES profiles(id),
  question_id uuid REFERENCES questions(id),
  course_id uuid REFERENCES courses(id),
  selected_index integer NOT NULL,
  correct boolean NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE saved_flashcards (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id uuid REFERENCES profiles(id),
  course_id uuid REFERENCES courses(id),
  topic text NOT NULL,
  cards jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE saved_notes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id uuid REFERENCES profiles(id),
  course_id uuid REFERENCES courses(id),
  topic text NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE ai_messages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id uuid REFERENCES profiles(id),
  course_id uuid REFERENCES courses(id),
  content text NOT NULL,
  role text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE announcements (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  author_id uuid REFERENCES profiles(id),
  class_id uuid REFERENCES classes(id),
  title text NOT NULL,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE live_sessions (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  lecturer_id uuid REFERENCES profiles(id),
  class_id uuid REFERENCES classes(id),
  title text NOT NULL,
  room_name text NOT NULL,
  status text,
  started_at timestamp with time zone,
  ended_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  sender_id uuid REFERENCES profiles(id),
  receiver_id uuid REFERENCES profiles(id),
  class_id uuid REFERENCES classes(id),
  content text NOT NULL,
  read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);

-- ==========================================
-- 3. Create Vector Match Function (For RAG)
-- ==========================================
CREATE OR REPLACE FUNCTION match_chunks (
  query_embedding vector(768),
  match_threshold float,
  match_count int,
  filter_course_id uuid
)
RETURNS TABLE (
  id uuid,
  content text,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    material_chunks.id,
    material_chunks.content,
    1 - (material_chunks.embedding <=> query_embedding) AS similarity
  FROM material_chunks
  WHERE material_chunks.course_id = filter_course_id
    AND 1 - (material_chunks.embedding <=> query_embedding) > match_threshold
  ORDER BY material_chunks.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

-- ==========================================
-- 4. Enable Row Level Security (RLS)
-- ==========================================
ALTER TABLE institutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE units ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE material_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- 5. Create Security Policies
-- ==========================================

-- PROFILES
CREATE POLICY "Allow all profiles" ON profiles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Allow authenticated users to create profile" ON profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Allow authenticated users to read profiles" ON profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admins can invite users" ON profiles FOR INSERT TO authenticated WITH CHECK (
  EXISTS (SELECT 1 FROM profiles p WHERE p.id = auth.uid() AND p.role = 'admin' AND p.institution_id = profiles.institution_id)
);

-- INSTITUTIONS
CREATE POLICY "Anyone can view institutions" ON institutions FOR SELECT USING (true);
CREATE POLICY "Admins can update their institution" ON institutions FOR UPDATE USING (auth.uid() = admin_id);
CREATE POLICY "Anyone can create an institution" ON institutions FOR INSERT WITH CHECK (auth.uid() = admin_id);
CREATE POLICY "Allow all institutions" ON institutions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow authenticated users to create institution" ON institutions FOR INSERT TO authenticated WITH CHECK (auth.uid() = admin_id);

-- COURSES
CREATE POLICY "Enable insert for authenticated users only" ON courses FOR INSERT TO authenticated WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Enable read for users based on owner_id" ON courses FOR SELECT TO authenticated USING (auth.uid() = owner_id);
CREATE POLICY "Enable update for users based on owner_id" ON courses FOR UPDATE TO authenticated USING (auth.uid() = owner_id);
CREATE POLICY "Enable delete for users based on owner_id" ON courses FOR DELETE TO authenticated USING (auth.uid() = owner_id);
CREATE POLICY "Anyone can read join codes" ON courses FOR SELECT USING (true);

-- UNITS
CREATE POLICY "Anyone can read units" ON units FOR SELECT USING (true);
CREATE POLICY "Owners can manage units" ON units FOR ALL USING (
  course_id IN (SELECT id FROM courses WHERE owner_id = auth.uid())
);

-- CLASSES
CREATE POLICY "Anyone can view classes" ON classes FOR SELECT USING (true);
CREATE POLICY "Lecturers manage their classes" ON classes FOR ALL USING (auth.uid() = lecturer_id);

-- QUESTIONS
CREATE POLICY "questions_owner_write" ON questions FOR ALL USING (
  course_id IN (SELECT id FROM courses WHERE owner_id = auth.uid())
);

-- MATERIALS
CREATE POLICY "Allow authenticated users to insert materials" ON materials FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Allow authenticated users to read materials" ON materials FOR SELECT TO authenticated USING (true);

-- SAVED NOTES & FLASHCARDS
CREATE POLICY "Students can manage their own notes" ON saved_notes FOR ALL USING (auth.uid() = student_id);
CREATE POLICY "Students can manage their own flashcards" ON saved_flashcards FOR ALL USING (auth.uid() = student_id);

-- MESSAGES
CREATE POLICY "Anyone authenticated can read messages" ON messages FOR SELECT TO authenticated USING (true);
CREATE POLICY "Anyone authenticated can insert messages" ON messages FOR INSERT TO authenticated WITH CHECK (auth.uid() = sender_id);

-- ANNOUNCEMENTS
CREATE POLICY "Anyone authenticated can read announcements" ON announcements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Anyone authenticated can insert announcements" ON announcements FOR INSERT TO authenticated WITH CHECK (auth.uid() = author_id);

-- AI MESSAGES
CREATE POLICY "Students read own AI messages" ON ai_messages FOR SELECT TO authenticated USING (auth.uid() = student_id);
CREATE POLICY "Students insert own AI messages" ON ai_messages FOR INSERT TO authenticated WITH CHECK (auth.uid() = student_id);

-- ENROLLMENTS
CREATE POLICY "Enrollments readable by auth" ON enrollments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Enrollments insertable by auth" ON enrollments FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "Enrollments deletable by auth" ON enrollments FOR DELETE TO authenticated USING (true);

-- QUIZ ATTEMPTS
CREATE POLICY "Students read own attempts" ON quiz_attempts FOR SELECT TO authenticated USING (auth.uid() = student_id);
CREATE POLICY "Students insert own attempts" ON quiz_attempts FOR INSERT TO authenticated WITH CHECK (auth.uid() = student_id);
CREATE POLICY "Faculty read attempts for own courses" ON quiz_attempts FOR SELECT TO authenticated USING (
  course_id IN (SELECT id FROM courses WHERE owner_id = auth.uid())
);

-- LIVE SESSIONS
CREATE POLICY "Faculty manage live sessions" ON live_sessions FOR ALL TO authenticated USING (lecturer_id = auth.uid()) WITH CHECK (lecturer_id = auth.uid());
CREATE POLICY "Class can read live sessions" ON live_sessions FOR SELECT TO authenticated USING (true);

-- ==========================================
-- 6. Auto-create Profile on Signup
-- ==========================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.email,
    'student' -- Default role, can be updated later
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger the function every time a user is created
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();