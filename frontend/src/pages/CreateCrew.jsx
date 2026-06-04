import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import client from '../api/client'

export default function CreateCrew() {
  const [form, setForm] = useState({ name: '', description: '' })
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  const submit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      const r = await client.post('/crews', form)
      navigate(`/crew/${r.data.id}`)
    } catch (err) {
      alert(err.response?.data?.error || '크루 생성에 실패했어요.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-wrap">
      <div className="auth-box fade-up" style={{ maxWidth: 480 }}>
        <div className="page-eyebrow">Create</div>
        <div className="heading" style={{ marginBottom: 24 }}>새 크루 만들기</div>
        <div className="card card-neon-p">
          <form onSubmit={submit}>
            <div className="form-group">
              <label className="form-label">크루 이름</label>
              <input
                type="text"
                placeholder="예: 새벽 러닝 크루"
                required
                value={form.name}
                onChange={e => setForm({ ...form, name: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label className="form-label">소개 (선택)</label>
              <textarea
                placeholder="크루를 소개해주세요"
                rows={3}
                value={form.description}
                onChange={e => setForm({ ...form, description: e.target.value })}
              />
            </div>
            <button type="submit" className="btn btn-primary btn-full mt-8" disabled={loading}>
              {loading ? '생성 중…' : '크루 생성 →'}
            </button>
          </form>
        </div>
        <Link to="/" className="btn btn-ghost btn-full mt-8">← 돌아가기</Link>
      </div>
    </div>
  )
}
