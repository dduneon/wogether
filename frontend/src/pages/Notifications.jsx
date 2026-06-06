import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import client from '../api/client'
import { kstFull } from '../utils/time'

const NOTI_ICON = { nudge: '👉', goal_request: '🤝', goal_approved: '✅', join: '🎉' }

export default function Notifications() {
  const [items, setItems] = useState(null)
  const [deleting, setDeleting] = useState(new Set())

  useEffect(() => {
    client.get('/notifications').then(r => {
      setItems(r.data)
      client.post('/notifications/read').catch(() => {})
    }).catch(() => setItems([]))
  }, [])

  async function handleDelete(id, e) {
    if (e) e.stopPropagation()
    setDeleting(prev => new Set(prev).add(id))
    try {
      await client.delete(`/notifications/${id}`)
      setItems(prev => prev.filter(n => n.id !== id))
    } catch {
      setDeleting(prev => { const s = new Set(prev); s.delete(id); return s })
    }
  }

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
            <div
              key={n.id}
              className={`noti-item${n.is_read ? '' : ' unread'}${deleting.has(n.id) ? ' noti-deleting' : ''}`}
              onClick={() => handleDelete(n.id)}
              style={{ cursor: 'pointer' }}
            >
              <span className="noti-icon">{NOTI_ICON[n.type] || '🔔'}</span>
              <div className="noti-body">
                <p className="noti-msg">{n.message}</p>
                <div className="noti-meta">
                  {kstFull(n.created_at)}
                  {n.crew_id && (
                    <>
                      &nbsp;·&nbsp;
                      <Link
                        to={`/crew/${n.crew_id}`}
                        style={{ color: 'var(--purple-l)' }}
                        onClick={e => e.stopPropagation()}
                      >크루 보기 →</Link>
                    </>
                  )}
                </div>
              </div>
              <button
                className="noti-delete-btn"
                onClick={(e) => handleDelete(n.id, e)}
                title="삭제"
              >×</button>
            </div>
          ))}
        </div>
      )}

      <style>{`
        .noti-item {
          position: relative;
          display: flex;
          align-items: flex-start;
          gap: 12px;
          transition: opacity 0.2s, transform 0.2s;
        }
        .noti-item:hover { background: rgba(255,255,255,0.04); }
        .noti-deleting { opacity: 0; transform: translateX(20px); }
        .noti-body { flex: 1; min-width: 0; }
        .noti-delete-btn {
          flex-shrink: 0;
          margin-left: auto;
          background: none;
          border: none;
          color: var(--text-muted, #888);
          font-size: 20px;
          line-height: 1;
          cursor: pointer;
          padding: 2px 6px;
          border-radius: 6px;
          transition: background 0.15s, color 0.15s;
          align-self: center;
        }
        .noti-delete-btn:hover {
          background: rgba(255,80,80,0.12);
          color: #ff5050;
        }
      `}</style>
    </div>
  )
}
