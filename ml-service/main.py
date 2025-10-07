from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import face_recognition
import cv2
import numpy as np
from PIL import Image
import io
import os
import json
from typing import List, Optional, Dict, Any
import logging
from sqlalchemy import create_engine, text
from minio import Minio
import requests
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="LabFace ML Service",
    description="Face recognition service for attendance system",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection
DB_HOST = os.getenv("DB_HOST", "mariadb")
DB_PORT = os.getenv("DB_PORT", "3307")
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "root123")
DB_NAME = os.getenv("DB_NAME", "labface_db")

# MinIO connection
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "minio:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "minioadmin")

# Initialize database connection
DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(DATABASE_URL)

# Initialize MinIO client
minio_client = Minio(
    MINIO_ENDPOINT.split(':')[0],
    access_key=MINIO_ACCESS_KEY,
    secret_key=MINIO_SECRET_KEY,
    secure=False
)

# Pydantic models
class MatchRequest(BaseModel):
    image_url: Optional[str] = None
    image_data: Optional[str] = None  # base64 encoded
    session_id: Optional[int] = None

class MatchResponse(BaseModel):
    matched: bool
    student_id: Optional[str] = None
    score: Optional[float] = None
    confidence: Optional[float] = None
    image_url: Optional[str] = None

class EmbeddingRequest(BaseModel):
    student_id: str
    image_url: str
    model_name: str = "face_recognition"

class EmbeddingResponse(BaseModel):
    success: bool
    embedding_id: Optional[int] = None
    message: str

# Global variables for caching
known_encodings = {}
known_student_ids = []

def load_embeddings_from_db():
    """Load all embeddings from database"""
    global known_encodings, known_student_ids
    
    try:
        with engine.connect() as conn:
            result = conn.execute(text("""
                SELECT student_id, vector, model_name 
                FROM embeddings 
                WHERE model_name = 'face_recognition'
            """))
            
            known_encodings = {}
            known_student_ids = []
            
            for row in result:
                student_id = row[0]
                vector_data = json.loads(row[1])
                model_name = row[2]
                
                # Convert back to numpy array
                encoding = np.array(vector_data)
                known_encodings[student_id] = encoding
                known_student_ids.append(student_id)
                
        logger.info(f"Loaded {len(known_encodings)} embeddings from database")
        
    except Exception as e:
        logger.error(f"Error loading embeddings: {e}")
        known_encodings = {}
        known_student_ids = []

def get_face_encoding(image_data: bytes) -> Optional[np.ndarray]:
    """Extract face encoding from image data"""
    try:
        # Convert bytes to numpy array
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            return None
            
        # Convert BGR to RGB
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        # Find face locations
        face_locations = face_recognition.face_locations(rgb_image)
        
        if not face_locations:
            return None
            
        # Get face encodings
        face_encodings = face_recognition.face_encodings(rgb_image, face_locations)
        
        if not face_encodings:
            return None
            
        return face_encodings[0]  # Return first face found
        
    except Exception as e:
        logger.error(f"Error extracting face encoding: {e}")
        return None

def download_image_from_url(url: str) -> Optional[bytes]:
    """Download image from URL"""
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        return response.content
    except Exception as e:
        logger.error(f"Error downloading image from {url}: {e}")
        return None

@app.on_event("startup")
async def startup_event():
    """Initialize service on startup"""
    logger.info("Starting LabFace ML Service...")
    load_embeddings_from_db()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "ml-service"}

@app.post("/match", response_model=MatchResponse)
async def match_face(request: MatchRequest):
    """Match a face against known embeddings"""
    try:
        # Get image data
        if request.image_url:
            image_data = download_image_from_url(request.image_url)
            if not image_data:
                raise HTTPException(status_code=400, detail="Could not download image")
        elif request.image_data:
            import base64
            image_data = base64.b64decode(request.image_data)
        else:
            raise HTTPException(status_code=400, detail="Either image_url or image_data required")
        
        # Extract face encoding
        face_encoding = get_face_encoding(image_data)
        if face_encoding is None:
            return MatchResponse(
                matched=False,
                message="No face detected in image"
            )
        
        # Compare with known encodings
        if not known_encodings:
            return MatchResponse(
                matched=False,
                message="No known faces in database"
            )
        
        # Calculate distances
        distances = []
        student_ids = []
        
        for student_id, known_encoding in known_encodings.items():
            distance = face_recognition.face_distance([known_encoding], face_encoding)[0]
            distances.append(distance)
            student_ids.append(student_id)
        
        # Find best match
        min_distance = min(distances)
        best_match_idx = distances.index(min_distance)
        best_student_id = student_ids[best_match_idx]
        
        # Confidence threshold (lower distance = higher confidence)
        confidence_threshold = 0.6
        confidence = 1 - min_distance  # Convert distance to confidence
        
        if min_distance <= confidence_threshold:
            return MatchResponse(
                matched=True,
                student_id=best_student_id,
                score=min_distance,
                confidence=confidence,
                image_url=request.image_url
            )
        else:
            return MatchResponse(
                matched=False,
                score=min_distance,
                confidence=confidence,
                message="Face not recognized"
            )
            
    except Exception as e:
        logger.error(f"Error in face matching: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/embeddings", response_model=EmbeddingResponse)
async def create_embedding(request: EmbeddingRequest):
    """Create and store face embedding"""
    try:
        # Download image
        image_data = download_image_from_url(request.image_url)
        if not image_data:
            raise HTTPException(status_code=400, detail="Could not download image")
        
        # Extract face encoding
        face_encoding = get_face_encoding(image_data)
        if face_encoding is None:
            raise HTTPException(status_code=400, detail="No face detected in image")
        
        # Convert to JSON-serializable format
        vector_data = face_encoding.tolist()
        
        # Store in database
        with engine.connect() as conn:
            result = conn.execute(text("""
                INSERT INTO embeddings (student_id, model_name, vector)
                VALUES (:student_id, :model_name, :vector)
            """), {
                'student_id': request.student_id,
                'model_name': request.model_name,
                'vector': json.dumps(vector_data)
            })
            
            embedding_id = result.lastrowid
            
        # Update cache
        known_encodings[request.student_id] = face_encoding
        if request.student_id not in known_student_ids:
            known_student_ids.append(request.student_id)
        
        logger.info(f"Created embedding for student {request.student_id}")
        
        return EmbeddingResponse(
            success=True,
            embedding_id=embedding_id,
            message="Embedding created successfully"
        )
        
    except Exception as e:
        logger.error(f"Error creating embedding: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/embeddings/{student_id}")
async def delete_embedding(student_id: str):
    """Delete embeddings for a student"""
    try:
        with engine.connect() as conn:
            conn.execute(text("""
                DELETE FROM embeddings 
                WHERE student_id = :student_id
            """), {'student_id': student_id})
            
        # Update cache
        if student_id in known_encodings:
            del known_encodings[student_id]
        if student_id in known_student_ids:
            known_student_ids.remove(student_id)
        
        logger.info(f"Deleted embeddings for student {student_id}")
        
        return {"success": True, "message": "Embeddings deleted successfully"}
        
    except Exception as e:
        logger.error(f"Error deleting embeddings: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/reload-embeddings")
async def reload_embeddings():
    """Reload embeddings from database"""
    try:
        load_embeddings_from_db()
        return {"success": True, "message": f"Reloaded {len(known_encodings)} embeddings"}
    except Exception as e:
        logger.error(f"Error reloading embeddings: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/embeddings/count")
async def get_embedding_count():
    """Get count of stored embeddings"""
    return {
        "count": len(known_encodings),
        "student_ids": known_student_ids
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
