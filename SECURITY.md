# Security Policy

## 🔒 Security Overview

LabFace handles sensitive biometric data and requires robust security measures. This document outlines security best practices, compliance requirements, and implementation guidelines.

## 🛡️ Data Protection

### Biometric Data Handling

**Data Types:**
- Facial images (profile photos, selfies)
- Face embeddings (mathematical representations)
- Attendance records with timestamps
- Personal identification information

**Protection Measures:**
- Encryption at rest for all biometric data
- Secure transmission using HTTPS/TLS
- Access controls and authentication
- Regular security audits
- Data retention policies

### Encryption Standards

**At Rest:**
- Database encryption using MariaDB encryption
- MinIO server-side encryption (SSE)
- Encrypted backup storage
- Key management system

**In Transit:**
- TLS 1.3 for all API communications
- WebSocket secure connections (WSS)
- RTSP over TLS for camera streams
- VPN for camera network access

## 🔐 Authentication & Authorization

### JWT Security

```typescript
// JWT Configuration
const jwtConfig = {
  secret: process.env.JWT_SECRET, // 32+ character random string
  expiresIn: '24h',
  algorithm: 'HS256'
}

// Token validation
const verifyToken = (token: string) => {
  return jwt.verify(token, process.env.JWT_SECRET)
}
```

**Security Requirements:**
- Strong JWT secrets (32+ characters)
- Token expiration (24 hours max)
- Secure token storage (httpOnly cookies recommended)
- Token refresh mechanism
- Logout token invalidation

### Password Security

```typescript
// Password hashing with bcrypt
const saltRounds = 12
const hashedPassword = await bcrypt.hash(password, saltRounds)

// Password validation
const isValid = await bcrypt.compare(password, hashedPassword)
```

**Password Requirements:**
- Minimum 8 characters
- Mix of uppercase, lowercase, numbers, symbols
- No common passwords
- Regular password updates
- Account lockout after failed attempts

## 🏗️ Infrastructure Security

### Network Security

**Firewall Configuration:**
```bash
# Allow only necessary ports
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3000/tcp  # Frontend (dev)
ufw allow 4000/tcp  # Backend API
ufw allow 8000/tcp  # ML Service
ufw allow 3306/tcp  # Database (restrict to app servers)
ufw allow 9000/tcp  # MinIO
ufw deny 554/tcp    # RTSP (use VPN instead)
```

**VPN Setup for Cameras:**
```bash
# OpenVPN configuration for camera access
# /etc/openvpn/server.conf
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
server 10.8.0.0 255.255.255.0
push "route 192.168.1.0 255.255.255.0"  # Camera network
```

### Database Security

**MariaDB Security:**
```sql
-- Create dedicated user with limited privileges
CREATE USER 'labface_app'@'%' IDENTIFIED BY 'strong_password';
GRANT SELECT, INSERT, UPDATE, DELETE ON labface.* TO 'labface_app'@'%';
FLUSH PRIVILEGES;

-- Enable SSL
SET GLOBAL ssl_cert = '/path/to/server-cert.pem';
SET GLOBAL ssl_key = '/path/to/server-key.pem';
```

**Connection Security:**
```typescript
const dbConfig = {
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: {
    rejectUnauthorized: true,
    ca: fs.readFileSync('/path/to/ca-cert.pem')
  }
}
```

### MinIO Security

**Access Control:**
```bash
# Create service account
mc admin user add minio labface-service strong_password

# Create policy
mc admin policy add minio labface-policy /path/to/policy.json

# Attach policy to user
mc admin policy attach minio labface-policy --user labface-service
```

