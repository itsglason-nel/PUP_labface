'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'
import { getUser, getToken } from '@/lib/auth'
import { socketService } from '@/lib/socket'
import { api } from '@/lib/api'
import toast from 'react-hot-toast'
import { Users, Clock, CheckCircle, XCircle, Download, Square, Play } from 'lucide-react'

interface PresenceEvent {
  event_id: number
  student_id: string
  first_name: string
  last_name: string
  event_type: 'in' | 'out'
  event_ts: string
  source: string
  score?: number
  image_url?: string
}

interface SessionStats {
  present: number
  late: number
  absent: number
  total: number
}

export default function LiveSession({ params }: { params: { sessionId: string } }) {
  const router = useRouter()
  const [events, setEvents] = useState<PresenceEvent[]>([])
  const [stats, setStats] = useState<SessionStats>({ present: 0, late: 0, absent: 0, total: 0 })
  const [session, setSession] = useState<any>(null)
  const [loading, setLoading] = useState(true)
  const user = getUser()
  const token = getToken()

  useEffect(() => {
    if (!user || user.type !== 'professor') {
      router.push('/')
      return
    }

    if (token) {
      socketService.connect(token)
    }

    fetchSessionData()
    setupSocketListeners()

    return () => {
      socketService.leaveAttendanceRoom(params.sessionId)
    }
  }, [params.sessionId])

  const fetchSessionData = async () => {
    try {
      const response = await api.get(`/classes/sessions/${params.sessionId}`)
      setSession(response.data)
      
      // Fetch initial events
      const eventsResponse = await api.get(`/presence_events?session_id=${params.sessionId}`)
      setEvents(eventsResponse.data)
      
      // Calculate initial stats
      calculateStats(eventsResponse.data)
    } catch (error: any) {
      toast.error('Failed to fetch session data')
    } finally {
      setLoading(false)
    }
  }

  const setupSocketListeners = () => {
    socketService.joinAttendanceRoom(params.sessionId)
    
    socketService.onPresenceEvent((event: PresenceEvent) => {
      setEvents(prev => [event, ...prev])
      toast.success(`${event.first_name} ${event.last_name} checked ${event.event_type}`)
    })

    socketService.onSessionStatus((status: any) => {
      if (status.status === 'stopped') {
        toast('Session has been stopped')
        router.push('/professor/dashboard')
      }
    })
  }

  const calculateStats = (eventList: PresenceEvent[]) => {
    const presentStudents = new Set<string>()
    const lateStudents = new Set<string>()
    
    eventList.forEach(event => {
      if (event.event_type === 'in') {
        presentStudents.add(event.student_id)
        // Check if late (simplified logic)
        const eventTime = new Date(event.event_ts)
        const sessionStart = new Date(session?.start_ts)
        const diffMinutes = (eventTime.getTime() - sessionStart.getTime()) / (1000 * 60)
        
        if (diffMinutes > 30) { // 30 minutes late threshold
          lateStudents.add(event.student_id)
        }
      }
    })

    setStats({
      present: presentStudents.size,
      late: lateStudents.size,
      absent: Math.max(0, (session?.total_students || 0) - presentStudents.size),
      total: session?.total_students || 0
    })
  }

  const stopSession = async () => {
    try {
      await api.post(`/classes/${session.class_id}/stop`)
      toast.success('Session stopped successfully')
      router.push('/professor/dashboard')
    } catch (error: any) {
      toast.error('Failed to stop session')
    }
  }

  const exportAttendance = async () => {
    try {
      const response = await api.get(`/attendance/export?session_id=${params.sessionId}&format=csv`, {
        responseType: 'blob'
      })
      
      const blob = new Blob([response.data], { type: 'text/csv' })
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = `attendance_${params.sessionId}.csv`
      document.body.appendChild(a)
      a.click()
      window.URL.revokeObjectURL(url)
      document.body.removeChild(a)
      
      toast.success('Attendance exported successfully')
    } catch (error: any) {
      toast.error('Failed to export attendance')
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading session...</p>
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
              <h1 className="text-xl font-semibold text-gray-900">Live Session</h1>
              <span className="ml-4 text-sm text-gray-600">
                {session?.subject} - {session?.section}
              </span>
            </div>
            <div className="flex items-center space-x-4">
              <Button
                variant="outline"
                onClick={exportAttendance}
                className="flex items-center space-x-2"
              >
                <Download className="h-4 w-4" />
                <span>Export</span>
              </Button>
              <Button
                variant="danger"
                onClick={stopSession}
                className="flex items-center space-x-2"
              >
                <Square className="h-4 w-4" />
                <span>Stop Session</span>
              </Button>
            </div>
          </div>
        </div>
      </nav>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Live Events Feed */}
          <div className="lg:col-span-2">
            <Card className="h-96 overflow-hidden">
              <div className="p-6 border-b">
                <h2 className="text-lg font-semibold text-gray-900">Live Events</h2>
                <p className="text-sm text-gray-600">Real-time attendance updates</p>
              </div>
              <div className="h-80 overflow-y-auto">
                {events.length === 0 ? (
                  <div className="flex items-center justify-center h-full">
                    <div className="text-center">
                      <Clock className="h-12 w-12 text-gray-400 mx-auto mb-4" />
                      <p className="text-gray-600">Waiting for attendance events...</p>
                    </div>
                  </div>
                ) : (
                  <div className="p-4 space-y-3">
                    {events.map((event) => (
                      <div
                        key={event.event_id}
                        className="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg"
                      >
                        <div className={`p-2 rounded-full ${
                          event.event_type === 'in' ? 'bg-green-100' : 'bg-red-100'
                        }`}>
                          {event.event_type === 'in' ? (
                            <CheckCircle className="h-4 w-4 text-green-600" />
                          ) : (
                            <XCircle className="h-4 w-4 text-red-600" />
                          )}
                        </div>
                        <div className="flex-1">
                          <p className="font-medium text-gray-900">
                            {event.first_name} {event.last_name}
                          </p>
                          <p className="text-sm text-gray-600">
                            {event.event_type === 'in' ? 'Checked in' : 'Checked out'} • 
                            {new Date(event.event_ts).toLocaleTimeString()}
                          </p>
                          {event.score && (
                            <p className="text-xs text-gray-500">
                              Confidence: {(event.score * 100).toFixed(1)}%
                            </p>
                          )}
                        </div>
                        {event.image_url && (
                          <img
                            src={event.image_url}
                            alt="Event image"
                            className="w-12 h-12 rounded object-cover"
                          />
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </Card>
          </div>

          {/* Statistics Sidebar */}
          <div className="space-y-6">
            <Card>
              <div className="p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Session Statistics</h3>
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <CheckCircle className="h-5 w-5 text-green-600" />
                      <span className="text-gray-700">Present</span>
                    </div>
                    <span className="font-semibold text-green-600">{stats.present}</span>
                  </div>
                  
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <Clock className="h-5 w-5 text-yellow-600" />
                      <span className="text-gray-700">Late</span>
                    </div>
                    <span className="font-semibold text-yellow-600">{stats.late}</span>
                  </div>
                  
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-2">
                      <XCircle className="h-5 w-5 text-red-600" />
                      <span className="text-gray-700">Absent</span>
                    </div>
                    <span className="font-semibold text-red-600">{stats.absent}</span>
                  </div>
                  
                  <div className="border-t pt-4">
                    <div className="flex items-center justify-between">
                      <span className="font-medium text-gray-900">Total Students</span>
                      <span className="font-semibold">{stats.total}</span>
                    </div>
                  </div>
                </div>
              </div>
            </Card>

            <Card>
              <div className="p-6">
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Session Info</h3>
                <div className="space-y-2 text-sm">
                  <div className="flex justify-between">
                    <span className="text-gray-600">Subject:</span>
                    <span className="font-medium">{session?.subject}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Section:</span>
                    <span className="font-medium">{session?.section}</span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Started:</span>
                    <span className="font-medium">
                      {session?.start_ts ? new Date(session.start_ts).toLocaleTimeString() : 'N/A'}
                    </span>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-gray-600">Status:</span>
                    <span className="font-medium text-green-600">Active</span>
                  </div>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}
