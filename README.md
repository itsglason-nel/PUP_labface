# LabFace - AI-Powered Attendance System

A complete, production-ready full-stack attendance system with face recognition, real-time monitoring, and CCTV integration.

## 🚀 Features

- **Face Recognition**: AI-powered attendance tracking using facial recognition
- **Real-time Monitoring**: Live attendance dashboard with WebSocket updates
- **CCTV Integration**: RTSP camera support for automated detection
- **Multi-role System**: Separate interfaces for Professors and Students
- **Secure Authentication**: JWT-based authentication with bcrypt password hashing
- **File Storage**: MinIO S3-compatible object storage for images
- **Export Functionality**: CSV export for attendance records
- **Docker Support**: Complete containerized deployment

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API   │    │   ML Service    │
│   (Next.js)     │◄──►│   (Express)     │◄──►│   (FastAPI)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   MinIO         │    │   MariaDB       │    │   Cameras       │
│   (S3 Storage)  │    │   (Database)    │    │   (RTSP)        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📋 Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for local development)
- Python 3.11+ (for ML service development)
- MariaDB/MySQL (if running without Docker)

## 🚀 Quick Start

### 1. Clone and Setup

```bash
git clone <repository-url>
cd labface-attendance-system
```

### 2. Environment Configuration

```bash
# Copy environment template
cp env.example .env

# Edit environment variables
nano .env
```

**Required Environment Variables:**

```env
# Database
DB_HOST=mariadb
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_secure_password
DB_NAME=labface

# MinIO Storage
MINIO_ENDPOINT=minio:9000
MINIO_ACCESS_KEY=your_access_key
MINIO_SECRET_KEY=your_secret_key

# JWT Security
JWT_SECRET=your_very_secure_jwt_secret_key

# Camera Configuration
CAM_RTSP_C1=rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=1
CAM_RTSP_C2=rtsp://admin:password@192.168.1.101:554/cam/realmonitor?channel=1&subtype=1

# Attendance Settings
LATE_THRESHOLD_MINUTES=30
ABSENT_AFTER_MINUTES=30
```

### 3. Start Services

```bash
# Start all services
docker compose up --build

# Or start in background
docker compose up -d --build
```

### 4. Access the Application

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:4000
- **ML Service**: http://localhost:8000
- **MinIO Console**: http://localhost:9001
- **Database Admin**: http://localhost:8080

## 📚 API Documentation

### Authentication Endpoints

```bash
# Professor Registration
POST /api/auth/professor/register
{
  "professor_id": "PROF001",
  "first_name": "John",
  "last_name": "Doe",
  "email": "john.doe@university.edu",
  "password": "secure_password"
}

# Professor Login
POST /api/auth/professor/login
{
  "email": "john.doe@university.edu",
  "password": "secure_password"
}

# Student Registration (3-step process)
POST /api/auth/student/register
{
  "student_id": "STU001",
  "first_name": "Jane",
  "last_name": "Smith",
  "email": "jane.smith@student.edu",
  "password": "secure_password",
  "course": "Computer Science",
  "year_level": 2
}
```

### Class Management

```bash
# Create Class
POST /api/classes
Authorization: Bearer <jwt_token>
{
  "semester": "Fall 2024",
  "school_year": "2024-2025",
  "subject": "Computer Science 101",
  "section": "A"
}

# Start Attendance Session
POST /api/classes/{class_id}/start
Authorization: Bearer <jwt_token>

# Stop Attendance Session
POST /api/classes/{class_id}/stop
Authorization: Bearer <jwt_token>
```

### Attendance Tracking

```bash
# Student Check-in
POST /api/attendance/checkin
Authorization: Bearer <jwt_token>
{
  "session_id": 1,
  "image_data": "base64_encoded_image"
}

# Export Attendance
GET /api/attendance/export?session_id=1&format=csv
Authorization: Bearer <jwt_token>
```

## 📷 Camera Integration

### RTSP Configuration

The system supports RTSP cameras for automated face detection. Configure your cameras in the environment:

```env
# Primary camera (entrance detection)
CAM_RTSP_C1=rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=1

# Secondary camera (exit detection)
CAM_RTSP_C2=rtsp://admin:password@192.168.1.101:554/cam/realmonitor?channel=1&subtype=1
```

### GStreamer Commands

**Channel 1 Main Stream:**
```bash
gst-launch-1.0 -v rtspsrc location="rtsp://admin:glason27@192.168.1.15:554/cam/realmonitor?channel=1&subtype=1" \
  protocols=udp latency=0 ! rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! \
  videoscale ! video/x-raw,width=640,height=360 ! appsink sync=false max-buffers=1 drop=true
```

**Channel 2 Main Stream:**
```bash
gst-launch-1.0 -v rtspsrc location="rtsp://admin:glason27@192.168.1.15:554/cam/realmonitor?channel=1&subtype=1" \
  protocols=udp latency=0 ! rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! \
  videoscale ! video/x-raw,width=640,height=360 ! appsink sync=false max-buffers=1 drop=true
```

