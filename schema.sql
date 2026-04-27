-- ══════════════════════════════════════════
-- CareSync Database Schema
-- Run this in Supabase SQL Editor
-- ══════════════════════════════════════════

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── HOUSES ──
CREATE TABLE IF NOT EXISTS houses (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  email TEXT,
  pharmacy_email TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── USERS / STAFF ──
CREATE TABLE IF NOT EXISTS staff (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin','manager','worker')),
  house_id UUID REFERENCES houses(id),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── SERVICE USERS ──
CREATE TABLE IF NOT EXISTS service_users (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  fname TEXT NOT NULL,
  lname TEXT NOT NULL,
  dob DATE,
  room TEXT,
  house_id UUID REFERENCES houses(id),
  needs TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── MEDICATIONS ──
CREATE TABLE IF NOT EXISTS medications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  service_user_id UUID REFERENCES service_users(id),
  name TEXT NOT NULL,
  dose TEXT,
  type TEXT CHECK (type IN ('scheduled','prn')),
  times TEXT[], -- array of times e.g. {'08:00','17:00'}
  stock INTEGER DEFAULT 0,
  reorder_at INTEGER DEFAULT 7,
  pharmacy_email TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── MAR RECORDS (immutable audit trail) ──
CREATE TABLE IF NOT EXISTS mar_records (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  service_user_id UUID REFERENCES service_users(id),
  medication_id UUID REFERENCES medications(id),
  admin_time TEXT, -- e.g. '08:00'
  admin_date DATE NOT NULL,
  status TEXT CHECK (status IN ('given','refused','na')),
  initials TEXT,
  initials2 TEXT, -- countersignature
  notes TEXT,
  refusal_reason TEXT,
  prn_outcome TEXT,
  is_cd BOOLEAN DEFAULT FALSE,
  is_critical BOOLEAN DEFAULT FALSE,
  is_prn BOOLEAN DEFAULT FALSE,
  voided BOOLEAN DEFAULT FALSE,
  void_reason TEXT,
  staff_id UUID REFERENCES staff(id),
  countersign_staff_id UUID REFERENCES staff(id),
  countersigned_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── DAILY LOGS ──
CREATE TABLE IF NOT EXISTS daily_logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  service_user_id UUID REFERENCES service_users(id),
  house_id UUID REFERENCES houses(id),
  categories TEXT[],
  mood INTEGER CHECK (mood BETWEEN 1 AND 5),
  food TEXT,
  appetite TEXT,
  personal_care TEXT[],
  assist_level TEXT,
  sleep_hours TEXT,
  sleep_quality TEXT,
  notes TEXT NOT NULL,
  log_date DATE NOT NULL,
  log_time TIME,
  staff_id UUID REFERENCES staff(id),
  staff_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── FINANCES ──
CREATE TABLE IF NOT EXISTS finances (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  service_user_id UUID REFERENCES service_users(id),
  house_id UUID REFERENCES houses(id),
  amount DECIMAL(10,2) NOT NULL,
  category TEXT,
  description TEXT,
  location TEXT,
  accompanied_by TEXT,
  transaction_date DATE NOT NULL,
  receipt_ref TEXT,
  staff_id UUID REFERENCES staff(id),
  staff_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── ROTA ──
CREATE TABLE IF NOT EXISTS rota (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  staff_id UUID REFERENCES staff(id),
  house_id UUID REFERENCES houses(id),
  shift_date DATE NOT NULL,
  shift_code TEXT NOT NULL, -- e.g. '9^9','11-9','DO','AL'
  shift_hours DECIMAL(4,1) DEFAULT 0,
  created_by UUID REFERENCES staff(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(staff_id, shift_date, house_id)
);

-- ── BODY MAP MARKERS ──
CREATE TABLE IF NOT EXISTS body_markers (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  service_user_id UUID REFERENCES service_users(id),
  marker_type TEXT, -- bruise, wound, redness, skin condition
  location TEXT,
  size TEXT,
  notes TEXT,
  status TEXT DEFAULT 'New', -- New, Existing, Healing, Resolved
  observed_date DATE,
  observed_by TEXT,
  staff_id UUID REFERENCES staff(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── MED COUNT HISTORY ──
CREATE TABLE IF NOT EXISTS med_counts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  medication_id UUID REFERENCES medications(id),
  service_user_id UUID REFERENCES service_users(id),
  count_type TEXT CHECK (count_type IN ('in','out','audit')),
  quantity INTEGER,
  prev_stock INTEGER,
  new_stock INTEGER,
  notes TEXT,
  staff_id UUID REFERENCES staff(id),
  staff_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ══════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ══════════════════════════════════════════
ALTER TABLE houses ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE mar_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE finances ENABLE ROW LEVEL SECURITY;
ALTER TABLE rota ENABLE ROW LEVEL SECURITY;
ALTER TABLE body_markers ENABLE ROW LEVEL SECURITY;
ALTER TABLE med_counts ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read/write for now
-- (We will add role-based policies after launch)
CREATE POLICY "Allow authenticated" ON houses FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON staff FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON service_users FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON medications FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON mar_records FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON daily_logs FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON finances FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON rota FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON body_markers FOR ALL TO authenticated USING (true);
CREATE POLICY "Allow authenticated" ON med_counts FOR ALL TO authenticated USING (true);

-- ══════════════════════════════════════════
-- SEED DATA (demo house and admin user)
-- ══════════════════════════════════════════
INSERT INTO houses (id, name, address, phone, email, pharmacy_email)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Maple House',
  '12 High Street, Bangor, Gwynedd',
  '01248 000001',
  'maplehouse@caresync.wales',
  'pharmacy@boots.com'
) ON CONFLICT DO NOTHING;

