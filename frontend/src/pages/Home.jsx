import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'
import { kstShort } from '../utils/time'
import WorkoutCalendar from '../components/WorkoutCalendar'

export default function Home() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [inviteCode, setInviteCode] = useState('')
  const [joining, setJoining] = useState(false)

  useEffect(() => {
    client.get('/dashboard').then(r => setData(r.data)).catch(() => {})
  }, [])

  const joinCrew = async (e) => {
    e.preventDefault()
    if (!inviteCode.trim()) return
    setJoining(true)
    try {
      const r = await client.post('/crews/join', { invite_code: inviteCode.trim() })
      navigate(`/crew/${r.data.id}`)
    } catch (err) {
      alert(err.response?.data?.error || '참여에 실패했어요.')
    } finally {
      setJoining(false)
    }
  }

  if (!data) return null

  const { unread, total_logs_this_week, quick_crew_id, crews_data } = data

  return (
    <div className="page-wrap">
      {/* 헤더 */}
      <div className="flex-between mb-16 fade-up">
        <div>
          <div className="page-eyebrow">My Space</div>
          <div className="heading">
            안녕하세요, <span className="text-purple">{user?.nickname}</span>님 👋
          </div>
        </div>
        {unread > 0 && (
          <Link to="/notifications" className="tag tag-red" style={{ animation: 'pulse 2s infinite' }}>
            🔔 {unread}
          </Link>
        )}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, alignItems: 'start' }} className="home-two-col">
        {/* 왼쪽: 주간 요약 + 크루 참여 + 달력 */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div className="week-summary-card fade-up-1">
            <div className="week-summary-left">
              <div className="week-summary-label">이번 주 내 인증</div>
              <div className="week-summary-count">
                {total_logs_this_week}<span className="week-summary-unit">회</span>
              </div>
            </div>
            <div className="week-summary-divider" />
            <div className="week-summary-right">
              {quick_crew_id ? (
                <>
                  <div className="week-summary-label">오늘 운동했나요?</div>
                  <Link to={`/crew/${quick_crew_id}/log/create`} className="btn btn-primary btn-sm" style={{ marginTop: 8 }}>
                    📸 바로 인증하기
                  </Link>
                </>
              ) : (
                <>
                  <div className="week-summary-label">아직 크루가 없어요</div>
                  <Link to="/crew/create" className="btn btn-secondary btn-sm" style={{ marginTop: 8 }}>
                    + 크루 만들기
                  </Link>
                </>
              )}
            </div>
          </div>

          <div className="card join-card fade-up-2">
            <form onSubmit={joinCrew} className="join-input-row">
              <input
                type="text"
                placeholder="초대코드로 크루 참여…"
                value={inviteCode}
                onChange={e => setInviteCode(e.target.value)}
              />
              <button type="submit" className="btn btn-primary btn-sm" disabled={joining}>
                {joining ? '…' : '참여'}
              </button>
            </form>
            <Link to="/crew/create" className="btn btn-secondary btn-sm">+ 새 크루</Link>
          </div>

          <WorkoutCalendar />
        </div>

        {/* 오른쪽: 크루 목록 */}
        <div>
          <div className="section-label fade-up-3">내 크루 {crews_data.length}</div>
          {crews_data.length > 0 ? (
            <div className="fade-up-3" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {crews_data.map(d => {
                const { crew, my_pct, crew_logs_count, last_log_timestamp, pending_count } = d
                const pctClass = my_pct >= 100 ? 'text-green' : my_pct >= 50 ? 'text-yellow' : 'text-muted'
                const fillClass = my_pct >= 100 ? 'green' : my_pct >= 50 ? 'yellow' : ''
                return (
                  <Link key={crew.id} to={`/crew/${crew.id}`} className="crew-card">
                    <div className="crew-card-inner">
                      <div className="crew-card-top">
                        <div className="crew-card-name">{crew.name}</div>
                        {pending_count > 0 && (
                          <span className="crew-pending-badge">🤝 {pending_count}</span>
                        )}
                      </div>
                      {crew.description && (
                        <div className="crew-card-desc">{crew.description}</div>
                      )}
                      <div className="crew-card-progress-label">
                        <span>내 이번 주 달성률</span>
                        <span className={pctClass} style={{ fontWeight: 700, fontFamily: "'Space Mono', monospace" }}>
                          {my_pct}%
                        </span>
                      </div>
                      <div className="progress-track" style={{ marginBottom: 14 }}>
                        <div className={`progress-fill ${fillClass}`} style={{ width: `${my_pct}%` }} />
                      </div>
                      <div className="crew-card-meta-row">
                        <span className="crew-card-meta">
                          <span className="crew-card-dot" />
                          {crew.member_count}명
                        </span>
                        <span className="crew-card-meta">🔥 이번 주 {crew_logs_count}회</span>
                        <span className="crew-card-meta">
                          {last_log_timestamp ? `🕐 ${kstShort(last_log_timestamp)}` : '아직 인증 없음'}
                        </span>
                      </div>
                    </div>
                  </Link>
                )
              })}
            </div>
          ) : (
            <div className="empty-state fade-up-3">
              <div className="empty-state-icon">🏃</div>
              <p>아직 속한 크루가 없어요.<br />크루를 만들거나 초대코드로 참여해보세요!</p>
              <Link to="/crew/create" className="btn btn-primary mt-16">첫 크루 만들기</Link>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
