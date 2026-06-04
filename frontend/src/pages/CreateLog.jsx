import { useEffect, useState, useRef } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'

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
  const [myGoals, setMyGoals] = useState([])
  const [form, setForm] = useState({ goal_id: '', workout_type: '', caption: '' })
  const [files, setFiles] = useState([])
  const [previews, setPreviews] = useState([])
  const [userEditedWT, setUserEditedWT] = useState(false)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    client.get(`/crews/${id}/goals`).then(r => {
      const mine = r.data.filter(g => g.status === 'approved' && g.user_id === user?.id)
      setMyGoals(mine)
    }).catch(() => {})
  }, [id])

  const onGoalChange = (goalId) => {
    setForm(prev => ({ ...prev, goal_id: goalId }))
    if (!goalId || userEditedWT) return
    const goal = myGoals.find(g => String(g.id) === String(goalId))
    if (goal) {
      const suggested = CATEGORY_WORKOUT_MAP[goal.category] || goal.category || ''
      setForm(prev => ({ ...prev, goal_id: goalId, workout_type: suggested }))
    }
  }

  const selectedGoal = myGoals.find(g => String(g.id) === String(form.goal_id))

  const handlePhotos = (e) => {
    const selected = Array.from(e.target.files)
    setFiles(selected)
    setPreviews(selected.slice(0, 3).map(f => URL.createObjectURL(f)))
  }

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    const fd = new FormData()
    files.forEach(f => fd.append('photo', f))
    if (form.goal_id) fd.append('goal_id', form.goal_id)
    if (form.workout_type) fd.append('workout_type', form.workout_type)
    if (form.caption) fd.append('caption', form.caption)
    try {
      await client.post(`/crews/${id}/logs`, fd, { headers: { 'Content-Type': 'multipart/form-data' } })
      navigate(`/crew/${id}`)
    } catch (err) {
      alert(err.response?.data?.error || '인증에 실패했어요.')
    } finally {
      setLoading(false)
    }
  }

  const previewClass = previews.length === 1 ? 'cols-1' : previews.length === 2 ? 'cols-2' : 'cols-3'

  return (
    <div className="composer-wrap">
      <div className="composer-box fade-up">
        <div className="page-eyebrow">운동 인증</div>
        <div className="heading" style={{ marginBottom: 20 }}>새 게시물 📸</div>

        <form onSubmit={submit} id="composer-form">
          {/* 사진 업로드 */}
          <div
            className={`composer-photo-area${previews.length > 0 ? ' has-preview' : ''}`}
            onClick={() => fileInputRef.current?.click()}
          >
            {previews.length === 0 ? (
              <>
                <div className="composer-photo-icon">🖼</div>
                <div className="composer-photo-hint">
                  여기를 눌러 사진 추가<br />
                  <span>JPG, PNG, WebP — 최대 여러 장</span>
                </div>
              </>
            ) : (
              <div className={`composer-preview-grid ${previewClass}`}>
                {previews.map((src, i) => <img key={i} src={src} alt="" />)}
              </div>
            )}
            <input
              type="file"
              ref={fileInputRef}
              accept="image/*"
              multiple
              style={{ display: 'none' }}
              onChange={handlePhotos}
            />
          </div>

          {/* 연결 목표 */}
          {myGoals.length > 0 && (
            <div style={{ marginTop: 16 }}>
              <label className="form-label" style={{ fontSize: '.82rem', opacity: .7, marginBottom: 6, display: 'block' }}>
                연결할 목표
              </label>
              <select
                value={form.goal_id}
                onChange={e => onGoalChange(e.target.value)}
                style={{ width: '100%', padding: '10px 14px', background: 'var(--bg-3)', border: '1px solid var(--border)', borderRadius: 'var(--radius-sm)', color: 'var(--text)', fontFamily: 'inherit', fontSize: '.9rem', outline: 'none' }}
              >
                <option value="">🎯 목표 연결 안 함</option>
                {myGoals.map(g => (
                  <option key={g.id} value={g.id}>
                    {g.category} · {g.title} — 주 {g.frequency_per_week}회
                  </option>
                ))}
              </select>

              {/* 선택된 목표 정보 카드 */}
              {selectedGoal && (
                <div style={{ display: 'none', marginTop: 10, padding: '12px 14px', background: 'var(--bg-3)', border: '1px solid var(--border)', borderRadius: 'var(--radius-sm)', ...(form.goal_id ? { display: 'block' } : {}) }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                    <span style={{ fontSize: '.78rem', padding: '3px 9px', borderRadius: 20, background: 'rgba(0,229,255,.12)', color: '#00e5ff', border: '1px solid rgba(0,229,255,.25)' }}>
                      {selectedGoal.category}
                    </span>
                    <span style={{ fontSize: '.88rem', fontWeight: 600 }}>{selectedGoal.title}</span>
                  </div>
                  <div style={{ fontSize: '.78rem', opacity: .6, marginBottom: 6 }}>이번 주 진행률</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div style={{ flex: 1, height: 6, background: 'rgba(255,255,255,.1)', borderRadius: 3, overflow: 'hidden' }}>
                      <div style={{ height: '100%', background: '#00e5ff', borderRadius: 3, width: `${selectedGoal.progress.percent}%`, transition: 'width .3s' }} />
                    </div>
                    <span style={{ fontSize: '.82rem', fontWeight: 700, color: '#00e5ff', whiteSpace: 'nowrap' }}>
                      {selectedGoal.progress.done} / {selectedGoal.progress.target}회
                    </span>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* 캡션 + 운동 종류 */}
          <div style={{ marginTop: 14, background: 'var(--bg-2)', border: '1px solid var(--border)', borderRadius: 'var(--radius)', padding: 16 }}>
            <textarea
              className="composer-caption"
              placeholder="오늘 운동 어땠나요? 크루에 자랑해보세요 💪"
              rows={3}
              value={form.caption}
              onChange={e => setForm({ ...form, caption: e.target.value })}
            />
            <div className="composer-meta-row" style={{ marginTop: 12 }}>
              <input
                type="text"
                placeholder="# 운동 종류  (예: 러닝, 헬스, 요가)"
                value={form.workout_type}
                onChange={e => { setUserEditedWT(true); setForm({ ...form, workout_type: e.target.value }) }}
              />
            </div>
          </div>

          <button type="submit" className="btn btn-primary btn-full mt-16" style={{ fontSize: '1rem', padding: 14 }} disabled={loading}>
            {loading ? '공유 중…' : '공유하기 🔥'}
          </button>
        </form>

        <Link to={`/crew/${id}`} className="btn btn-ghost btn-full mt-8">← 돌아가기</Link>
      </div>
    </div>
  )
}
