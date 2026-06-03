import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import Navbar from './components/Navbar'
import PrivateRoute from './components/PrivateRoute'
import Login from './pages/Login'
import Signup from './pages/Signup'
import Home from './pages/Home'
import CrewDetail from './pages/CrewDetail'
import CreateCrew from './pages/CreateCrew'
import CreateGoal from './pages/CreateGoal'
import CreateLog from './pages/CreateLog'
import Notifications from './pages/Notifications'

function AppRoutes() {
  const { user } = useAuth()
  return (
    <>
      {user && <Navbar />}
      <Routes>
        <Route path="/login" element={user ? <Navigate to="/" replace /> : <Login />} />
        <Route path="/signup" element={user ? <Navigate to="/" replace /> : <Signup />} />
        <Route path="/" element={<PrivateRoute><Home /></PrivateRoute>} />
        <Route path="/crew/create" element={<PrivateRoute><CreateCrew /></PrivateRoute>} />
        <Route path="/crew/:id" element={<PrivateRoute><CrewDetail /></PrivateRoute>} />
        <Route path="/crew/:id/goal/create" element={<PrivateRoute><CreateGoal /></PrivateRoute>} />
        <Route path="/crew/:id/log/create" element={<PrivateRoute><CreateLog /></PrivateRoute>} />
        <Route path="/notifications" element={<PrivateRoute><Notifications /></PrivateRoute>} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </>
  )
}

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  )
}
