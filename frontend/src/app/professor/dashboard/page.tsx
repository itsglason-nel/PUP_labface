'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { api } from '@/lib/api'
import { getUser } from '@/lib/auth'
import toast from 'react-hot-toast'
import { Plus, Play, Square, Users, Calendar } from 'lucide-react'

interface Class {
  class_id: number
  subject: string
  section: string
  semester: string
  school_year: string
  created_at: string
}

export default function ProfessorDashboard() {
  const router = useRouter()
  const [classes, setClasses] = useState<Class[]>([])
  const [loading, setLoading] = useState(true)
  const user = getUser()

  useEffect(() => {
    if (!user || user.type !== 'professor') {
      router.push('/')
      return
    }

    fetchClasses()
  }, [])

  const fetchClasses = async () => {
    try {
      const response = await api.get('/classes')
      setClasses(response.data)
    } catch (error: any) {
      toast.error('Failed to fetch classes')
    } finally {
      setLoading(false)
    }
  }

  const startSession = async (classId: number) => {
    try {
      const response = await api.post(`/classes/${classId}/start`)
      toast.success('Session started successfully!')
      router.push(`/professor/session/${response.data.session_id}`)
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to start session')
    }
  }

  const stopSession = async (classId: number) => {
    try {
      await api.post(`/classes/${classId}/stop`)
      toast.success('Session stopped successfully!')
      fetchClasses()
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to stop session')
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <h1 className="text-xl font-semibold text-gray-900">LabFace Dashboard</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-600">Welcome, {user?.first_name}</span>
              <Button
                variant="outline"
                onClick={() => {
                  localStorage.clear()
                  router.push('/')
                }}
              >
                Logout
              </Button>
            </div>
          </div>
        </div>
      </nav>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex justify-between items-center mb-8">
          <h2 className="text-2xl font-bold text-gray-900">My Classes</h2>
          <Button
            onClick={() => router.push('/professor/classes/new')}
            className="flex items-center space-x-2"
          >
            <Plus className="h-4 w-4" />
            <span>New Class</span>
          </Button>
        </div>

        {classes.length === 0 ? (
          <Card className="text-center py-12">
            <Calendar className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-medium text-gray-900 mb-2">No classes yet</h3>
            <p className="text-gray-600 mb-4">Create your first class to get started</p>
            <Button onClick={() => router.push('/professor/classes/new')}>
              Create Class
            </Button>
          </Card>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {classes.map((classItem) => (
              <Card key={classItem.class_id} className="p-6">
                <div className="flex items-start justify-between mb-4">
                  <div>
                    <h3 className="text-lg font-semibold text-gray-900">
                      {classItem.subject}
                    </h3>
                    <p className="text-sm text-gray-600">
                      {classItem.section} • {classItem.semester} {classItem.school_year}
                    </p>
                  </div>
                </div>

                <div className="flex space-x-2">
                  <Button
                    onClick={() => startSession(classItem.class_id)}
                    className="flex-1 flex items-center justify-center space-x-2"
                  >
                    <Play className="h-4 w-4" />
                    <span>Start Session</span>
                  </Button>
                  <Button
                    variant="outline"
                    onClick={() => stopSession(classItem.class_id)}
                    className="flex items-center justify-center"
                  >
                    <Square className="h-4 w-4" />
                  </Button>
                </div>

                <div className="mt-4 pt-4 border-t">
                  <Button
                    variant="outline"
                    onClick={() => router.push(`/professor/classes/${classItem.class_id}`)}
                    className="w-full"
                  >
                    <Users className="h-4 w-4 mr-2" />
                    View Details
                  </Button>
                </div>
              </Card>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
