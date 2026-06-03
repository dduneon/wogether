import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import { useEffect, useState } from 'react'
import client from '../api/client'

export default function Navbar() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const [unread, setUnread] = useState(0)

  useEffect(() => {
    if (!user) return
    client.get('/notifications/unread-count')
      .then(r => setUnread(r.data.count))
      .catch(() => {})
    const interval = setInterval(() => {
      client.get('/notifications/unread-count')
        .then(r => setUnread(r.data.count))
        .catch(() => {})
    }, 30000)
    return () => clearInterval(interval)
  }, [user])

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  return (
    <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
      <div className="max-w-2xl mx-auto px-4 h-14 flex items-center justify-between">
        <Link to="/" className="font-bold text-lg text-indigo-600 tracking-tight">
          워게더
        </Link>
        {user && (
          <div className="flex items-center gap-3">
            <Link to="/notifications" className="relative p-2 text-gray-500 hover:text-gray-900">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                  d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6 6 0 10-12 0v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
              {unread > 0 && (
                <span className="absolute top-1 right-1 bg-red-500 text-white text-xs rounded-full w-4 h-4 flex items-center justify-center">
                  {unread > 9 ? '9+' : unread}
                </span>
              )}
            </Link>
            <span className="text-sm text-gray-600">{user.nickname}</span>
            <button onClick={handleLogout}
              className="text-sm text-gray-500 hover:text-gray-900">
              로그아웃
            </button>
          </div>
        )}
      </div>
    </nav>
  )
}
