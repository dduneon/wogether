import { useEffect, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'
import WorkoutCalendar from '../components/WorkoutCalendar'

const WEEK_LABELS = ['월', '화', '수', '목', '금', '토', '일']

export default function Home() {
  const { user } = useAuth()
  const navigate = useNavigate()
  const [data, setData] = useState(null)
  const [inviteCode, setInviteCode] = useState('')
  const [joining, setJoining] = useState(false)
  const [showJoin, setShowJoin] = useState(false)
  const [showCrewPicker, setShowCrewPicker] = useState(false)

  const handleLogCTA = () => {
    if (!data) return
    const { crews_data } = data
    if (crews_data.length === 0) return
    if (crews_data.length === 1) {
      navigate(`/crew/${crews_data[0].crew.id}/log/create`)
    } else {
      setShowCrewPicker(true)
    }
  }

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

  if (!data) return (
    <div className="page-wrap" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '60vh' }}>
      <div style={{ color: 'var(--text-dim)', fontSize: '.9rem' }}>불러오는 중…</div>
    </div>
  )

  const {
    unread, total_logs_this_week, total_goal_count, goal_remaining,
    quick_crew_id, streak, week_dots, today_logged,
    recent_feed, crews_data,
  } = data

  const totalPending = crews_data.reduce((sum, d) => sum + d.pending_count, 0)

  return (
    <div className="page-wrap">

      {/* ── 헤더 ── */}
      <div className="flex-between mb-16 fade-up" style={{ alignItems: 'flex-start' }}>
        <div>
          <div className="page-eyebrow">My Space</div>
          <div className="heading" style={{ marginBottom: 0 }}>
            안녕하세요, <span className="text-purple">{user?.nickname}</span>님 👋
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 4 }}>
          {unread > 0 && (
            <Link to="/notifications" className="tag tag-red" style={{ animation: 'pulse 2s infinite' }}>
              🔔 {unread}
            </Link>
          )}
          <button
            onClick={() => setShowJoin(v => !v)}
            className="tag"
            style={{ cursor: 'pointer', background: 'var(--bg-3)', border: '1px solid var(--border)', color: 'var(--text)' }}
            title="크루 참여 / 생성"
          >
            ＋ 크루
          </button>
        </div>
      </div>

      {/* ── 크루 참여 드롭다운 (접힘) ── */}
      {showJoin && (
        <div className="card fade-up" style={{ marginBottom: 16, padding: '16px 20px' }}>
          <form onSubmit={joinCrew} style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
            <input
              type="text"
              placeholder="초대코드 입력…"
              value={inviteCode}
              onChange={e => setInviteCode(e.target.value)}
              style={{ flex: 1 }}
              autoFocus
            />
            <button type="submit" className="btn btn-primary btn-sm" disabled={joining}>
              {joining ? '…' : '참여'}
            </button>
          </form>
          <Link to="/crew/create" className="btn btn-secondary btn-sm" style={{ width: '100%', textAlign: 'center' }}>
            + 새 크루 만들기
          </Link>
        </div>
      )}

      {/* ── 목표 승인 액션 카드 ── */}
      {totalPending > 0 && (
        <div className="fade-up" style={{
          background: 'linear-gradient(135deg,rgba(251,191,36,.1),rgba(251,191,36,.05))',
          border: '1px solid rgba(251,191,36,.35)',
          borderRadius: 'var(--radius)',
          padding: '14px 20px',
          marginBottom: 16,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          gap: 12,
        }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: '.9rem', color: 'var(--text)', marginBottom: 2 }}>
              🤝 목표 승인 요청 {totalPending}건
            </div>
            <div style={{ fontSize: '.78rem', color: 'var(--text-muted)' }}>
              팀원의 목표를 확인하고 승인해주세요
            </div>
          </div>
          <Link
            to={`/crew/${crews_data.find(d => d.pending_count > 0)?.crew.id}`}
            className="btn btn-sm"
            style={{ background: 'rgba(251,191,36,.2)', color: '#fbbf24', border: '1px solid rgba(251,191,36,.4)', whiteSpace: 'nowrap' }}
          >
            확인하기
          </Link>
        </div>
      )}

      {/* ── 스트릭 히어로 카드 ── */}
      <div className="streak-hero fade-up-1">
        <div className="streak-hero-left">
          <div className="streak-fire">{streak > 0 ? '🔥' : '💤'}</div>
          <div>
            <div className="streak-number">{streak}</div>
            <div className="streak-label">일 연속 운동</div>
          </div>
        </div>
        <div className="streak-hero-right">
          <div className="week-dots-row">
            {(week_dots || Array(7).fill(false)).map((done, i) => {
              const todayIdx = new Date().getDay() === 0 ? 6 : new Date().getDay() - 1
              const isToday = i === todayIdx
              return (
                <div key={i} className={`week-dot ${done ? 'week-dot-done' : ''} ${isToday ? 'week-dot-today' : ''}`}>
                  <span className="week-dot-label">{WEEK_LABELS[i]}</span>
                </div>
              )
            })}
          </div>
          <div className="week-count-row">
            <span className="week-count-num">{total_logs_this_week}</span>
            <span className="week-count-sep">/</span>
            <span className="week-count-goal">{total_goal_count || '—'}</span>
            <span className="week-count-unit">회</span>
            {goal_remaining > 0 && (
              <span className="week-remaining">아직 {goal_remaining}번 더!</span>
            )}
            {goal_remaining === 0 && total_goal_count > 0 && (
              <span className="week-remaining" style={{ color: 'var(--green)' }}>이번 주 달성! 🎉</span>
            )}
          </div>
        </div>
      </div>

      {/* ── 인증 CTA ── */}
      {today_logged ? (
        <div className="done-state-card fade-up-1">
          <span className="done-check">✅</span>
          <div>
            <div style={{ fontWeight: 700, color: 'var(--text)', fontSize: '.95rem' }}>오늘 인증 완료!</div>
            <div style={{ fontSize: '.78rem', color: 'var(--text-muted)', marginTop: 2 }}>내일도 화이팅 💪</div>
          </div>
          {quick_crew_id && (
            <Link to={`/crew/${quick_crew_id}/log/create`} className="btn btn-sm" style={{ marginLeft: 'auto', background: 'var(--bg-3)', border: '1px solid var(--border)' }}>
              추가 인증
            </Link>
          )}
        </div>
      ) : quick_crew_id ? (
        <button onClick={handleLogCTA} className="cta-hero fade-up-1" style={{ width: '100%', textAlign: 'left', cursor: 'pointer', font: 'inherit' }}>
          <span style={{ fontSize: '1.5rem' }}>📸</span>
          <div>
            <div style={{ fontWeight: 700, fontSize: '1.05rem' }}>오늘 운동 인증하기</div>
            <div style={{ fontSize: '.78rem', opacity: .7, marginTop: 2 }}>
              {crews_data.length > 1 ? '어느 크루에 인증할지 선택해요' : '사진을 올려서 크루에게 인증하세요'}
            </div>
          </div>
          <span style={{ marginLeft: 'auto', opacity: .6, fontSize: '1.2rem' }}>›</span>
        </button>
      ) : (
        <div className="fade-up-1 empty-state" style={{ padding: '28px 20px', marginBottom: 16 }}>
          <div className="empty-state-icon">🏃</div>
          <p>아직 속한 크루가 없어요.<br />크루를 만들거나 초대코드로 참여해보세요!</p>
          <button onClick={() => setShowJoin(true)} className="btn btn-primary mt-16">
            크루 참여하기
          </button>
        </div>
      )}

      {/* ── 내 크루 목록 ── */}
      {crews_data.length > 0 && (
        <div style={{ marginTop: 24 }}>
          <div className="section-label fade-up-2">내 크루 {crews_data.length}</div>
          <div className="fade-up-2" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {crews_data.map(d => {
              const { crew, my_pct, crew_logs_count, crew_goal_remaining, pending_count, members } = d
              const pctClass = my_pct >= 100 ? 'text-green' : my_pct >= 50 ? 'text-yellow' : 'text-muted'
              const fillClass = my_pct >= 100 ? 'green' : my_pct >= 50 ? 'yellow' : ''
              return (
                <Link key={crew.id} to={`/crew/${crew.id}`} className="crew-card">
                  <div className="crew-card-inner">
                    <div className="crew-card-top">
                      <div className="crew-card-name">{crew.name}</div>
                      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                        {pending_count > 0 && (
                          <span className="crew-pending-badge">🤝 {pending_count}</span>
                        )}
                        {crew_goal_remaining === 0 && my_pct >= 100 && (
                          <span style={{ fontSize: '.72rem', color: 'var(--green)', fontWeight: 700 }}>✅ 달성</span>
                        )}
                      </div>
                    </div>
                    {crew.description && (
                      <div className="crew-card-desc">{crew.description}</div>
                    )}

                    {/* 팀원 아바타 */}
                    {members && members.length > 0 && (
                      <div className="member-avatar-row">
                        {members.map(m => (
                          <div
                            key={m.id}
                            className={`member-avatar ${m.logged_today ? 'member-avatar-active' : 'member-avatar-idle'} ${m.is_me ? 'member-avatar-me' : ''}`}
                            title={`${m.nickname}${m.logged_today ? ' · 오늘 인증 완료' : ' · 미인증'}`}
                          >
                            {m.nickname[0]}
                          </div>
                        ))}
                        <div style={{ fontSize: '.72rem', color: 'var(--text-dim)', marginLeft: 4, alignSelf: 'center' }}>
                          {members.filter(m => m.logged_today).length}/{members.length}명 인증
                        </div>
                      </div>
                    )}

                    <div className="crew-card-progress-label">
                      <span>내 이번 주 달성률</span>
                      <span className={pctClass} style={{ fontWeight: 700, fontFamily: "'Space Mono', monospace" }}>
                        {my_pct}%
                        {crew_goal_remaining > 0 && (
                          <span style={{ fontWeight: 400, fontSize: '.72rem', color: 'var(--text-dim)', marginLeft: 6 }}>
                            ({crew_goal_remaining}번 남음)
                          </span>
                        )}
                      </span>
                    </div>
                    <div className="progress-track" style={{ marginBottom: 10 }}>
                      <div className={`progress-fill ${fillClass}`} style={{ width: `${my_pct}%` }} />
                    </div>
                    <div className="crew-card-meta-row">
                      <span className="crew-card-meta">
                        <span className="crew-card-dot" />
                        {crew.member_count}명
                      </span>
                      <span className="crew-card-meta">🔥 이번 주 {crew_logs_count}회</span>
                    </div>
                  </div>
                </Link>
              )
            })}
          </div>
        </div>
      )}

      {/* ── 미니 소셜 피드 ── */}
      {recent_feed && recent_feed.length > 0 && (
        <div style={{ marginTop: 28 }}>
          <div className="section-label fade-up-3">최근 팀 활동</div>
          <div className="card fade-up-3" style={{ padding: 0, overflow: 'hidden' }}>
            {recent_feed.map((item, idx) => (
              <Link
                key={item.log_id}
                to={`/crew/${item.crew_id}`}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                  padding: '13px 18px',
                  borderBottom: idx < recent_feed.length - 1 ? '1px solid var(--border)' : 'none',
                  textDecoration: 'none',
                  transition: 'background .15s',
                }}
                onMouseEnter={e => e.currentTarget.style.background = 'var(--bg-3)'}
                onMouseLeave={e => e.currentTarget.style.background = 'transparent'}
              >
                <div className="feed-avatar">{item.nickname[0]}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: '.85rem', color: 'var(--text)', lineHeight: 1.4 }}>
                    <span style={{ fontWeight: 700 }}>{item.nickname}</span>
                    <span style={{ color: 'var(--text-muted)' }}>님이 </span>
                    <span style={{ color: 'var(--purple-l)', fontWeight: 600 }}>{item.crew_name}</span>
                    <span style={{ color: 'var(--text-muted)' }}>에 인증했어요</span>
                  </div>
                  {item.caption && (
                    <div style={{ fontSize: '.75rem', color: 'var(--text-dim)', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {item.caption}
                    </div>
                  )}
                  <div style={{ fontSize: '.7rem', color: 'var(--text-dim)', marginTop: 2 }}>{item.time_ago}</div>
                </div>
                {item.thumbnail_url && (
                  <img
                    src={item.thumbnail_url}
                    alt=""
                    style={{ width: 44, height: 44, borderRadius: 8, objectFit: 'cover', flexShrink: 0, border: '1px solid var(--border-h)' }}
                  />
                )}
              </Link>
            ))}
          </div>
        </div>
      )}

      {/* ── 운동 달력 ── */}
      <div style={{ marginTop: 28 }}>
        <div className="section-label fade-up-3">운동 달력</div>
        <WorkoutCalendar />
      </div>

      {/* ── 크루 선택 모달 ── */}
      {showCrewPicker && (
        <div
          className="modal-backdrop"
          onClick={() => setShowCrewPicker(false)}
        >
          <div
            className="crew-picker-sheet"
            onClick={e => e.stopPropagation()}
          >
            <div className="crew-picker-handle" />
            <div className="crew-picker-title">어느 크루에 인증할까요?</div>
            <div className="crew-picker-list">
              {crews_data.map(d => (
                <button
                  key={d.crew.id}
                  className="crew-picker-item"
                  onClick={() => {
                    setShowCrewPicker(false)
                    navigate(`/crew/${d.crew.id}/log/create`)
                  }}
                >
                  <div className="crew-picker-icon">
                    {d.crew.name[0].toUpperCase()}
                  </div>
                  <div style={{ flex: 1, minWidth: 0, textAlign: 'left' }}>
                    <div style={{ fontWeight: 700, fontSize: '.95rem', color: 'var(--text)' }}>{d.crew.name}</div>
                    <div style={{ fontSize: '.75rem', color: 'var(--text-muted)', marginTop: 2 }}>
                      멤버 {d.crew.member_count}명 · 이번 주 {d.crew_logs_count}회 인증
                    </div>
                  </div>
                  <span style={{ color: 'var(--text-dim)', fontSize: '1rem' }}>›</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

    </div>
  )
}
