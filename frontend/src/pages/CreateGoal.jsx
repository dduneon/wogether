import { useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import client from '../api/client'

const CATEGORIES = ['러닝', '헬스', '수영', '자전거', '요가', '필라테스', '구기종목', '기타']

export default function CreateGoal() {
  const { id: crewId } = useParams()
  const navigate = useNavigate()
  const [form, setForm] = useState({
    title: '', category: '기타', description: '', frequency_per_week: 3
  })
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      await client.post(`/crews/${crewId}/goals`, form)
      navigate(`/crew/${crewId}`)
    } catch (err) {
      alert(err.response?.data?.error || '목표 등록에 실패했습니다.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      <h1 className="text-xl font-bold mb-6">목표 추가</h1>
      <div className="bg-white rounded-2xl border border-gray-200 p-6">
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">목표 이름</label>
            <input type="text" value={form.title}
              onChange={e => setForm(f => ({ ...f, title: e.target.value }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="예: 주 3회 러닝" required />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">카테고리</label>
            <div className="flex flex-wrap gap-2">
              {CATEGORIES.map(cat => (
                <button key={cat} type="button"
                  onClick={() => setForm(f => ({ ...f, category: cat }))}
                  className={`text-sm px-3 py-1.5 rounded-full border transition-colors ${
                    form.category === cat
                      ? 'bg-indigo-600 text-white border-indigo-600'
                      : 'border-gray-300 text-gray-600 hover:border-indigo-400'
                  }`}>
                  {cat}
                </button>
              ))}
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              주당 목표 횟수: <span className="text-indigo-600 font-bold">{form.frequency_per_week}회</span>
            </label>
            <input type="range" min={1} max={7} value={form.frequency_per_week}
              onChange={e => setForm(f => ({ ...f, frequency_per_week: +e.target.value }))}
              className="w-full accent-indigo-600" />
            <div className="flex justify-between text-xs text-gray-400 mt-1">
              <span>1회</span><span>7회</span>
            </div>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">설명 (선택)</label>
            <textarea value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
              rows={2}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="목표에 대한 설명" />
          </div>
          <div className="flex gap-3">
            <button type="button" onClick={() => navigate(-1)}
              className="flex-1 border border-gray-300 rounded-lg py-2 text-sm font-medium hover:bg-gray-50">
              취소
            </button>
            <button type="submit" disabled={loading}
              className="flex-1 bg-indigo-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-indigo-700 disabled:opacity-50">
              {loading ? '등록 중...' : '목표 등록'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
