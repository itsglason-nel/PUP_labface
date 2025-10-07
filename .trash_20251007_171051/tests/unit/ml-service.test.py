import pytest
import numpy as np
from unittest.mock import Mock, patch
import sys
import os

# Add the ml-service directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../ml-service'))

from main import app
from fastapi.testclient import TestClient

client = TestClient(app)

class TestMLService:
    """Test cases for the ML service"""

    def test_health_endpoint(self):
        """Test the health check endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"

    def test_embeddings_endpoint_missing_fields(self):
        """Test embeddings endpoint with missing fields"""
        response = client.post("/embeddings", json={})
        assert response.status_code == 422  # Validation error

    def test_embeddings_endpoint_invalid_url(self):
        """Test embeddings endpoint with invalid URL"""
        response = client.post("/embeddings", json={
            "student_id": "STU001",
            "image_url": "invalid_url",
            "model_name": "face_recognition"
        })
        assert response.status_code == 400

    @patch('main.face_recognition.face_encodings')
    @patch('main.requests.get')
    def test_embeddings_endpoint_success(self, mock_get, mock_face_encodings):
        """Test successful embeddings creation"""
        # Mock the image download
        mock_response = Mock()
        mock_response.content = b"fake_image_data"
        mock_get.return_value = mock_response
        
        # Mock face encodings
        mock_face_encodings.return_value = [np.array([0.1, 0.2, 0.3, 0.4, 0.5])]
        
        response = client.post("/embeddings", json={
            "student_id": "STU001",
            "image_url": "https://example.com/image.jpg",
            "model_name": "face_recognition"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert "embedding_id" in data

    def test_match_endpoint_missing_fields(self):
        """Test match endpoint with missing fields"""
        response = client.post("/match", json={})
        assert response.status_code == 422  # Validation error

    def test_match_endpoint_invalid_image_data(self):
        """Test match endpoint with invalid image data"""
        response = client.post("/match", json={
            "image_data": "invalid_base64",
            "session_id": "SESSION001"
        })
        assert response.status_code == 400

    @patch('main.face_recognition.face_encodings')
    @patch('main.face_recognition.compare_faces')
    def test_match_endpoint_success(self, mock_compare_faces, mock_face_encodings):
        """Test successful face matching"""
        # Mock face encodings
        mock_face_encodings.return_value = [np.array([0.1, 0.2, 0.3, 0.4, 0.5])]
        
        # Mock face comparison
        mock_compare_faces.return_value = [True]
        
        # Valid base64 image data
        valid_image_data = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/2wBDAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQH/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAv/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwA/8A8A"
        
        response = client.post("/match", json={
            "image_data": valid_image_data,
            "session_id": "SESSION001"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert "matched" in data
        assert "confidence" in data

    def test_remove_embedding_endpoint_missing_fields(self):
        """Test remove embedding endpoint with missing fields"""
        response = client.delete("/embeddings", json={})
        assert response.status_code == 422  # Validation error

    @patch('main.knex')
    def test_remove_embedding_endpoint_success(self, mock_knex):
        """Test successful embedding removal"""
        mock_knex.return_value.where.return_value.del.return_value = 1
        
        response = client.delete("/embeddings", json={
            "student_id": "STU001"
        })
        
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True

    def test_invalid_endpoint(self):
        """Test invalid endpoint"""
        response = client.get("/invalid")
        assert response.status_code == 404

    def test_cors_headers(self):
        """Test CORS headers are present"""
        response = client.options("/health")
        assert response.status_code == 200
        assert "access-control-allow-origin" in response.headers

    def test_content_type_validation(self):
        """Test content type validation"""
        response = client.post("/embeddings", 
                              data="invalid_data",
                              headers={"Content-Type": "text/plain"})
        assert response.status_code == 422

    @patch('main.face_recognition.face_encodings')
    def test_no_face_detected(self, mock_face_encodings):
        """Test handling when no face is detected"""
        mock_face_encodings.return_value = []
        
        response = client.post("/embeddings", json={
            "student_id": "STU001",
            "image_url": "https://example.com/image.jpg",
            "model_name": "face_recognition"
        })
        
        assert response.status_code == 400
        data = response.json()
        assert "No face detected" in data["error"]

    @patch('main.face_recognition.face_encodings')
    def test_multiple_faces_detected(self, mock_face_encodings):
        """Test handling when multiple faces are detected"""
        mock_face_encodings.return_value = [
            np.array([0.1, 0.2, 0.3, 0.4, 0.5]),
            np.array([0.6, 0.7, 0.8, 0.9, 1.0])
        ]
        
        response = client.post("/embeddings", json={
            "student_id": "STU001",
            "image_url": "https://example.com/image.jpg",
            "model_name": "face_recognition"
        })
        
        assert response.status_code == 400
        data = response.json()
        assert "Multiple faces detected" in data["error"]

    def test_embedding_storage(self):
        """Test embedding storage functionality"""
        # This would test the actual storage logic
        # In a real test, you would mock the database operations
        pass

    def test_face_comparison_accuracy(self):
        """Test face comparison accuracy"""
        # This would test the actual face comparison logic
        # In a real test, you would use test images and verify accuracy
        pass

    def test_model_loading(self):
        """Test model loading functionality"""
        # This would test that the face recognition model loads correctly
        pass

    def test_error_handling(self):
        """Test error handling in various scenarios"""
        # Test database connection errors
        # Test image processing errors
        # Test model inference errors
        pass

    def test_performance(self):
        """Test performance characteristics"""
        # Test response times
        # Test memory usage
        # Test concurrent requests
        pass

    def test_security(self):
        """Test security aspects"""
        # Test input validation
        # Test file upload security
        # Test authentication/authorization
        pass

if __name__ == "__main__":
    pytest.main([__file__])
