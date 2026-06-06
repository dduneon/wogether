import { useEffect, useState, useCallback } from 'react'
import client from '../api/client'

const DAYS = ['월', '화', '수', '목', '금', '토', '일']

function getFirstDayOffset(year, month) {
  // JS Date: 0=일, 1=월 ... 6=토 → 월요일 시작 기준 offset
  const d = new Date(year, month - 1, 1).getDay()
  return (d + 6) % 7 // 월=0, 화=1 ... 일=6
}

function getDaysInMonth(year, month) {
  return new Date(year, month, 0).getDate()
}

export default function WorkoutCalendar() {
  const now = new Date()
  const [year, setYear] = useState(now.getFullYear())
  const [month, setMonth] = useState(now.getMonth() + 1)
  const [data, setData] = useState(null)
  const [selectedDate, setSelectedDate] = useState(null)

  const load = useCallback((y, m) => {
    setData(null)
    client.get(`/me/workout-calendar?year=${y}&month=${m}`)
      .then(r => setData(r.data))
      .catch(() => {})
  }, [])

  useEffect(() => { load(year, month) }, [year, month, load])

  const prevMonth = () => {
    if (month === 1) { setYear(y => y - 1); setMonth(12) }
    else setMonth(m => m - 1)
    setSelectedDate(null)
  }
  const nextMonth = () => {
    if (month === 12) { setYear(y => y + 1); setMonth(1) }
    else setMonth(m => m + 1)
    setSelectedDate(null)
  }

  const workoutSet = new Set(data?.workout_dates ?? [])
  const offset = getFirstDayOffset(year, month)
  const daysInMonth = getDaysInMonth(year, month)
  const totalCells = Math.ceil((offset + daysInMonth) / 7) * 7
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`

  const selectedLogs = selectedDate ? (data?.logs_by_date?.[selectedDate] ?? []) : []

  return (
    <div className="card fade-up-2" style={{ marginBottom: 24 }}>
      {/* 헤더 */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <span style={{ fontSize: '1rem', fontWeight: 700 }}>📅 운동 달력</span>
          {data?.streak > 0 && (
            <span style={{
              background: 'linear-gradient(135deg,rgba(168,85,247,.2),rgba(34,211,238,.15))',
              border: '1px solid rgba(168,85,247,.35)',
              borderRadius: 999,
              padding: '2px 10px',
              fontSize: '.72rem',
              fontWeight: 700,
              color: 'var(--purple-l)',
            }}>
              🔥 {data.streak}일 연속
            </span>
          )}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <button onClick={prevMonth} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', padding: '4px 8px', fontSize: '1rem' }}>‹</button>
          <span style={{ fontSize: '.85rem', fontWeight: 600, minWidth: 72, textAlign: 'center', color: 'var(--text)' }}>
            {year}.{String(month).padStart(2, '0')}
          </span>
          <button onClick={nextMonth} style={{ background: 'none', border: 'none', color: 'var(--text-muted)', cursor: 'pointer', padding: '4px 8px', fontSize: '1rem' }}>›</button>
        </div>
      </div>

      {/* 요일 헤더 */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', marginBottom: 2 }}>
        {DAYS.map(d => (
          <div key={d} style={{ textAlign: 'center', fontSize: '.62rem', fontWeight: 700, color: 'var(--text-dim)', padding: '3px 0', letterSpacing: '.04em' }}>{d}</div>
        ))}
      </div>

      {/* 날짜 그리드 */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7,1fr)', gap: 1 }}>
        {Array.from({ length: totalCells }).map((_, i) => {
          const dayNum = i - offset + 1
          if (dayNum < 1 || dayNum > daysInMonth) return <div key={i} />
          const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(dayNum).padStart(2, '0')}`
          const hasWorkout = workoutSet.has(dateStr)
          const isToday = dateStr === todayStr
          const isSelected = dateStr === selectedDate

          return (
            <button
              key={i}
              onClick={() => setSelectedDate(hasWorkout ? (isSelected ? null : dateStr) : null)}
              style={{
                position: 'relative',
                height: 32,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                borderRadius: 6,
                border: isSelected ? '1.5px solid var(--purple)' : isToday ? '1.5px solid rgba(168,85,247,.4)' : '1.5px solid transparent',
                background: hasWorkout
                  ? isSelected
                    ? 'linear-gradient(135deg,rgba(168,85,247,.35),rgba(34,211,238,.2))'
                    : 'rgba(168,85,247,.15)'
                  : isToday ? 'rgba(168,85,247,.06)' : 'transparent',
                cursor: hasWorkout ? 'pointer' : 'default',
                padding: 0,
                transition: 'all .15s',
                boxShadow: isSelected ? '0 0 10px rgba(168,85,247,.3)' : 'none',
              }}
            >
              <span style={{
                fontSize: '.72rem',
                fontWeight: hasWorkout ? 700 : 400,
                color: hasWorkout ? 'var(--purple-l)' : isToday ? 'var(--text)' : 'var(--text-muted)',
                lineHeight: 1,
              }}>
                {dayNum}
              </span>
              {hasWorkout && (
                <span style={{
                  display: 'block',
                  width: 4,
                  height: 4,
                  borderRadius: '50%',
                  background: 'var(--purple)',
                  marginTop: 3,
                  boxShadow: '0 0 4px var(--purple)',
                }} />
              )}
            </button>
          )
        })}
      </div>

      {/* 선택한 날 로그 */}
      {selectedDate && (
        <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 14 }}>
          <div style={{ fontSize: '.75rem', fontWeight: 700, color: 'var(--text-muted)', marginBottom: 10, textTransform: 'uppercase', letterSpacing: '.08em' }}>
            {selectedDate} · {selectedLogs.length}회 운동
          </div>
          {selectedLogs.map(log => (
            <div key={log.id} style={{
              display: 'flex',
              alignItems: 'flex-start',
              gap: 12,
              padding: '10px 0',
              borderBottom: '1px solid var(--border)',
            }}>
              {log.representative_image_url ? (
                <img
                  src={log.representative_image_url}
                  alt=""
                  style={{ width: 48, height: 48, borderRadius: 8, objectFit: 'cover', flexShrink: 0, border: '1px solid var(--border-h)' }}
                />
              ) : (
                <div style={{ width: 48, height: 48, borderRadius: 8, background: 'var(--bg-3)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.4rem', flexShrink: 0 }}>🏋️</div>
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: '.85rem', fontWeight: 600, color: 'var(--text)', marginBottom: 2 }}>
                  {log.crew_name || '크루'}
                </div>
                {log.caption && (
                  <div style={{ fontSize: '.78rem', color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {log.caption}
                  </div>
                )}
                <div style={{ fontSize: '.7rem', color: 'var(--text-dim)', marginTop: 3 }}>
                  {new Date(log.timestamp).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit', hour12: false })}
                  {log.like_count > 0 && ` · ❤️ ${log.like_count}`}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* 로딩 */}
      {!data && (
        <div style={{ textAlign: 'center', padding: '20px 0', color: 'var(--text-dim)', fontSize: '.8rem' }}>불러오는 중…</div>
      )}
    </div>
  )
}
