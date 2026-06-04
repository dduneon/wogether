import axios from 'axios'

const client = axios.create({ baseURL: '/api' })

client.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

client.interceptors.response.use(
  (res) => res,
  (err) => {
    // 로그인/회원가입 요청은 인터셉터에서 처리하지 않음 (각 페이지에서 직접 핸들링)
    const url = err.config?.url || ''
    const isAuthEndpoint = url.includes('/login') || url.includes('/signup')
    if (err.response?.status === 401 && !isAuthEndpoint) {
      localStorage.removeItem('token')
      localStorage.removeItem('user')
      window.location.href = '/login'
    }
    return Promise.reject(err)
  }
)

export default client
