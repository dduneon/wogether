import { useEffect, useRef, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'
import { kstFull, kstShort } from '../utils/time'

const ACTIVITY_ICON = { join: '👋', goal_added: '🎯', goal_approved: '✅', goal_completed: '🏆' }

export default function CrewDetail() {
  const { id } = useParams()
  const { user } = useAuth()
  const [data, setData] = useState(null)
  const [tab, setTab] = useState('feed')

  const nudgeCooldowns = useRef({})

  const load = () => client.get(`/crews/${id}`).then(r => setData(r.data)).catch(() => {})

  useEffect(() => { load() }, [id])

  if (!data) return null
  const { crew, members, feed_items, pending_for_me } = data

  const shareInvite = () => {
    const url = `${location.origin}/join/${crew.invite_code}`
    const msg = `[Wogether] ${crew.name} 크루에 초대합니다!\n함께 운동 목표를 달성해요 💪\n${url}`
    if (navigator.share) {
      navigator.share({ title: 'Wogether 크루 초대', text: msg, url }).catch(() => {})
      return
    }
    navigator.clipboard.writeText(url).then(() => alert('초대링크가 복사됐어요!')).catch(() => prompt('초대링크를 복사하세요', url))
  }

  const approvePending = async (goalId) => {
    try {
      await client.post(`/goals/${goalId}/approve`)
      load()
    } catch {}
  }

  const deleteGoal = async (goalId) => {
    if (!confirm('목표를 삭제할까요?')) return
    try {
      await client.delete(`/goals/${goalId}`)
      load()
    } catch {}
  }

  const nudge = async (targetId) => {
    const last = nudgeCooldowns.current[targetId]
    if (last && Date.now() - last < 10000) {
      alert('10초에 한 번만 콕! 찌를 수 있어요.')
      return
    }
    try {
      await client.post(`/crews/${id}/nudge/${targetId}`)
      nudgeCooldowns.current[targetId] = Date.now()
      alert('콕! 찔렀어요 👉')
    } catch (e) {
      alert(e?.response?.data?.error || '1분에 한 번만 콕! 찌를 수 있어요.')
    }
  }

  const toggleLike = async (logId, currentLiked, currentCount, idx) => {
    try {
      const r = await client.post(`/logs/${logId}/like`)
      setData(prev => {
        const items = [...prev.feed_items]
        items[idx] = { ...items[idx], data: { ...items[idx].data, like_count: r.data.count, is_liked: r.data.liked } }
        return { ...prev, feed_items: items }
      })
    } catch {}
  }

  const deleteLog = async (logId) => {
    if (!confirm('인증을 삭제할까요?')) return
    try {
      await client.delete(`/logs/${logId}`)
      load()
    } catch {}
  }

  const leaveCrew = async () => {
    if (!confirm(`"${crew.name}" 크루에서 나갈까요?`)) return
    try {
      await client.post(`/crews/${id}/leave`)
      window.location.href = '/'
    } catch {}
  }

  return (
    <div className="page-wrap">
      {/* Hero */}
      <div className="fade-up mb-24">
        <div className="page-eyebrow">Crew</div>
        <div className="crew-hero-row">
          <div>
            <h1 className="crew-hero-name gradient-text">{crew.name}</h1>
            {crew.description && <p className="crew-hero-desc">{crew.description}</p>}
          </div>
          <div className="crew-hero-side">
            <button className="invite-icon-btn" onClick={shareInvite} title="초대링크 공유">🔗</button>
            {crew.owner_id !== user?.id && (
              <button className="btn btn-ghost btn-sm" onClick={leaveCrew}>나가기</button>
            )}
          </div>
        </div>
        <div className="crew-meta-row">
          <span className="crew-meta-item">👥 {crew.member_count}명</span>
        </div>
        <div className="crew-actions">
          <Link to={`/crew/${id}/goal/create`} className="btn btn-secondary btn-action">🎯 목표 추가</Link>
          <Link to={`/crew/${id}/log/create`} className="btn btn-primary btn-action">📸 운동 인증</Link>
        </div>
      </div>

      {/* 동의 대기 배너 */}
      {pending_for_me?.length > 0 && (
        <div className="pending-banner fade-up-1">
          <div className="pending-banner-title">🤝 동의 대기 중인 목표 {pending_for_me.length}개</div>
          {pending_for_me.map(g => (
            <div key={g.id} className="pending-row">
              <span>
                <span className="text-muted">{g.user_nickname}</span>
                &nbsp;—&nbsp;
                <strong>{g.title}</strong>
                <span className="tag tag-yellow" style={{ marginLeft: 6 }}>주 {g.frequency_per_week}회</span>
              </span>
              <button className="btn btn-cyan btn-sm" onClick={() => approvePending(g.id)}>동의 ✓</button>
            </div>
          ))}
        </div>
      )}

      {/* 탭 */}
      <div className="crew-tabs fade-up-2">
        <button className={`crew-tab${tab === 'feed' ? ' active' : ''}`} onClick={() => setTab('feed')}>📸 인증 피드</button>
        <button className={`crew-tab${tab === 'status' ? ' active' : ''}`} onClick={() => setTab('status')}>📊 현황</button>
      </div>

      {/* 현황 탭 */}
      {tab === 'status' && (
        <div className="tab-panel">
          <div className="member-grid">
            {members.map(m => {
              const pct = m.avg_percent
              const pctClass = pct >= 100 ? 'hot' : pct >= 50 ? 'mid' : pct > 0 ? 'cold' : 'zero'
              const fillClass = pct >= 100 ? 'green' : pct >= 50 ? 'yellow' : ''
              return (
                <div key={m.user.id} className="member-card">
                  <div className="member-top">
                    <div>
                      <div className="member-nickname">
                        {m.user.nickname}
                        {m.role === 'owner' && <span className="tag tag-purple" style={{ marginLeft: 6 }}>크루장</span>}
                      </div>
                    </div>
                    <div className={`member-pct ${pctClass}`}>{pct}%</div>
                  </div>
                  <div className="progress-track" style={{ marginBottom: 14 }}>
                    <div className={`progress-fill ${fillClass}`} style={{ width: `${pct}%` }} />
                  </div>
                  {m.goals.length > 0 ? (
                    <div style={{ marginBottom: 12 }}>
                      {m.goals.map(g => (
                        <div key={g.id} className="goal-item">
                          <span className="goal-item-title">{g.title}</span>
                          <span className="goal-item-prog">{g.progress.done}/{g.progress.target}</span>
                          {g.status === 'pending' && <span className="tag tag-yellow">대기</span>}
                          {g.user_id === user?.id && (
                            <button className="btn btn-ghost btn-sm" style={{ padding: '2px 8px' }} onClick={() => deleteGoal(g.id)}>✕</button>
                          )}
                        </div>
                      ))}
                    </div>
                  ) : (
                    <p style={{ fontSize: '.82rem', color: 'var(--text-dim)', marginBottom: 12 }}>목표 없음</p>
                  )}
                  {m.user.id !== user?.id && (
                    <button className="btn btn-secondary btn-full btn-sm nudge-btn" onClick={() => nudge(m.user.id)}>
                      👉 운동하라고 콕!
                    </button>
                  )}
                </div>
              )
            })}
          </div>
        </div>
      )}

      {/* 인증 피드 탭 */}
      {tab === 'feed' && (
        <div className="tab-panel">
          {feed_items?.length > 0 ? (
            <div className="sns-feed">
              {feed_items.map((item, idx) => {
                if (item.type === 'log') {
                  const log = item.data
                  const imgCount = log.images?.length || 0
                  const imgClass = imgCount === 1 ? '' : imgCount === 2 ? 'cols-2' : 'cols-3'
                  return (
                    <div key={`log-${log.id}`} className="sns-post">
                      <div className="sns-post-header">
                        <div className="sns-avatar">{log.user?.nickname?.[0]}</div>
                        <div>
                          <div className="sns-author-name">{log.user?.nickname}</div>
                          <div className="sns-post-time">{kstFull(log.timestamp)}</div>
                        </div>
                        {log.workout_type && (
                          <div className="sns-workout-badge">
                            <span className="tag tag-cyan">{log.workout_type}</span>
                          </div>
                        )}
                      </div>
                      {imgCount > 0 ? (
                        imgCount === 1 ? (
                          <div className="sns-post-images">
                            <img src={log.images[0]} className="sns-post-img" alt="운동 인증" />
                          </div>
                        ) : (
                          <div className={`sns-multi-img ${imgClass}`}>
                            {log.images.slice(0, 3).map((url, i) => <img key={i} src={url} alt="" />)}
                          </div>
                        )
                      ) : (
                        <div className="sns-post-img-placeholder">🏋️</div>
                      )}
                      {log.caption && (
                        <div className="sns-post-body">
                          <p className="sns-caption">
                            <span className="sns-author-handle">{log.user?.nickname}</span>
                            {log.caption}
                          </p>
                        </div>
                      )}
                      <div className="sns-post-actions">
                        <button
                          className={`sns-action-btn${log.is_liked ? ' liked' : ''}`}
                          onClick={() => toggleLike(log.id, log.is_liked, log.like_count, idx)}
                        >
                          💪 <span>{log.like_count}</span>
                        </button>
                        {log.user?.id === user?.id && (
                          <button className="sns-delete-btn" onClick={() => deleteLog(log.id)}>🗑 삭제</button>
                        )}
                      </div>
                    </div>
                  )
                } else {
                  const act = item.data
                  const m = act.meta || {}
                  return (
                    <div key={`act-${act.id}`} className="activity-card">
                      <div className="activity-avatar">{act.user?.nickname?.[0]}</div>
                      <div className="activity-body">
                        {act.event_type === 'join' && (
                          <span><span className="activity-icon">👋</span><strong>{act.user?.nickname}</strong>님이 크루에 합류했어요!</span>
                        )}
                        {act.event_type === 'goal_added' && (
                          <span><span className="activity-icon">🎯</span><strong>{act.user?.nickname}</strong>님이 목표를 추가했어요 — <em>{m.goal_title}</em> (주 {m.frequency}회)</span>
                        )}
                        {act.event_type === 'goal_approved' && (
                          <span><span className="activity-icon">✅</span><strong>{act.user?.nickname}</strong>님의 목표 <em>{m.goal_title}</em>이(가) 팀원 동의를 받았어요!</span>
                        )}
                        {act.event_type === 'goal_completed' && (
                          <span><span className="activity-icon">🏆</span><strong>{act.user?.nickname}</strong>님이 이번 주 목표 <em>{m.goal_title}</em>을(를) 달성했어요! ({m.done}/{m.target}회)</span>
                        )}
                        <div className="activity-time">{kstShort(act.created_at)}</div>
                      </div>
                    </div>
                  )
                }
              })}
            </div>
          ) : (
            <div className="empty-state">
              <div className="empty-state-icon">📸</div>
              <p>아직 인증 기록이 없어요. 첫 운동을 인증해보세요!</p>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
