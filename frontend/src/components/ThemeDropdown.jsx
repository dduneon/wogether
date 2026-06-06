import { useState, useRef, useEffect } from 'react'
import { useTheme } from '../context/ThemeContext'

const MODES = [
  { id: 'dark',  label: '다크',   icon: '🌑' },
  { id: 'light', label: '라이트', icon: '☀️' },
]

export default function ThemeDropdown() {
  const { mode, changeMode } = useTheme()
  const [open, setOpen] = useState(false)
  const wrapRef = useRef(null)

  useEffect(() => {
    const handler = (e) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('click', handler)
    return () => document.removeEventListener('click', handler)
  }, [])

  return (
    <div className="theme-popup-wrap" ref={wrapRef}>
      <button
        className="noti-bell-btn"
        onClick={() => setOpen(o => !o)}
        title="테마 설정"
        aria-label="테마 설정"
      >
        ⚙️
      </button>

      {open && (
        <div className="theme-dropdown open">
          <div className="theme-drop-head">테마</div>
          <div className="theme-options">
            {MODES.map(m => (
              <button
                key={m.id}
                className="theme-opt"
                onClick={() => { changeMode(m.id); setOpen(false) }}
              >
                <span className="theme-opt-icon">{m.icon}</span>
                <span className="theme-opt-label">{m.label}</span>
                <span className={`theme-opt-check${mode === m.id ? ' visible' : ''}`}>✓</span>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  )
}
