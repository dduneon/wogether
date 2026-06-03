import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'

function formatTime(iso) {
  if (!iso) return ''
  const d = new Date(iso + 'Z')
  const now = new Date()
  const diff = Math.floor((now - d) / 86400000)
  if (diff === 0) return `오늘 ${d.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' })}`
  if (diff === 1) return '어제'
  if (diff < 7) return `${diff}일 전`
  return d.toLocaleDateString('ko-KR', { month: 'numeric', day: 'numeric' })
}

export default function CrewDetail() {
  const { id } = useParams()
  const { user } = useAuth()
  const [data, setData] = useState(null)
  const [logs, setLogs] = useState([])
  const [loading, setLoading] = useState(true)

  const fetchData = () => {
    Promise.all([
      client.get(`/crews/${id}`),
      client.get(`/crews/${id}/logs`),
    ]).then(([crewRes, logsRes]) => {
      setData(crewRes.data)
      setLogs(logsRes.data)
    }).finally(() => setLoading(false))
  }

  useEffect(() => { fetchData() }, [id])

  const handleApprove = async (goalId) => {
    await client.post(`/goals/${goalId}/approve`)
    fetchData()
  }

  const handleNudge = async (targetUserId) => {
    try {
      await client.post(`/crews/${id}/nudge/${targetUserId}`)
      alert('독촉 알림을 보냈어요!')
    } catch (err) {
      alert(err.response?.data?.error || '독촉 실패')
    }
  }

  const handleLike = async (logId) => {
    const res = await client.post(`/logs/${logId}/like`)
    setLogs(prev => prev.map(l => l.id === logId
      ? { ...l, like_count: res.data.count, liked: res.data.liked }
      : l
    ))
  }

  if (loading) return (
    <div className="flex items-center justify-center min-h-[60vh]">
      <div className="text-gray-400">불러오는 중...</div>
    </div>
  )
  if (!data) return null

  const { crew, members } = data
  const pendingGoals = members.flatMap(m =>
    m.goals.filter(g => g.status === 'pending' && g.user_id !== user.id &&
      g.approval.approved < g.approval.total)
  )

  return (
    <div className="max-w-2xl mx-auto px-4 py-6 space-y-6">
      {/* 헤더 */}
      <div className="flex items-start justify-between">
        <div>
          <h1 className="text-xl font-bold">{crew.name}</h1>
          {crew.description && <p className="text-sm text-gray-500 mt-0.5">{crew.description}</p>}
          <p className="text-xs text-gray-400 mt-1">초대 코드: <span className="font-mono font-medium text-gray-700">{crew.invite_code}</span></p>
        </div>
        <Link to={`/crew/${id}/log/create`}
          className="bg-indigo-600 text-white text-sm px-4 py-2 rounded-lg font-medium hover:bg-indigo-700 shrink-0">
          + 인증
        </Link>
      </div>

      {/* 승인 대기 목표 */}
      {pendingGoals.length > 0 && (
        <div className="bg-amber-50 border border-amber-200 rounded-2xl p-4">
          <p className="text-sm font-semibold text-amber-800 mb-2">동의 요청 ({pendingGoals.length})</p>
          <div className="space-y-2">
            {pendingGoals.map(g => (
              <div key={g.id} className="flex items-center justify-between">
                <div>
                  <span className="text-sm font-medium">{g.title}</span>
                  <span className="text-xs text-gray-500 ml-2">주 {g.frequency_per_week}회</span>
                </div>
                <button onClick={() => handleApprove(g.id)}
                  className="text-xs bg-amber-600 text-white px-3 py-1 rounded-lg hover:bg-amber-700">
                  동의
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 멤버 현황 */}
      <div className="bg-white rounded-2xl border border-gray-200 p-4">
        <div className="flex items-center justify-between mb-3">
          <h2 className="font-semibold">멤버 현황</h2>
          <Link to={`/crew/${id}/goal/create`}
            className="text-xs text-indigo-600 font-medium">+ 목표 추가</Link>
        </div>
        <div className="space-y-3">
          {members.map(m => (
            <div key={m.user.id}>
              <div className="flex items-center justify-between mb-1">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">{m.user.nickname}</span>
                  {m.role === 'owner' && <span className="text-xs text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded">크루장</span>}
                </div>
                <div className="flex items-center gap-2">
                  <span className="text-xs text-gray-500">{m.avg_percent}%</span>
                  {m.user.id !== user.id && (
                    <button onClick={() => handleNudge(m.user.id)}
                      className="text-xs text-gray-400 hover:text-indigo-600">
                      👉 독촉
                    </button>
                  )}
                </div>
              </div>
              <div className="h-1.5 bg-gray-100 rounded-full overflow-hidden">
                <div className="h-full bg-indigo-500 rounded-full transition-all"
                  style={{ width: `${m.avg_percent}%` }} />
              </div>
              <div className="flex flex-wrap gap-1 mt-1.5">
                {m.goals.map(g => (
                  <span key={g.id}
                    className={`text-xs px-2 py-0.5 rounded-full ${g.status === 'approved' ? 'bg-indigo-50 text-indigo-700' : 'bg-gray-100 text-gray-500'}`}>
                    {g.title} ({g.progress.done}/{g.progress.target})
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* 운동 피드 */}
      <div>
        <h2 className="font-semibold mb-3">최근 인증</h2>
        {logs.length === 0 ? (
          <div className="text-center py-8 text-gray-400 text-sm">아직 인증이 없어요</div>
        ) : (
          <div className="space-y-4">
            {logs.map(log => (
              <div key={log.id} className="bg-white rounded-2xl border border-gray-200 overflow-hidden">
                {log.images.length > 0 && (
                  <img src={log.images[0]} alt="" className="w-full object-cover max-h-80" />
                )}
                <div className="p-4">
                  <div className="flex items-center justify-between mb-2">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-medium">{log.user.nickname}</span>
                      {log.workout_type && (
                        <span className="text-xs text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded-full">
                          {log.workout_type}
                        </span>
                      )}
                    </div>
                    <span className="text-xs text-gray-400">{formatTime(log.timestamp)}</span>
                  </div>
                  {log.caption && <p className="text-sm text-gray-700 mb-3">{log.caption}</p>}
                  <button onClick={() => handleLike(log.id)}
                    className={`flex items-center gap-1 text-sm ${log.liked ? 'text-red-500' : 'text-gray-400 hover:text-red-400'}`}>
                    {log.liked ? '❤️' : '🤍'} {log.like_count}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
