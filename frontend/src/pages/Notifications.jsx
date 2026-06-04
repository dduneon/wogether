import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import client from '../api/client'
import { kstFull } from '../utils/time'

const NOTI_ICON = { nudge: '👉', goal_request: '🤝', goal_approved: '✅', join: '🎉' }

export default function Notifications() {
  const [items, setItems] = useState(null)

  useEffect(() => {
    client.get('/notifications').then(r => {
      setItems(r.data)
      client.post('/notifications/read').catch(() => {})
    }).catch(() => setItems([]))
  }, [])

  return (
    <div className="page-wrap">
      <div className="fade-up mb-24">
        <div className="page-eyebrow">Inbox</div>
        <div className="heading">알림 🔔</div>
      </div>

      {items === null ? (
        <div className="empty-state fade-up-1">
          <div className="empty-state-icon">🔔</div>
          <p>불러오는 중…</p>
        </div>
      ) : items.length === 0 ? (
        <div className="empty-state fade-up-1">
          <div className="empty-state-icon">🔔</div>
          <p>알림이 없어요</p>
        </div>
      ) : (
        <div className="noti-list fade-up-1">
          {items.map(n => (
            <div key={n.id} className={`noti-item${n.is_read ? '' : ' unread'}`}>
              <span className="noti-icon">{NOTI_ICON[n.type] || '🔔'}</span>
              <div className="noti-body">
                <p className="noti-msg">{n.message}</p>
                <div className="noti-meta">
                  {kstFull(n.created_at)}
                  {n.crew_id && (
                    <>
                      &nbsp;·&nbsp;
                      <Link to={`/crew/${n.crew_id}`} style={{ color: 'var(--purple-l)' }}>크루 보기 →</Link>
                    </>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