**Policy Configuration:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::labface/*"
    }
  ]
}
```

## 🔍 Monitoring & Logging

### Security Logging

**Structured Logging:**
```typescript
const securityLogger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'logs/security.log' })
  ]
})

// Log security events
securityLogger.info('Login attempt', {
  user: email,
  ip: req.ip,
  userAgent: req.get('User-Agent'),
  timestamp: new Date().toISOString()
})
```

**Security Events to Monitor:**
- Authentication attempts (success/failure)
- Authorization failures
- Data access patterns
- File upload/download activities
- Database query anomalies
- Network connection attempts

### Intrusion Detection

**Failed Login Monitoring:**
```typescript
const loginAttempts = new Map()

const checkLoginAttempts = (ip: string) => {
  const attempts = loginAttempts.get(ip) || 0
  if (attempts >= 5) {
    // Block IP for 15 minutes
    setTimeout(() => loginAttempts.delete(ip), 15 * 60 * 1000)
    return false
  }
  return true
}
```

**Anomaly Detection:**
- Unusual access patterns
- Multiple failed authentication attempts
- Suspicious file access
- Database query anomalies
- Network traffic spikes

## 📋 Compliance Requirements

### GDPR Compliance

**Data Subject Rights:**
- Right to access personal data
- Right to rectification
- Right to erasure ("right to be forgotten")
- Right to data portability
- Right to object to processing

**Implementation:**
```typescript
// Data export endpoint
app.get('/api/user/data-export', authenticateToken, async (req, res) => {
  const userData = await getUserData(req.user.id)
  res.json({
    personal_data: userData.personal,
    attendance_records: userData.attendance,
    biometric_data: userData.biometric
  })
})

// Data deletion endpoint
app.delete('/api/user/data', authenticateToken, async (req, res) => {
  await deleteUserData(req.user.id)
  res.json({ message: 'Data deleted successfully' })
})
```

### Consent Management

**Consent Tracking:**
```sql
CREATE TABLE consent_records (
  id SERIAL PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  consent_type VARCHAR(100) NOT NULL,
  granted BOOLEAN NOT NULL,
  granted_at TIMESTAMP DEFAULT now(),
  revoked_at TIMESTAMP,
  ip_address INET,
  user_agent TEXT
);
```

**Consent UI:**
```typescript
const ConsentForm = () => {
  const [consent, setConsent] = useState({
    biometric: false,
    dataProcessing: false,
    dataRetention: false
  })

  const handleConsent = async () => {
    await api.post('/consent', {
      biometric: consent.biometric,
      dataProcessing: consent.dataProcessing,
      dataRetention: consent.dataRetention
    })
  }
}
```

### Data Retention Policy

**Retention Schedule:**
- Biometric data: 2 years after graduation
- Attendance records: 7 years (academic requirement)
- Personal data: Until consent withdrawal
- System logs: 1 year
- Security logs: 3 years

**Automated Cleanup:**
```sql
-- Delete expired biometric data
DELETE FROM embeddings 
WHERE created_at < DATE_SUB(NOW(), INTERVAL 2 YEAR);

-- Archive old attendance records
INSERT INTO attendance_archive 
SELECT * FROM attendance 
WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 YEAR);
```

## 🚨 Incident Response

### Security Incident Procedure

1. **Detection:**
   - Automated monitoring alerts
   - User reports
   - Security audit findings

2. **Response:**
   - Immediate containment
   - Evidence preservation
   - Impact assessment
   - Notification procedures

3. **Recovery:**
   - System restoration
   - Security patch deployment
   - Access review
   - Documentation

### Breach Notification

**Timeline Requirements:**
- GDPR: 72 hours to supervisory authority
- Users: Without undue delay
- Documentation: Full incident report

**Notification Template:**
```
Subject: Security Incident Notification

Dear [User],

We are writing to inform you of a security incident that may have affected your personal data.

Incident Details:
- Date: [Date]
- Type: [Data breach type]
- Data affected: [Specific data types]
- Actions taken: [Response measures]

We have taken immediate steps to secure the system and prevent further unauthorized access.

Contact: security@labface.edu
```

## 🔧 Security Configuration

### Environment Security

**Production Environment:**
```bash
# Secure environment variables
export NODE_ENV=production
export JWT_SECRET=$(openssl rand -base64 32)
export DB_PASSWORD=$(openssl rand -base64 32)
export MINIO_SECRET_KEY=$(openssl rand -base64 32)

# Disable debug mode
export DEBUG=false
export LOG_LEVEL=warn
```

**Docker Security:**
```dockerfile
# Use non-root user
RUN adduser --disabled-password --gecos '' appuser
USER appuser

# Security headers
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
```

### API Security

**Rate Limiting:**
```typescript
const rateLimit = require('express-rate-limit')

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP'
})

app.use('/api/', limiter)
```

**Input Validation:**
```typescript
const validateImage = (req, res, next) => {
  const { image } = req.body
  if (!image || typeof image !== 'string') {
    return res.status(400).json({ error: 'Invalid image data' })
  }
  next()
}
```

## 📚 Security Training

### Staff Training

**Security Awareness:**
- Password security best practices
- Phishing recognition
- Data handling procedures
- Incident reporting

**Technical Training:**
- Secure coding practices
- Vulnerability assessment
- Penetration testing
- Security tool usage

### Regular Audits

**Security Checklist:**
- [ ] Password policy enforcement
- [ ] Access control review
- [ ] Data encryption verification
- [ ] Log monitoring setup
- [ ] Backup security
- [ ] Incident response testing
- [ ] Compliance audit
- [ ] Penetration testing

## 📞 Security Contacts

**Security Team:**
- Email: security@labface.edu
- Phone: +1-XXX-XXX-XXXX
- Emergency: 24/7 security hotline

**Incident Reporting:**
- Email: incidents@labface.edu
- Web: https://labface.edu/security/report
- Phone: Emergency contact number

---

**Last Updated:** [Current Date]
**Next Review:** [Date + 6 months]
**Version:** 1.0
