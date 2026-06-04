import { Link } from 'react-router-dom'

export default function Landing() {
  return (
    <div className="landing-wrap">
      <section className="landing-hero fade-up">
        <div className="display gradient-text">Wogether</div>
        <p className="landing-tagline">
          친구들과 크루를 맺고, 목표를 세우고, 운동을 인증하고,<br />
          서로 독촉하며 <strong style={{ color: 'var(--text)' }}>함께</strong> 달성하는 운동 챌린지
        </p>
        <div className="landing-cta">
          <Link to="/signup" className="btn btn-primary btn-lg">지금 시작하기 →</Link>
          <Link to="/login" className="btn btn-ghost btn-lg">로그인</Link>
        </div>
      </section>

      <div className="feature-grid">
        <div className="feature-card c-purple b-5 fade-up-1">
          <span className="feature-icon">👥</span>
          <div className="feature-title">크루 만들기</div>
          <div className="feature-desc">초대코드 하나로 친구들을 불러모아 크루를 결성하세요. 최고의 팀으로 거듭납니다.</div>
        </div>
        <div className="feature-card c-cyan b-4 fade-up-2">
          <span className="feature-icon">🎯</span>
          <div className="feature-title">목표 설정</div>
          <div className="feature-desc">주 N회 운동 목표를 세우고 팀원의 동의를 받으면 확정됩니다.</div>
        </div>
        <div className="feature-card c-green b-3 fade-up-3">
          <span className="feature-icon">📊</span>
          <div className="feature-title">달성률</div>
          <div className="feature-desc">이번 주 팀원 모두의 진행률을 한눈에</div>
        </div>
        <div className="feature-card c-pink b-3 fade-up-1">
          <span className="feature-icon">📸</span>
          <div className="feature-title">인증</div>
          <div className="feature-desc">러닝·헬스·수영 등 모든 운동을 사진으로 인증</div>
        </div>
        <div className="feature-card c-yellow b-5 fade-up-2">
          <span className="feature-icon">👉</span>
          <div className="feature-title">독촉 알림</div>
          <div className="feature-desc">안 한 팀원에게 "콕! 찌르기"로 알림을 보내세요. 긴장감이 동기부여가 됩니다.</div>
        </div>
        <div className="feature-card c-cyan b-4 fade-up-3">
          <span className="feature-icon">🤝</span>
          <div className="feature-title">팀 동의</div>
          <div className="feature-desc">목표는 팀원 전체의 동의를 받아야 확정. 책임감이 달라집니다.</div>
        </div>
      </div>
    </div>
  )
}
