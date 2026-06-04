import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/AuthContext'
import client from '../api/client'

export default function Signup() {
  const [form, setForm] = useState({ username: '', nickname: '', password: '' })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const navigate = useNavigate()

  const submit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)
    try {
      const r = await client.post('/signup', form)
      login(r.data.token, r.data.user)
      navigate('/')
    } catch (err) {
      const msg = err.response?.data?.error
      setError(msg || '회원가입에 실패했어요. 잠시 후 다시 시도해주세요.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-wrap">
      <div className="auth-box fade-up">
        <div className="auth-logo">Wogether</div>
        <p className="auth-sub">크루를 만들고, 목표를 세우고, 함께 달성하세요</p>
        {error && (
          <div style={{ background: 'rgba(248,113,113,.1)', border: '1px solid rgba(248,113,113,.3)', borderRadius: 'var(--radius-sm)', padding: '10px 14px', marginBottom: 14, fontSize: '.875rem', color: 'var(--red)' }}>
            {error}
          </div>
        )}
        <div className="card card-neon-c">
          <form onSubmit={submit}>
            <div className="form-group">
              <label className="form-label">아이디</label>
              <input
                type="text"
                placeholder="아이디 (로그인에 사용)"
                required
                value={form.username}
                onChange={e => setForm({ ...form, username: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label className="form-label">닉네임</label>
              <input
                type="text"
                placeholder="크루에서 보일 이름 (한글 가능)"
                required
                value={form.nickname}
                onChange={e => setForm({ ...form, nickname: e.target.value })}
              />
            </div>
            <div className="form-group">
              <label className="form-label">비밀번호</label>
              <input
                type="password"
                placeholder="비밀번호"
                required
                value={form.password}
                onChange={e => setForm({ ...form, password: e.target.value })}
              />
            </div>
            <button type="submit" className="btn btn-cyan btn-full mt-8" disabled={loading}>
              {loading ? '가입 중…' : '시작하기 →'}
            </button>
          </form>
        </div>
        <div className="auth-switch">
          이미 계정이 있나요? <Link to="/login">로그인</Link>
        </div>
      </div>
    </div>
  )
}
