import { useEffect, useState, useRef } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import client from '../api/client'
import { useAuth } from '../context/AuthContext'

const WORKOUT_TYPES = ['러닝', '헬스', '수영', '자전거', '요가', '필라테스', '구기종목', '기타']

export default function CreateLog() {
  const { id: crewId } = useParams()
  const { user } = useAuth()
  const navigate = useNavigate()
  const fileRef = useRef()
  const [goals, setGoals] = useState([])
  const [form, setForm] = useState({ caption: '', workout_type: '', goal_id: '' })
  const [photos, setPhotos] = useState([])
  const [previews, setPreviews] = useState([])
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    client.get(`/crews/${crewId}/goals`)
      .then(r => setGoals(r.data.filter(g => g.status === 'approved' && g.user_id === user.id)))
  }, [crewId])

  const handlePhotos = (e) => {
    const files = Array.from(e.target.files)
    setPhotos(files)
    setPreviews(files.map(f => URL.createObjectURL(f)))
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (photos.length === 0) { alert('사진을 최소 한 장 선택해주세요.'); return }
    setLoading(true)
    try {
      const fd = new FormData()
      fd.append('caption', form.caption)
      fd.append('workout_type', form.workout_type)
      if (form.goal_id) fd.append('goal_id', form.goal_id)
      photos.forEach(f => fd.append('photo', f))
      await client.post(`/crews/${crewId}/logs`, fd, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })
      navigate(`/crew/${crewId}`)
    } catch (err) {
      alert(err.response?.data?.error || '인증 등록에 실패했습니다.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      <h1 className="text-xl font-bold mb-6">운동 인증</h1>
      <div className="bg-white rounded-2xl border border-gray-200 p-6">
        <form onSubmit={handleSubmit} className="space-y-4">
          {/* 사진 선택 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">인증 사진</label>
            <div onClick={() => fileRef.current.click()}
              className="border-2 border-dashed border-gray-300 rounded-xl p-6 text-center cursor-pointer hover:border-indigo-400 transition-colors">
              {previews.length > 0 ? (
                <div className="flex gap-2 flex-wrap justify-center">
                  {previews.map((src, i) => (
                    <img key={i} src={src} alt="" className="h-20 w-20 object-cover rounded-lg" />
                  ))}
                </div>
              ) : (
                <div className="text-gray-400">
                  <p className="text-2xl mb-1">📸</p>
                  <p className="text-sm">사진을 선택하세요</p>
                </div>
              )}
            </div>
            <input ref={fileRef} type="file" accept="image/*" multiple
              onChange={handlePhotos} className="hidden" />
          </div>

          {/* 운동 종류 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">운동 종류</label>
            <div className="flex flex-wrap gap-2">
              {WORKOUT_TYPES.map(t => (
                <button key={t} type="button"
                  onClick={() => setForm(f => ({ ...f, workout_type: t }))}
                  className={`text-sm px-3 py-1.5 rounded-full border transition-colors ${
                    form.workout_type === t
                      ? 'bg-indigo-600 text-white border-indigo-600'
                      : 'border-gray-300 text-gray-600 hover:border-indigo-400'
                  }`}>
                  {t}
                </button>
              ))}
            </div>
          </div>

          {/* 연결 목표 */}
          {goals.length > 0 && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">연결 목표 (선택)</label>
              <select value={form.goal_id}
                onChange={e => setForm(f => ({ ...f, goal_id: e.target.value }))}
                className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400">
                <option value="">선택 안 함</option>
                {goals.map(g => (
                  <option key={g.id} value={g.id}>{g.title}</option>
                ))}
              </select>
            </div>
          )}

          {/* 한마디 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">한마디 (선택)</label>
            <textarea value={form.caption}
              onChange={e => setForm(f => ({ ...f, caption: e.target.value }))}
              rows={2}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="오늘 운동 어땠나요?" />
          </div>

          <div className="flex gap-3">
            <button type="button" onClick={() => navigate(-1)}
              className="flex-1 border border-gray-300 rounded-lg py-2 text-sm font-medium hover:bg-gray-50">
              취소
            </button>
            <button type="submit" disabled={loading}
              className="flex-1 bg-indigo-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-indigo-700 disabled:opacity-50">
              {loading ? '업로드 중...' : '인증 완료 🔥'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
