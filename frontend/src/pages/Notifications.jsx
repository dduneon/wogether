import { useEffect, useState } from 'react'
import client from '../api/client'

function formatTime(iso) {
  if (!iso) return ''
  const d = new Date(iso + 'Z')
  const diff = Math.floor((Date.now() - d) / 86400000)
  if (diff === 0) return `오늘 ${d.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' })}`
  if (diff === 1) return '어제'
  return d.toLocaleDateString('ko-KR', { month: 'numeric', day: 'numeric' })
}

const TYPE_ICON = {
  nudge: '👉',
  goal_request: '✋',
  goal_approved: '💪',
  join: '🎉',
}

export default function Notifications() {
  const [notis, setNotis] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([
      client.get('/notifications'),
      client.post('/notifications/read'),
    ]).then(([res]) => setNotis(res.data))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return (
    <div className="flex items-center justify-center min-h-[60vh]">
      <div className="text-gray-400">불러오는 중...</div>
    </div>
  )

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      <h1 className="text-xl font-bold mb-6">알림</h1>
      {notis.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <p className="text-4xl mb-3">🔔</p>
          <p>새로운 알림이 없어요</p>
        </div>
      ) : (
        <div className="space-y-2">
          {notis.map(n => (
            <div key={n.id}
              className={`bg-white rounded-xl border p-4 ${n.is_read ? 'border-gray-200' : 'border-indigo-200 bg-indigo-50'}`}>
              <div className="flex items-start gap-3">
                <span className="text-xl">{TYPE_ICON[n.type] || '🔔'}</span>
                <div className="flex-1 min-w-0">
                  <p className="text-sm text-gray-800">{n.message}</p>
                  <p className="text-xs text-gray-400 mt-1">{formatTime(n.created_at)}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
