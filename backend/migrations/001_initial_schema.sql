-- LabFace Attendance System - Initial Schema
-- This migration creates the core tables for the attendance system

-- 1) students (canonical)
CREATE TABLE students (
  student_id   VARCHAR(50) PRIMARY KEY,
  first_name   TEXT NOT NULL,
  middle_name  TEXT,
  last_name    TEXT NOT NULL,
  course       VARCHAR(200),
  year_level   INT,
  email        VARCHAR(200) UNIQUE,
  mobile       VARCHAR(30),
  password_hash TEXT NOT NULL,   -- store hashed password only (bcrypt/argon2)
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 1b) student photos (store multiple profile/selfie photos as URLs)
CREATE TABLE student_photos (
  photo_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
  student_id VARCHAR(50) NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
  image_url  TEXT NOT NULL,              -- store location (S3) not blob in DB
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2) professors (separate table for professor accounts)
CREATE TABLE professors (
  professor_id VARCHAR(50) PRIMARY KEY,
  first_name   TEXT NOT NULL,
  last_name    TEXT NOT NULL,
  email        VARCHAR(200) UNIQUE,
  password_hash TEXT NOT NULL,
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3) classes
CREATE TABLE classes (
  class_id     INT AUTO_INCREMENT PRIMARY KEY,
  semester     VARCHAR(50),
  school_year  VARCHAR(50),
  subject      VARCHAR(200) NOT NULL,
  section      VARCHAR(100),
  professor_id VARCHAR(50) REFERENCES professors(professor_id),
  created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4) enrollment (which students are in which class)
CREATE TABLE class_students (
  class_id    INT NOT NULL REFERENCES classes(class_id) ON DELETE CASCADE,
  student_id  VARCHAR(50) NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
  enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (class_id, student_id)
);

-- 5) sessions (one row per class meeting)
CREATE TABLE sessions (
  session_id  INT AUTO_INCREMENT PRIMARY KEY,
  class_id    INT NOT NULL REFERENCES classes(class_id),
  session_date DATE NOT NULL,
  start_ts    TIMESTAMP,
  end_ts      TIMESTAMP,
  status      TEXT DEFAULT 'open',       -- open / closed
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6) attendance
CREATE TABLE attendance (
  attendance_id INT AUTO_INCREMENT PRIMARY KEY,
  session_id    INT NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
  student_id    VARCHAR(50) NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
  status        VARCHAR(20) NOT NULL,    -- present / absent / excused / review
  checkin_ts    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  checkout_ts TIMESTAMP,
  presence_minutes INT,  
  selfie_url    TEXT,                    -- stored selfie (S3 URL) if used
  UNIQUE(session_id, student_id)
);

-- 7) presence_events table
CREATE TABLE IF NOT EXISTS presence_events (
  event_id   BIGINT AUTO_INCREMENT PRIMARY KEY,
  session_id INT REFERENCES sessions(session_id),
  student_id VARCHAR(50) NOT NULL REFERENCES students(student_id),
  event_type TEXT NOT NULL,       -- 'in' or 'out' (or 'seen'/'left' if you prefer)
  event_ts   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  source     VARCHAR(50),         -- 'face','qr','cctv','app','manual'
  details    JSON,               -- optional: { "image_url": "...", "score": 0.82, "camera":"C1" }
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pe_session_student ON presence_events(session_id, student_id, event_ts);

-- 8) face_checkins: every selfie/checkin saved for audit
CREATE TABLE IF NOT EXISTS face_checkins(
  checkin_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
  session_id     INT REFERENCES sessions(session_id),
  image_url      TEXT,                   -- stored selfie URL
  computed_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
