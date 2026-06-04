import { useEffect, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import client from '../api/client'

export default function JoinCrew() {
  const { code } = useParams()
  const navigate = useNavigate()
  const [crew, setCrew] = useState(null)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    // 초대코드로 크루 정보 미리보기 — /api/crews/join POST로 실제 참여, 여기선 직접 보여주기
    // 초대링크 진입 시 바로 참여 확인 화면만 보여줌
    setCrew({ name: '크루', invite_code: code })
  }, [code])

  const join = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      const r = await client.post('/crews/join', { invite_code: code })
      navigate(`/crew/${r.data.id}`)
    } catch (err) {
      const msg = err.response?.data?.error
      if (msg === 'already a member') {
        navigate('/')
      } else {
        setError(msg || '참여에 실패했어요.')
      }
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="auth-wrap">
      <div className="auth-box fade-up" style={{ maxWidth: 420, textAlign: 'center' }}>
        <div className="page-eyebrow">초대링크</div>
        <div className="heading" style={{ marginBottom: 8 }}>크루 참여 🎉</div>
        <p className="auth-sub" style={{ marginBottom: 24 }}>초대코드로 크루에 합류해요</p>

        {error && (
          <div style={{ background: 'rgba(248,113,113,.1)', border: '1px solid rgba(248,113,113,.3)', borderRadius: 'var(--radius-sm)', padding: '10px 14px', marginBottom: 14, fontSize: '.875rem', color: 'var(--red)' }}>
            {error}
          </div>
        )}

        <div className="card card-neon-p" style={{ textAlign: 'left', marginBottom: 16 }}>
          <div style={{ fontSize: '.85rem', color: 'var(--text-muted)', marginBottom: 8 }}>초대코드</div>
          <div style={{ fontFamily: "'Space Mono', monospace", fontSize: '1.1rem', fontWeight: 700, color: 'var(--cyan)' }}>
            {code}
          </div>
        </div>

        <form onSubmit={join}>
          <button type="submit" className="btn btn-primary btn-full btn-lg" disabled={loading}>
            {loading ? '참여 중…' : '합류하기 →'}
          </button>
        </form>
        <Link to="/" className="btn btn-ghost btn-full mt-8">취소</Link>
      </div>
    </div>
  )
}
