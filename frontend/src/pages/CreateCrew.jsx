import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import client from '../api/client'

export default function CreateCrew() {
  const navigate = useNavigate()
  const [form, setForm] = useState({ name: '', description: '' })
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    try {
      const res = await client.post('/crews', form)
      navigate(`/crew/${res.data.id}`)
    } catch (err) {
      alert(err.response?.data?.error || '크루 생성에 실패했습니다.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="max-w-2xl mx-auto px-4 py-6">
      <h1 className="text-xl font-bold mb-6">크루 만들기</h1>
      <div className="bg-white rounded-2xl border border-gray-200 p-6">
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">크루 이름</label>
            <input type="text" value={form.name}
              onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="예: 새벽 러닝 크루" required />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">소개 (선택)</label>
            <textarea value={form.description}
              onChange={e => setForm(f => ({ ...f, description: e.target.value }))}
              rows={3}
              className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-400"
              placeholder="크루 소개를 입력하세요" />
          </div>
          <div className="flex gap-3">
            <button type="button" onClick={() => navigate(-1)}
              className="flex-1 border border-gray-300 rounded-lg py-2 text-sm font-medium hover:bg-gray-50">
              취소
            </button>
            <button type="submit" disabled={loading}
              className="flex-1 bg-indigo-600 text-white rounded-lg py-2 text-sm font-medium hover:bg-indigo-700 disabled:opacity-50">
              {loading ? '생성 중...' : '만들기'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
