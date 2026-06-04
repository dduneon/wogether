import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'

export default function Login() {
  const [form, setForm] = useState({ username: '', password: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const navigate = useNavigate()

  const submit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const r = await client.post('/login', form)
      login(r.data.token, r.data.user)
      navigate('/')
    } catch (err) {
      const msg = err.response?.data?.error
      setError(msg || '로그인에 실패했어요. 잠시 후 다시 시도해주세요.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-wrap">
      <div className="auth-box fade-up">
        <div className="auth-logo">Wogether</div>
        <p className="auth-sub">크루와 함께 운동 목표를 달성하세요 💪</p>
        {error && (
          <div style={{ background: 'rgba(248,113,113,.1)', border: '1px solid rgba(248,113,113,.3)', borderRadius: 'var(--radius-sm)', padding: '10px 14px', marginBottom: 14, fontSize: '.875rem', color: 'var(--red)' }}>
            {error}
          </div>
        )}
        <div className="card card-neon-p">
          <form onSubmit={submit}>
            <div className="form-group">
              <label className="form-label">아이디</label>
              <input
                type="text"
                placeholder="아이디를 입력하세요"
                required
                value={form.username}
                onChange={e => setForm({ ...form, username: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label className="form-label">비밀번호</label>
              <input
                type="password"
                placeholder="비밀번호를 입력하세요"
                required
                value={form.password}
                onChange={e => setForm({ ...form, password: e.target.value })}
              />
            </div>
            <button type="submit" className="btn btn-primary btn-full mt-8" disabled={loading}>
              {loading ? '로그인 중…' : '로그인'}
            </button>
          </form>
        </div>
        <div className="auth-switch">
          계정이 없으신가요? <Link to="/signup">회원가입</Link>
        </div>
      </div>
    </div>
  )
}
