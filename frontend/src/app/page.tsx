'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Card } from '@/components/ui/Card'
import { Button } from '@/components/ui/Button'

export default function Home() {
  const router = useRouter()

  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="max-w-md w-full space-y-8">
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-2">LabFace</h1>
          <p className="text-gray-600">AI-Powered Attendance System</p>
        </div>
        
        <Card className="p-8">
          <div className="space-y-4">
            <h2 className="text-2xl font-semibold text-center mb-6">Choose Your Role</h2>
            
            <Button
              onClick={() => router.push('/professor/login')}
              className="w-full"
              size="lg"
            >
              Professor Login
            </Button>
            
            <Button
              onClick={() => router.push('/student/login')}
              variant="secondary"
              className="w-full"
              size="lg"
            >
              Student Login
            </Button>
            
            <div className="text-center text-sm text-gray-500 mt-6">
              <p>New to LabFace?</p>
              <div className="space-x-4 mt-2">
                <button
                  onClick={() => router.push('/professor/register')}
                  className="text-primary-600 hover:text-primary-700"
                >
                  Register as Professor
                </button>
                <span>•</span>
                <button
                  onClick={() => router.push('/student/register')}
                  className="text-primary-600 hover:text-primary-700"
                >
                  Register as Student
                </button>
              </div>
            </div>
          </div>
        </Card>
      </div>
    </div>
  )
}
