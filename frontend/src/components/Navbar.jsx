import { useState, useEffect, useRef } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'
import { kstShort } from '../utils/time'
import ThemeDropdown from './ThemeDropdown'

const NOTI_ICON = { nudge: '👉', goal_request: '🤝', goal_approved: '✅', join: '🎉' }

export default function Navbar() {
  const { logout } = useAuth()
  const navigate = useNavigate()
  const [unread, setUnread] = useState(0)
  const [open, setOpen] = useState(false)
  const [items, setItems] = useState(null)
  const wrapRef = useRef(null)

  const fetchUnread = async () => {
    try {
      const r = await client.get('/notifications/unread-count')
      setUnread(r.data.count)
    } catch {}
  }

  const loadPopup = async () => {
    try {
      const r = await client.get('/notifications')
      setItems(r.data.slice(0, 5))
      setUnread(0)
    } catch {
      setItems([])
    }
  }

  const deleteNoti = async (id, e) => {
    e.stopPropagation()
    try {
      await client.delete(`/notifications/${id}`)
      setItems(prev => prev.filter(n => n.id !== id))
    } catch {}
  }

  useEffect(() => {
    fetchUnread()
    const id = setInterval(fetchUnread, 30000)
    return () => clearInterval(id)
  }, [])

  useEffect(() => {
    const handler = (e) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('click', handler)
    return () => document.removeEventListener('click', handler)
  }, [])

  const toggle = () => {
    const next = !open
    setOpen(next)
    if (next) loadPopup()
  }

  return (
    <header className="top-nav">
      <div className="nav-content">
        <Link to="/" className="nav-logo">Wogether</Link>
        <nav className="nav-links">
          <div className="noti-popup-wrap" ref={wrapRef}>
            <button className="noti-bell-btn" onClick={toggle}>
              🔔 알림
              {unread > 0 && (
                <span className="noti-badge">{unread > 99 ? '99+' : unread}</span>
              )}
            </button>
            {open && (
              <div className="noti-dropdown">
                <div className="noti-drop-head">
                  <span>알림</span>
                  <Link to="/notifications" onClick={() => setOpen(false)}>전체 보기</Link>
                </div>
                {items === null ? (
                  <div className="noti-drop-empty">불러오는 중…</div>
                ) : items.length === 0 ? (
                  <div className="noti-drop-empty">알림이 없어요 😴</div>
                ) : items.map(n => (
                  <div key={n.id} className={`noti-drop-item${n.is_read ? '' : ' unread'}`}>
                    <span className="noti-drop-icon">{NOTI_ICON[n.type] || '🔔'}</span>
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div className="noti-drop-msg">{n.message}</div>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <span className="noti-drop-time">{kstShort(n.created_at)}</span>
                        {n.crew_id && (
                          <Link to={`/crew/${n.crew_id}`} className="noti-drop-link" onClick={() => setOpen(false)}>
                            크루 보기 →
                          </Link>
                        )}
                      </div>
                    </div>
                    <button
                      className="noti-drop-del"
                      onClick={(e) => deleteNoti(n.id, e)}
                      title="삭제"
                    >×</button>
                  </div>
                ))}
              </div>
            )}
          </div>

          <Link to="/crew/create">+ 크루</Link>
          <button onClick={() => { logout(); navigate('/login') }}>로그아웃</button>
          <ThemeDropdown />
        </nav>
      </div>
    </header>
  )
}
