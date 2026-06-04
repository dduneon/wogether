import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import client from '../api/client'

const CATEGORIES = [
  ['런닝·조깅', '🏃'], ['헬스·웨이트', '🏋️'], ['자전거', '🚴'],
  ['수영', '🏊'], ['요가·필라테스', '🧘'], ['홈트', '🤸'],
  ['구기종목', '⚽'], ['등산·트레킹', '🥾'], ['기타', '💪'],
]

export default function CreateGoal() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [form, setForm] = useState({ category: '런닝·조깅', title: '', description: '', frequency_per_week: 3 })
  const [loading, setLoading] = useState(false)

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      await client.post(`/crews/${id}/goals`, form)
      navigate(`/crew/${id}`)
    } catch (err) {
      alert(err.response?.data?.error || '목표 등록에 실패했어요.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-wrap">
      <div className="auth-box fade-up" style={{ maxWidth: 520 }}>
        <div className="page-eyebrow">목표 설정</div>
        <div className="heading" style={{ marginBottom: 8 }}>목표 설정 🎯</div>
        <p className="auth-sub">팀원 모두의 동의를 받으면 목표가 확정됩니다</p>
        <div className="card card-neon-c">
          <form onSubmit={submit}>
            {/* 카테고리 */}
            <div className="form-group">
              <label className="form-label">운동 카테고리</label>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                {CATEGORIES.map(([name, icon]) => (
                  <label key={name} style={{ cursor: 'pointer' }}>
                    <input
                      type="radio"
                      name="category"
                      value={name}
                      checked={form.category === name}
                      onChange={() => setForm({ ...form, category: name })}
                      style={{ display: 'none' }}
                    />
                    <span style={{
                      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
                      padding: '10px 6px', borderRadius: 12,
                      border: `1.5px solid ${form.category === name ? 'var(--cyan)' : 'rgba(255,255,255,.12)'}`,
                      background: form.category === name ? 'rgba(0,229,255,.1)' : 'rgba(255,255,255,.04)',
                      color: form.category === name ? 'var(--cyan)' : 'inherit',
                      fontSize: '.78rem', textAlign: 'center', lineHeight: 1.3,
                      transition: 'border-color .15s, background .15s',
                    }}>
                      {icon}<br />{name}
                    </span>
                  </label>
                ))}
              </div>
            </div>

            {/* 목표 이름 */}
            <div className="form-group">
              <label className="form-label">목표 이름</label>
              <input
                type="text"
                placeholder="예: 5km 이상 달리기"
                required
                value={form.title}
                onChange={e => setForm({ ...form, title: e.target.value })}
              />
            </div>

            {/* 상세 조건 */}
            <div className="form-group">
              <label className="form-label">상세 조건 <span style={{ opacity: .5, fontSize: '.85em' }}>선택</span></label>
              <textarea
                rows={2}
                placeholder="예: 페이스 6분 이내, 야외 러닝만 인정"
                style={{ resize: 'vertical' }}
                value={form.description}
                onChange={e => setForm({ ...form, description: e.target.value })}
              />
            </div>

            {/* 주당 횟수 */}
            <div className="form-group">
              <label className="form-label">주당 횟수</label>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                {[1, 2, 3, 4, 5, 6, 7].map(n => (
                  <label key={n} style={{ cursor: 'pointer' }}>
                    <input
                      type="radio"
                      name="frequency_per_week"
                      value={n}
                      checked={form.frequency_per_week === n}
                      onChange={() => setForm({ ...form, frequency_per_week: n })}
                      style={{ display: 'none' }}
                    />
                    <span style={{
                      display: 'inline-block', padding: '7px 14px', borderRadius: 20,
                      border: `1.5px solid ${form.frequency_per_week === n ? 'var(--cyan)' : 'rgba(255,255,255,.15)'}`,
                      background: form.frequency_per_week === n ? 'rgba(0,229,255,.1)' : 'rgba(255,255,255,.04)',
                      color: form.frequency_per_week === n ? 'var(--cyan)' : 'inherit',
                      fontSize: '.88rem', transition: 'border-color .15s, background .15s',
                    }}>
                      {n}회
                    </span>
                  </label>
                ))}
              </div>
            </div>

            <button type="submit" className="btn btn-cyan btn-full mt-8" disabled={loading}>
              {loading ? '등록 중…' : '목표 등록 →'}
            </button>
          </form>
        </div>
        <Link to={`/crew/${id}`} className="btn btn-ghost btn-full mt-8">← 크루로 돌아가기</Link>
      </div>
    </div>
  )
}
