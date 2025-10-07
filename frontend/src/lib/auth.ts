export interface User {
  id: string
  type: 'student' | 'professor'
  email: string
  first_name?: string
  last_name?: string
}

export interface AuthResponse {
  token: string
  user: User
}

export function getToken(): string | null {
  if (typeof window === 'undefined') return null
  return localStorage.getItem('token')
}

export function getUser(): User | null {
  if (typeof window === 'undefined') return null
  const userStr = localStorage.getItem('user')
  return userStr ? JSON.parse(userStr) : null
}

export function setAuth(token: string, user: User): void {
  if (typeof window === 'undefined') return
  localStorage.setItem('token', token)
  localStorage.setItem('user', JSON.stringify(user))
}

export function clearAuth(): void {
  if (typeof window === 'undefined') return
  localStorage.removeItem('token')
  localStorage.removeItem('user')
}

export function isAuthenticated(): boolean {
  return !!getToken()
}

export function isProfessor(): boolean {
  const user = getUser()
  return user?.type === 'professor'
}

export function isStudent(): boolean {
  const user = getUser()
  return user?.type === 'student'
}
