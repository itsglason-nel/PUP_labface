import { io, Socket } from 'socket.io-client'

const WS_URL = process.env.NEXT_PUBLIC_WS_URL || 'http://localhost:4000'

class SocketService {
  private socket: Socket | null = null
  private reconnectAttempts = 0
  private maxReconnectAttempts = 5

  connect(token: string) {
    if (this.socket?.connected) {
      return this.socket
    }

    this.socket = io(WS_URL, {
      auth: {
        token
      },
      transports: ['websocket', 'polling']
    })

    this.socket.on('connect', () => {
      console.log('Connected to server')
      this.reconnectAttempts = 0
    })

    this.socket.on('disconnect', () => {
      console.log('Disconnected from server')
    })

    this.socket.on('connect_error', (error) => {
      console.error('Connection error:', error)
      this.handleReconnect()
    })

    return this.socket
  }

  private handleReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++
      const delay = Math.pow(2, this.reconnectAttempts) * 1000
      
      setTimeout(() => {
        console.log(`Attempting to reconnect (${this.reconnectAttempts}/${this.maxReconnectAttempts})`)
        this.socket?.connect()
      }, delay)
    }
  }

  joinAttendanceRoom(sessionId: string) {
    if (this.socket?.connected) {
      this.socket.emit('join-attendance', sessionId)
    }
  }

  leaveAttendanceRoom(sessionId: string) {
    if (this.socket?.connected) {
      this.socket.emit('leave-attendance', sessionId)
    }
  }

  onPresenceEvent(callback: (event: any) => void) {
    if (this.socket) {
      this.socket.on('presence-event', callback)
    }
  }

  onSessionStatus(callback: (status: any) => void) {
    if (this.socket) {
      this.socket.on('session-status', callback)
    }
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect()
      this.socket = null
    }
  }

  getSocket() {
    return this.socket
  }
}

export const socketService = new SocketService()
export default socketService
