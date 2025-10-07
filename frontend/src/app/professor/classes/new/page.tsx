'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
import { api } from '@/lib/api'
import { getUser } from '@/lib/auth'
import toast from 'react-hot-toast'

export default function NewClass() {
  const router = useRouter()
  const [loading, setLoading] = useState(false)
  const [formData, setFormData] = useState({
    semester: '',
    school_year: '',
    subject: '',
    section: ''
  })
  const user = getUser()

  useEffect(() => {
    if (!user || user.type !== 'professor') {
      router.push('/')
      return
    }
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      await api.post('/classes', formData)
      toast.success('Class created successfully!')
      router.push('/professor/dashboard')
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to create class')
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
              <h1 className="text-xl font-semibold text-gray-900">Create New Class</h1>
            </div>
            <div className="flex items-center space-x-4">
              <Button
                variant="outline"
                onClick={() => router.push('/professor/dashboard')}
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
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Create New Class</h2>
            <p className="text-gray-600">
              Fill in the details to create a new class for attendance tracking.
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid grid-cols-2 gap-4">
              <Input
                label="Semester"
                value={formData.semester}
                onChange={(e) => setFormData({ ...formData, semester: e.target.value })}
                placeholder="e.g., Fall 2024"
                required
              />

              <Input
                label="School Year"
                value={formData.school_year}
                onChange={(e) => setFormData({ ...formData, school_year: e.target.value })}
                placeholder="e.g., 2024-2025"
                required
              />
            </div>

            <Input
              label="Subject"
              value={formData.subject}
              onChange={(e) => setFormData({ ...formData, subject: e.target.value })}
              placeholder="e.g., Computer Science 101"
              required
            />

            <Input
              label="Section"
              value={formData.section}
              onChange={(e) => setFormData({ ...formData, section: e.target.value })}
              placeholder="e.g., A, B, or 01"
            />

            <div className="flex justify-end space-x-4">
              <Button
                type="button"
                variant="outline"
                onClick={() => router.push('/professor/dashboard')}
              >
                Cancel
              </Button>
              
              <Button
                type="submit"
                disabled={loading}
              >
                {loading ? 'Creating...' : 'Create Class'}
              </Button>
            </div>
          </form>
        </Card>
      </div>
    </div>
  )
}
