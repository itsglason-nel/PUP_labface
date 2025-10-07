'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { api } from '@/lib/api'
import toast from 'react-hot-toast'
import { Camera, Check, ArrowRight, ArrowLeft } from 'lucide-react'

interface RegistrationData {
  student_id: string
  first_name: string
  middle_name: string
  last_name: string
  course: string
  year_level: number
  email: string
  mobile: string
  password: string
  images: string[]
}

export default function StudentRegister() {
  const router = useRouter()
  const [step, setStep] = useState(1)
  const [loading, setLoading] = useState(false)
  const [formData, setFormData] = useState<RegistrationData>({
    student_id: '',
    first_name: '',
    middle_name: '',
    last_name: '',
    course: '',
    year_level: 1,
    email: '',
    mobile: '',
    password: '',
    images: []
  })

  const handleStep1 = (e: React.FormEvent) => {
    e.preventDefault()
    setStep(2)
  }

  const handleStep2 = (e: React.FormEvent) => {
    e.preventDefault()
    setStep(3)
  }

  const captureImage = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: true })
      const video = document.createElement('video')
      video.srcObject = stream
      video.play()

      // Create canvas and capture frame
      const canvas = document.createElement('canvas')
      const ctx = canvas.getContext('2d')
      
      video.addEventListener('loadedmetadata', () => {
        canvas.width = video.videoWidth
        canvas.height = video.videoHeight
        ctx?.drawImage(video, 0, 0)
        
        const imageData = canvas.toDataURL('image/jpeg')
        setFormData(prev => ({
          ...prev,
          images: [...prev.images, imageData]
        }))
        
        // Stop video stream
        stream.getTracks().forEach(track => track.stop())
      })
    } catch (error) {
      toast.error('Camera access denied or not available')
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      await api.post('/auth/student/register', formData)
      toast.success('Registration successful! Please login.')
      router.push('/student/login')
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Registration failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="max-w-2xl w-full">
        <Card className="p-8">
          <div className="text-center mb-8">
            <h1 className="text-2xl font-bold text-gray-900">Student Registration</h1>
            <p className="text-gray-600">Complete your registration in 3 steps</p>
            
            {/* Progress indicator */}
            <div className="flex justify-center mt-6">
              <div className="flex items-center space-x-4">
                {[1, 2, 3].map((stepNum) => (
                  <div key={stepNum} className="flex items-center">
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-medium ${
                      step >= stepNum 
                        ? 'bg-primary-600 text-white' 
                        : 'bg-gray-200 text-gray-600'
                    }`}>
                      {step > stepNum ? <Check className="h-4 w-4" /> : stepNum}
                    </div>
                    {stepNum < 3 && (
                      <div className={`w-8 h-0.5 ${
                        step > stepNum ? 'bg-primary-600' : 'bg-gray-200'
                      }`} />
                    )}
                  </div>
                ))}
              </div>
            </div>
          </div>

          {step === 1 && (
            <form onSubmit={handleStep1} className="space-y-4">
              <h2 className="text-lg font-semibold mb-4">Step 1: Personal Information</h2>
              
              <div className="grid grid-cols-2 gap-4">
                <Input
                  label="Student ID"
                  value={formData.student_id}
                  onChange={(e) => setFormData({ ...formData, student_id: e.target.value })}
                  required
                />
                <Input
                  label="Course"
                  value={formData.course}
                  onChange={(e) => setFormData({ ...formData, course: e.target.value })}
                />
              </div>

              <div className="grid grid-cols-3 gap-4">
                <Input
                  label="First Name"
                  value={formData.first_name}
                  onChange={(e) => setFormData({ ...formData, first_name: e.target.value })}
                  required
                />
                <Input
                  label="Middle Name"
                  value={formData.middle_name}
                  onChange={(e) => setFormData({ ...formData, middle_name: e.target.value })}
                />
                <Input
                  label="Last Name"
                  value={formData.last_name}
                  onChange={(e) => setFormData({ ...formData, last_name: e.target.value })}
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <Input
                  label="Email"
                  type="email"
                  value={formData.email}
                  onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                  required
                />
                <Input
                  label="Mobile"
                  value={formData.mobile}
                  onChange={(e) => setFormData({ ...formData, mobile: e.target.value })}
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="label">Year Level</label>
                  <select
                    className="input"
                    value={formData.year_level}
                    onChange={(e) => setFormData({ ...formData, year_level: parseInt(e.target.value) })}
                  >
                    {[1, 2, 3, 4, 5].map(year => (
                      <option key={year} value={year}>Year {year}</option>
                    ))}
                  </select>
                </div>
              </div>

              <Button type="submit" className="w-full">
                Next Step <ArrowRight className="h-4 w-4 ml-2" />
              </Button>
            </form>
          )}

          {step === 2 && (
            <form onSubmit={handleStep2} className="space-y-4">
              <h2 className="text-lg font-semibold mb-4">Step 2: Face Capture</h2>
              <p className="text-gray-600 mb-4">Please capture 2 clear photos of your face for attendance recognition.</p>
              
              <div className="grid grid-cols-2 gap-4">
                {[1, 2].map((imageNum) => (
                  <div key={imageNum} className="text-center">
                    <div className="border-2 border-dashed border-gray-300 rounded-lg p-8 mb-4">
                      {formData.images[imageNum - 1] ? (
                        <img
                          src={formData.images[imageNum - 1]}
                          alt={`Capture ${imageNum}`}
                          className="w-full h-32 object-cover rounded"
                        />
                      ) : (
                        <div className="text-center">
                          <Camera className="h-8 w-8 text-gray-400 mx-auto mb-2" />
                          <p className="text-sm text-gray-500">Photo {imageNum}</p>
                        </div>
                      )}
                    </div>
                    <Button
                      type="button"
                      variant="outline"
                      onClick={captureImage}
                      className="w-full"
                    >
                      <Camera className="h-4 w-4 mr-2" />
                      Capture Photo {imageNum}
                    </Button>
                  </div>
                ))}
              </div>

              <div className="flex space-x-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setStep(1)}
                  className="flex-1"
                >
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  Previous
                </Button>
                <Button
                  type="submit"
                  disabled={formData.images.length < 2}
                  className="flex-1"
                >
                  Next Step <ArrowRight className="h-4 w-4 ml-2" />
                </Button>
              </div>
            </form>
          )}

          {step === 3 && (
            <form onSubmit={handleSubmit} className="space-y-4">
              <h2 className="text-lg font-semibold mb-4">Step 3: Review & Consent</h2>
              
              <div className="bg-gray-50 p-4 rounded-lg mb-4">
                <h3 className="font-medium mb-2">Review Your Information:</h3>
                <div className="text-sm text-gray-600 space-y-1">
                  <p><strong>Name:</strong> {formData.first_name} {formData.middle_name} {formData.last_name}</p>
                  <p><strong>Student ID:</strong> {formData.student_id}</p>
                  <p><strong>Email:</strong> {formData.email}</p>
                  <p><strong>Course:</strong> {formData.course}</p>
                  <p><strong>Year Level:</strong> {formData.year_level}</p>
                  <p><strong>Photos Captured:</strong> {formData.images.length}/2</p>
                </div>
              </div>

              <Input
                label="Password"
                type="password"
                value={formData.password}
                onChange={(e) => setFormData({ ...formData, password: e.target.value })}
                required
              />

              <div className="space-y-2">
                <label className="flex items-start space-x-2">
                  <input
                    type="checkbox"
                    required
                    className="mt-1"
                  />
                  <span className="text-sm text-gray-600">
                    I consent to the use of my biometric data (facial images) for attendance tracking purposes. 
                    I understand that this data will be stored securely and used only for academic attendance management.
                  </span>
                </label>
              </div>

              <div className="flex space-x-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setStep(2)}
                  className="flex-1"
                >
                  <ArrowLeft className="h-4 w-4 mr-2" />
                  Previous
                </Button>
                <Button
                  type="submit"
                  disabled={loading}
                  className="flex-1"
                >
                  {loading ? 'Creating Account...' : 'Complete Registration'}
                </Button>
              </div>
            </form>
          )}
        </Card>
      </div>
    </div>
  )
}
