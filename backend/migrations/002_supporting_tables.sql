-- Supporting tables for enhanced functionality

-- embeddings table: stores face embeddings for ML service
CREATE TABLE embeddings (
  embedding_id BIGINT AUTO_INCREMENT PRIMARY KEY,
  student_id VARCHAR(50) NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
  model_name VARCHAR(100) NOT NULL,
  vector JSON NOT NULL,  -- stores the embedding vector as JSON
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- cameras table: manages CCTV camera configurations
CREATE TABLE cameras (
  camera_id VARCHAR(50) PRIMARY KEY,
  label VARCHAR(200) NOT NULL,
  rtsp_url TEXT NOT NULL,
  channel INT,
  subtype INT DEFAULT 1,  -- 0=main stream, 1=substream
  location VARCHAR(200),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- settings table: global configuration
CREATE TABLE settings (
  setting_id INT AUTO_INCREMENT PRIMARY KEY,
  key_name VARCHAR(100) UNIQUE NOT NULL,
  value TEXT,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default settings
INSERT INTO settings (key_name, value, description) VALUES
('late_threshold_minutes', '30', 'Minutes after session start to mark as late'),
('absent_after_minutes', '30', 'Minutes without detection to mark as absent'),
('use_substream_for_detection', 'true', 'Use substream for face detection'),
('confidence_threshold', '0.6', 'Minimum confidence score for face matching'),
('max_attendance_duration_hours', '8', 'Maximum session duration in hours');

-- Create indexes for performance
CREATE INDEX idx_embeddings_student ON embeddings(student_id);
CREATE INDEX idx_embeddings_model ON embeddings(model_name);
CREATE INDEX idx_cameras_active ON cameras(is_active);
CREATE INDEX idx_settings_key ON settings(key_name);
