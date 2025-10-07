'use client'

import { useState, useRef, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { getUser } from '@/lib/auth'
import { api } from '@/lib/api'
import toast from 'react-hot-toast'
import { Camera, CheckCircle, AlertCircle } from 'lucide-react'

export default function StudentCheckin() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [captured, setCaptured] = useState(false)
  const [imageData, setImageData] = useState<string | null>(null)
  const videoRef = useRef<HTMLVideoElement>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const user = getUser()

  useEffect(() => {
    if (!user || user.type !== 'student') {
      router.push('/')
      return
    }
  }, [])

  const startCamera = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { 
          width: 640, 
          height: 480,
          facingMode: 'user'
        } 
      })
      
      if (videoRef.current) {
        videoRef.current.srcObject = stream
      }
    } catch (error) {
      toast.error('Camera access denied or not available')
    }
  }

  const capturePhoto = () => {
    if (videoRef.current && canvasRef.current) {
      const video = videoRef.current
      const canvas = canvasRef.current
      const ctx = canvas.getContext('2d')
      
      if (ctx) {
        canvas.width = video.videoWidth
        canvas.height = video.videoHeight
        ctx.drawImage(video, 0, 0)
        
        const imageData = canvas.toDataURL('image/jpeg', 0.8)
        setImageData(imageData)
        setCaptured(true)
        
        // Stop camera
        const stream = video.srcObject as MediaStream
        stream.getTracks().forEach(track => track.stop())
      }
    }
  }

  const retakePhoto = () => {
    setCaptured(false)
    setImageData(null)
    startCamera()
  }

  const submitCheckin = async () => {
    if (!imageData) {
      toast.error('Please capture a photo first')
      return
    }

    setLoading(true)
    
    try {
      // Extract base64 data (remove data:image/jpeg;base64, prefix)
      const base64Data = imageData.split(',')[1]
      
      const response = await api.post('/attendance/checkin', {
        session_id: 1, // This should come from the current session
        image_data: base64Data
      })

      if (response.data.success) {
        toast.success(response.data.message)
        router.push('/student/dashboard')
      } else {
        toast.error(response.data.error || 'Check-in failed')
      }
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Check-in failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold text-gray-900">Check In</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">Welcome, {user?.first_name}</span>
              <Button
                variant="outline"
                onClick={() => router.push('/student/dashboard')}
              >
                Back to Dashboard
              </Button>
            </div>
          </div>
        </div>
      </nav>

      <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Card className="p-8">
          <div className="text-center mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Face Recognition Check-in</h2>
            <p className="text-gray-600">
              Please position your face in the camera frame and capture a clear photo for attendance.
            </p>
          </div>

          {!captured ? (
            <div className="space-y-6">
              <div className="relative">
                <video
                  ref={videoRef}
                  autoPlay
                  playsInline
                  className="w-full h-64 bg-gray-200 rounded-lg object-cover"
                />
                <div className="absolute inset-0 flex items-center justify-center">
                  <div className="text-center text-white">
                    <Camera className="h-12 w-12 mx-auto mb-2 opacity-50" />
                    <p className="text-sm">Position your face in the frame</p>
                  </div>
                </div>
              </div>

              <div className="flex justify-center space-x-4">
                <Button
                  onClick={startCamera}
                  variant="outline"
                  className="flex items-center space-x-2"
                >
                  <Camera className="h-4 w-4" />
                  <span>Start Camera</span>
                </Button>
                
                <Button
                  onClick={capturePhoto}
                  className="flex items-center space-x-2"
                >
                  <Camera className="h-4 w-4" />
                  <span>Capture Photo</span>
                </Button>
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              <div className="relative">
                <img
                  src={imageData || ''}
                  alt="Captured photo"
                  className="w-full h-64 bg-gray-200 rounded-lg object-cover"
                />
                <div className="absolute top-4 right-4">
                  <div className="bg-green-100 text-green-800 px-3 py-1 rounded-full text-sm font-medium flex items-center space-x-1">
                    <CheckCircle className="h-4 w-4" />
                    <span>Captured</span>
                  </div>
                </div>
              </div>

              <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                <div className="flex items-start space-x-3">
                  <AlertCircle className="h-5 w-5 text-blue-600 mt-0.5" />
                  <div>
                    <h3 className="text-sm font-medium text-blue-900">Photo Guidelines</h3>
                    <ul className="mt-1 text-sm text-blue-800 space-y-1">
                      <li>• Ensure your face is clearly visible</li>
                      <li>• Look directly at the camera</li>
                      <li>• Ensure good lighting</li>
                      <li>• Remove sunglasses or hats</li>
                    </ul>
                  </div>
                </div>
              </div>

              <div className="flex justify-center space-x-4">
                <Button
                  onClick={retakePhoto}
                  variant="outline"
                  className="flex items-center space-x-2"
                >
                  <Camera className="h-4 w-4" />
                  <span>Retake Photo</span>
                </Button>
                
                <Button
                  onClick={submitCheckin}
                  disabled={loading}
                  className="flex items-center space-x-2"
                >
                  {loading ? (
                    <>
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                      <span>Processing...</span>
                    </>
                  ) : (
                    <>
                      <CheckCircle className="h-4 w-4" />
                      <span>Submit Check-in</span>
                    </>
                  )}
                </Button>
              </div>
            </div>
          )}

          <canvas ref={canvasRef} className="hidden" />
        </Card>
      </div>
    </div>
  )
}
