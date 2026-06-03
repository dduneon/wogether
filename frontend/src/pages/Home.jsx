import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'

export default function Home() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [crews, setCrews] = useState([])
  const [loading, setLoading] = useState(true)
  const [joinCode, setJoinCode] = useState('')
  const [joining, setJoining] = useState(false)

  useEffect(() => {
    client.get('/crews').then(r => setCrews(r.data)).finally(() => setLoading(false))
  }, [])

  const handleJoin = async (e) => {
    e.preventDefault()
    setJoining(true)
    try {
      const res = await client.post('/crews/join', { invite_code: joinCode.trim() })
      navigate(`/crew/${res.data.id}`)
    } catch (err) {
      alert(err.response?.data?.error || '크루 참여에 실패했습니다.')
    } finally {
      setJoining(false)
    }
  }

  if (loading) return (
    <div className="flex items-center justify-center min-h-[60vh]">
      <div className="text-gray-400">불러오는 중...</div>
    </div>
  )

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-bold">{user.nickname}님, 안녕하세요 👋</h1>
          <p className="text-sm text-gray-500">오늘도 함께 운동해요!</p>
        </div>
        <Link to="/crew/create"
          className="bg-indigo-600 text-white text-sm px-4 py-2 rounded-lg font-medium hover:bg-indigo-700">
          + 크루 만들기
        </Link>
      </div>

      {/* 크루 참여 폼 */}
      <form onSubmit={handleJoin} className="flex gap-2 mb-6">
        <input
          type="text"
          placeholder="초대 코드로 크루 참여"
          value={joinCode}
          onChange={e => setJoinCode(e.target.value)}
          className="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
        />
        <button type="submit" disabled={joining || !joinCode.trim()}
          className="bg-gray-900 text-white text-sm px-4 py-2 rounded-lg font-medium hover:bg-gray-700 disabled:opacity-40">
          {joining ? '...' : '참여'}
        </button>
      </form>

      {/* 크루 목록 */}
      {crews.length === 0 ? (
        <div className="text-center py-16 text-gray-400">
          <p className="text-4xl mb-3">🏋️</p>
          <p className="font-medium">아직 크루가 없어요</p>
          <p className="text-sm mt-1">크루를 만들거나 초대 코드로 참여해보세요!</p>
        </div>
      ) : (
        <div className="space-y-3">
          {crews.map(crew => (
            <Link key={crew.id} to={`/crew/${crew.id}`}
              className="block bg-white rounded-2xl border border-gray-200 p-4 hover:border-indigo-300 hover:shadow-sm transition-all">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="font-semibold text-gray-900">{crew.name}</h2>
                  {crew.description && (
                    <p className="text-sm text-gray-500 mt-0.5 line-clamp-1">{crew.description}</p>
                  )}
                </div>
                <span className="text-sm text-gray-400">{crew.member_count}명 →</span>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
