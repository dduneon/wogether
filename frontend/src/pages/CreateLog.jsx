import { useEffect, useState, useRef } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'

const WORKOUT_TYPES = ['헬스', '러닝', '수영', '자전거', '요가', '필라테스', '등산', '축구', '농구', '기타']

const CATEGORY_WORKOUT_MAP = {
  '런닝·조깅': '러닝', '헬스·웨이트': '헬스', '자전거': '자전거',
  '수영': '수영', '요가·필라테스': '요가', '홈트': '홈트',
  '구기종목': '구기종목', '등산·트레킹': '등산', '기타': '',
}

export default function CreateLog() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const fileInputRef = useRef(null)
  const cameraInputRef = useRef(null)
  const customTypeRef = useRef(null)

  const [allCrews, setAllCrews] = useState([])
  const [selectedCrewId, setSelectedCrewId] = useState(id)
  const [showCrewPicker, setShowCrewPicker] = useState(false)
  const [myGoals, setMyGoals] = useState([])
  const [goalId, setGoalId] = useState('')
  const [workoutType, setWorkoutType] = useState('')
  const [showCustomType, setShowCustomType] = useState(false)
  const [customType, setCustomType] = useState('')
  const [caption, setCaption] = useState('')
  const [files, setFiles] = useState([])
  const [previews, setPreviews] = useState([])
  const [currentPreview, setCurrentPreview] = useState(0)
  const [loading, setLoading] = useState(false)

  // 내 크루 전체 목록
  useEffect(() => {
    client.get('/crews').then(r => setAllCrews(r.data)).catch(() => {})
  }, [])

  // 선택된 크루의 목표 불러오기
  useEffect(() => {
    if (!selectedCrewId) return
    setGoalId('')
    client.get(`/crews/${selectedCrewId}/goals`).then(r => {
      const mine = r.data.filter(g => g.status === 'approved' && g.user_id === user?.id)
      setMyGoals(mine)
    }).catch(() => {})
  }, [selectedCrewId, user])

  const selectedCrew = allCrews.find(c => String(c.id) === String(selectedCrewId))

  const onGoalChange = (gid) => {
    setGoalId(gid)
    if (!gid || workoutType) return
    const goal = myGoals.find(g => String(g.id) === String(gid))
    if (goal) {
      const suggested = CATEGORY_WORKOUT_MAP[goal.category] || ''
      if (suggested) setWorkoutType(suggested)
    }
  }

  const handleFiles = (selected) => {
    if (!selected.length) return
    const arr = Array.from(selected)
    setFiles(arr)
    setPreviews(arr.map(f => URL.createObjectURL(f)))
    setCurrentPreview(0)
  }

  const finalWorkoutType = showCustomType ? customType.trim() : workoutType

  const submit = async (e) => {
    e.preventDefault()
    if (!files.length) {
      alert('사진을 최소 1장 선택해주세요.')
      return
    }
    setLoading(true)
    const fd = new FormData()
    files.forEach(f => fd.append('photo', f))
    if (goalId) fd.append('goal_id', goalId)
    if (finalWorkoutType) fd.append('workout_type', finalWorkoutType)
    if (caption.trim()) fd.append('caption', caption.trim())
    try {
      await client.post(`/crews/${selectedCrewId}/logs`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      navigate(`/crew/${selectedCrewId}`)
    } catch (err) {
      alert(err.response?.data?.error || '인증에 실패했어요.')
    } finally {
      setLoading(false)
    }
  }

  const selectedGoal = myGoals.find(g => String(g.id) === String(goalId))

  return (
    <div style={{ maxWidth: 520, margin: '0 auto', paddingBottom: 40 }}>

      {/* ── 헤더 ── */}
      <div style={{ padding: '20px 20px 12px' }}>
        <div className="page-eyebrow">운동 인증</div>
        <div className="heading" style={{ marginBottom: 0 }}>새 게시물 📸</div>
      </div>

      <form onSubmit={submit}>

        {/* ── 사진 영역 ── */}
        <div style={{ position: 'relative', background: 'var(--bg-2)', minHeight: 300, overflow: 'hidden' }}>
          {previews.length === 0 ? (
            <div
              style={{ minHeight: 300, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 12, cursor: 'pointer' }}
              onClick={() => fileInputRef.current?.click()}
            >
              <div style={{
                width: 72, height: 72, borderRadius: 20, background: 'var(--bg-3)',
                border: '1px solid var(--border-h)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '2rem',
              }}>🖼️</div>
              <div style={{ textAlign: 'center' }}>
                <div style={{ color: 'var(--text-muted)', fontWeight: 600, fontSize: '.95rem' }}>사진을 추가하세요</div>
                <div style={{ color: 'var(--text-dim)', fontSize: '.82rem', marginTop: 4 }}>갤러리 또는 카메라</div>
              </div>
            </div>
          ) : (
            <div style={{ position: 'relative', height: 300 }}>
              <img
                src={previews[currentPreview]}
                alt=""
                style={{ width: '100%', height: 300, objectFit: 'cover', display: 'block' }}
              />
              {previews.length > 1 && (
                <>
                  <div style={{
                    position: 'absolute', top: 12, right: 12,
                    background: 'rgba(0,0,0,.55)', borderRadius: 999,
                    padding: '3px 10px', fontSize: '.78rem', fontWeight: 600, color: '#fff',
                  }}>
                    {currentPreview + 1}/{previews.length}
                  </div>
                  <div style={{ position: 'absolute', bottom: 52, left: '50%', transform: 'translateX(-50%)', display: 'flex', gap: 5 }}>
                    {previews.map((_, i) => (
                      <button key={i} type="button" onClick={() => setCurrentPreview(i)}
                        style={{ width: 6, height: 6, borderRadius: '50%', border: 'none', padding: 0, cursor: 'pointer', background: i === currentPreview ? '#fff' : 'rgba(255,255,255,.4)' }}
                      />
                    ))}
                  </div>
                </>
              )}
            </div>
          )}

          {/* 카메라 / 갤러리 버튼 */}
          <div style={{ position: 'absolute', bottom: 12, right: 12, display: 'flex', gap: 8 }}>
            <button type="button" onClick={() => cameraInputRef.current?.click()}
              style={{ width: 40, height: 40, borderRadius: 12, background: 'rgba(0,0,0,.55)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.1rem' }}
              title="카메라"
            >📷</button>
            <button type="button" onClick={() => fileInputRef.current?.click()}
              style={{ width: 40, height: 40, borderRadius: 12, background: 'rgba(0,0,0,.55)', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '1.1rem' }}
              title="갤러리"
            >🖼️</button>
          </div>

          <input ref={fileInputRef} type="file" accept="image/*" multiple style={{ display: 'none' }}
            onChange={e => handleFiles(e.target.files)} />
          <input ref={cameraInputRef} type="file" accept="image/*" capture="environment" style={{ display: 'none' }}
            onChange={e => handleFiles(e.target.files)} />
        </div>

        {/* ── 폼 본문 ── */}
        <div style={{ padding: '20px 20px 0' }}>

          {/* 크루 선택 */}
          <div style={{ marginBottom: 24 }}>
            <div className="cl-section-label">인증할 크루</div>
            <button
              type="button"
              onClick={() => allCrews.length > 1 && setShowCrewPicker(true)}
              style={{
                marginTop: 10, width: '100%', display: 'flex', alignItems: 'center', gap: 12,
                padding: '12px 14px', borderRadius: 12, cursor: allCrews.length > 1 ? 'pointer' : 'default',
                background: 'var(--bg-2)', border: '1px solid var(--border-h)',
                transition: 'border-color .2s', textAlign: 'left',
              }}
              onMouseEnter={e => { if (allCrews.length > 1) e.currentTarget.style.borderColor = 'var(--purple)' }}
              onMouseLeave={e => e.currentTarget.style.borderColor = 'var(--border-h)'}
            >
              <div style={{
                width: 36, height: 36, borderRadius: 10, flexShrink: 0,
                background: 'rgba(168,85,247,.15)', border: '1px solid rgba(168,85,247,.3)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: '1rem', fontWeight: 700, color: 'var(--purple-l)',
              }}>
                {selectedCrew ? selectedCrew.name[0].toUpperCase() : '?'}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: '.95rem', color: 'var(--text)' }}>
                  {selectedCrew ? selectedCrew.name : '크루 선택 중…'}
                </div>
                {selectedCrew?.description && (
                  <div style={{ fontSize: '.75rem', color: 'var(--text-muted)', marginTop: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {selectedCrew.description}
                  </div>
                )}
              </div>
              {allCrews.length > 1 && (
                <span style={{ color: 'var(--text-dim)', fontSize: '.8rem', flexShrink: 0 }}>변경 ›</span>
              )}
            </button>
          </div>

          {/* 운동 종류 */}
          <div style={{ marginBottom: 24 }}>
            <div className="cl-section-label">운동 종류</div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 10 }}>
              {WORKOUT_TYPES.map(type => {
                const active = !showCustomType && workoutType === type
                return (
                  <button
                    key={type}
                    type="button"
                    onClick={() => { setWorkoutType(type); setShowCustomType(false) }}
                    style={{
                      padding: '8px 14px', borderRadius: 999, fontSize: '.85rem', cursor: 'pointer',
                      fontWeight: active ? 700 : 400, transition: 'all .15s',
                      background: active ? 'rgba(168,85,247,.2)' : 'var(--bg-3)',
                      border: `1.5px solid ${active ? 'var(--purple)' : 'var(--border-h)'}`,
                      color: active ? 'var(--purple-l)' : 'var(--text-muted)',
                    }}
                  >
                    {type}
                  </button>
                )
              })}
              {/* 직접 입력 */}
              <button
                type="button"
                onClick={() => { setShowCustomType(true); setWorkoutType(''); setTimeout(() => customTypeRef.current?.focus(), 50) }}
                style={{
                  padding: '8px 14px', borderRadius: 999, fontSize: '.85rem', cursor: 'pointer',
                  fontWeight: showCustomType ? 700 : 400, transition: 'all .15s',
                  background: showCustomType ? 'rgba(34,211,238,.15)' : 'var(--bg-3)',
                  border: `1.5px solid ${showCustomType ? 'var(--cyan)' : 'var(--border-h)'}`,
                  color: showCustomType ? 'var(--cyan)' : 'var(--text-muted)',
                }}
              >
                직접 입력
              </button>
            </div>
            {showCustomType && (
              <input
                ref={customTypeRef}
                type="text"
                placeholder="운동 종류를 입력하세요"
                value={customType}
                onChange={e => setCustomType(e.target.value)}
                style={{
                  marginTop: 10, width: '100%', padding: '10px 14px', borderRadius: 12, fontSize: '.9rem',
                  background: 'var(--bg-2)', border: '1px solid var(--border-h)', color: 'var(--text)',
                  fontFamily: 'inherit', outline: 'none', boxSizing: 'border-box',
                }}
              />
            )}
          </div>

          {/* 목표 연결 */}
          {myGoals.length > 0 && (
            <div style={{ marginBottom: 24 }}>
              <div className="cl-section-label">목표 연결</div>
              <select
                value={goalId}
                onChange={e => onGoalChange(e.target.value)}
                style={{
                  marginTop: 10, width: '100%', padding: '12px 14px', borderRadius: 12,
                  background: 'var(--bg-2)', border: '1px solid var(--border-h)',
                  color: goalId ? 'var(--text)' : 'var(--text-dim)',
                  fontFamily: 'inherit', fontSize: '.9rem', outline: 'none', cursor: 'pointer',
                }}
              >
                <option value="">연결 안 함</option>
                {myGoals.map(g => (
                  <option key={g.id} value={g.id}>
                    {g.title} — 주 {g.frequency_per_week}회
                  </option>
                ))}
              </select>

              {selectedGoal && (
                <div style={{ marginTop: 8, padding: '10px 14px', background: 'var(--bg-3)', borderRadius: 10, border: '1px solid var(--border)' }}>
                  <div style={{ fontSize: '.75rem', color: 'var(--text-muted)', marginBottom: 6 }}>이번 주 진행률</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div style={{ flex: 1, height: 6, background: 'rgba(255,255,255,.1)', borderRadius: 3, overflow: 'hidden' }}>
                      <div style={{ height: '100%', background: 'var(--cyan)', borderRadius: 3, width: `${selectedGoal.progress.percent}%`, transition: 'width .3s' }} />
                    </div>
                    <span style={{ fontSize: '.82rem', fontWeight: 700, color: 'var(--cyan)', whiteSpace: 'nowrap' }}>
                      {selectedGoal.progress.done} / {selectedGoal.progress.target}회
                    </span>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* 한마디 */}
          <div style={{ marginBottom: 24 }}>
            <div className="cl-section-label">한마디</div>
            <textarea
              placeholder="오늘 운동 어땠나요? (선택)"
              rows={4}
              value={caption}
              onChange={e => setCaption(e.target.value)}
              style={{
                marginTop: 10, width: '100%', padding: '12px 14px', borderRadius: 12, fontSize: '.9rem',
                background: 'var(--bg-2)', border: '1px solid var(--border-h)', color: 'var(--text)',
                fontFamily: 'inherit', outline: 'none', resize: 'none', boxSizing: 'border-box',
                transition: 'border-color .2s',
              }}
              onFocus={e => e.target.style.borderColor = 'var(--purple)'}
              onBlur={e => e.target.style.borderColor = 'var(--border-h)'}
            />
          </div>

          {/* 제출 버튼 */}
          <button
            type="submit"
            disabled={loading}
            className="btn btn-primary btn-full"
            style={{ fontSize: '1rem', padding: '14px', marginBottom: 8 }}
          >
            {loading ? (
              <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
                <span style={{ width: 16, height: 16, border: '2px solid rgba(255,255,255,.3)', borderTopColor: '#fff', borderRadius: '50%', display: 'inline-block', animation: 'spin .7s linear infinite' }} />
                업로드 중…
              </span>
            ) : '올리기 →'}
          </button>
          <button type="button" onClick={() => navigate(-1)} className="btn btn-ghost btn-full">
            ← 돌아가기
          </button>
        </div>
      </form>

      {/* ── 크루 선택 모달 ── */}
      {showCrewPicker && (
        <div className="modal-backdrop" onClick={() => setShowCrewPicker(false)}>
          <div className="crew-picker-sheet" onClick={e => e.stopPropagation()}>
            <div className="crew-picker-handle" />
            <div className="crew-picker-title">어느 크루에 인증할까요?</div>
            <div className="crew-picker-list">
              {allCrews.map(crew => (
                <button
                  key={crew.id}
                  type="button"
                  className="crew-picker-item"
                  onClick={() => {
                    setSelectedCrewId(String(crew.id))
                    setShowCrewPicker(false)
                  }}
                  style={{ background: String(crew.id) === String(selectedCrewId) ? 'var(--bg-3)' : 'transparent' }}
                >
                  <div className="crew-picker-icon">{crew.name[0].toUpperCase()}</div>
                  <div style={{ flex: 1, minWidth: 0, textAlign: 'left' }}>
                    <div style={{ fontWeight: 700, fontSize: '.95rem', color: 'var(--text)' }}>{crew.name}</div>
                    <div style={{ fontSize: '.75rem', color: 'var(--text-muted)', marginTop: 2 }}>
                      멤버 {crew.member_count}명
                    </div>
                  </div>
                  {String(crew.id) === String(selectedCrewId)
                    ? <span style={{ color: 'var(--purple-l)', fontSize: '1rem' }}>✓</span>
                    : <span style={{ color: 'var(--text-dim)', fontSize: '1rem' }}>›</span>
                  }
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