### Camera Setup Recommendations

1. **Network Configuration**:
   - Use wired LAN connection for stability
   - Prefer UDP RTSP for lower latency
   - Configure TCP fallback for packet loss scenarios
   - Set up VLAN/QoS for camera traffic prioritization

2. **Camera Settings**:
   - Use substream (subtype=1) for face detection
   - Use main stream (subtype=0) for snapshots
   - Recommended resolution: 640x360 for detection
   - Frame rate: 15-30 FPS
   - GOP size: 30-60 frames

3. **Hardware Acceleration**:
   ```bash
   # NVIDIA GPU decode (if available)
   gst-launch-1.0 rtspsrc ! rtph264depay ! h264parse ! nvv4l2decoder ! videoconvert ! appsink
   
   # VAAPI decode (Intel/AMD)
   gst-launch-1.0 rtspsrc ! rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! appsink
   ```

4. **Testing Camera Stream**:
   ```bash
   # Test with VLC
   vlc rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=1
   
   # Test with FFmpeg
   ffmpeg -i rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=1 -t 10 test.mp4
   ```

## 🔧 Development

### Local Development Setup

```bash
# Backend
cd backend
npm install
npm run dev

# Frontend
cd frontend
npm install
npm run dev

# ML Service
cd ml-service
pip install -r requirements.txt
python main.py
```

### Database Migrations

```bash
# Run migrations
cd backend
npx knex migrate:latest

# Rollback migrations
npx knex migrate:rollback
```

### Testing

```bash
# Backend tests
cd backend
npm test

# ML service tests
cd ml-service
python -m pytest
```

## 🔒 Security Configuration

### Production Security Checklist

1. **Environment Variables**:
   - Change all default passwords
   - Use strong JWT secrets (32+ characters)
   - Enable HTTPS in production
   - Use environment-specific database credentials

2. **Database Security**:
   - Enable SSL connections
   - Use strong database passwords
   - Restrict database access by IP
   - Regular security updates

3. **MinIO Security**:
   - Change default access keys
   - Enable SSL/TLS
   - Configure bucket policies
   - Enable access logging

4. **Network Security**:
   - Use VPN for camera access
   - Firewall rules for service ports
   - Regular security audits
   - Monitor access logs

### HTTPS Configuration

```env
# Production HTTPS settings
HTTPS_CERT_PATH=/path/to/cert.pem
HTTPS_KEY_PATH=/path/to/key.pem
CORS_ORIGIN=https://yourdomain.com
```

## 📊 Monitoring and Logging

### Health Checks

```bash
# Service health endpoints
curl http://localhost:4000/api/health
curl http://localhost:8000/health
```

### Logging

- **Backend**: Winston structured logging
- **ML Service**: Python logging with JSON format
- **Frontend**: Browser console logging

### Performance Monitoring

- Database query optimization
- Image processing performance
- WebSocket connection monitoring
- Camera stream latency tracking

## 🚀 Deployment

### Production Deployment

1. **Environment Setup**:
   ```bash
   # Copy production environment
   cp env.example .env.production
   
   # Update production values
   nano .env.production
   ```

2. **Docker Compose Production**:
   ```bash
   # Use production compose file
   docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
   ```

3. **SSL/TLS Setup**:
   ```bash
   # Generate SSL certificates
   openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
   ```

### Scaling Considerations

- **Database**: Use connection pooling, read replicas
- **ML Service**: Horizontal scaling with load balancer
- **Storage**: MinIO cluster for high availability
- **Monitoring**: Prometheus + Grafana for metrics

## 🛠️ Troubleshooting

### Common Issues

1. **Camera Connection Issues**:
   - Check RTSP URL format
   - Verify camera credentials
   - Test with VLC player
   - Check network connectivity

2. **Face Recognition Issues**:
   - Ensure good lighting
   - Check image quality
   - Verify embeddings are created
   - Test with clear face images

3. **Database Connection**:
   - Check database credentials
   - Verify network connectivity
   - Check database service status
   - Review connection logs

4. **WebSocket Issues**:
   - Check CORS configuration
   - Verify Socket.IO version compatibility
   - Check firewall settings
   - Review browser console errors

### Performance Optimization

1. **Database Optimization**:
   - Add appropriate indexes
   - Optimize query performance
   - Use connection pooling
   - Regular maintenance

2. **Image Processing**:
   - Use hardware acceleration
   - Optimize image sizes
   - Implement caching
   - Batch processing

3. **Network Optimization**:
   - Use CDN for static assets
   - Implement caching strategies
   - Optimize WebSocket connections
   - Monitor bandwidth usage

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📞 Support

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review the documentation
- Contact the development team

---

**Note**: This system handles biometric data. Ensure compliance with local privacy laws (GDPR, PDPA, etc.) and implement appropriate consent mechanisms and data retention policies.
