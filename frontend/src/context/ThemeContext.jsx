import { createContext, useContext, useState, useEffect } from 'react'

const ThemeContext = createContext(null)

function applyTheme(mode) {
  document.documentElement.setAttribute('data-theme', mode === 'light' ? 'light' : 'dark')
}

export function ThemeProvider({ children }) {
  const [mode, setMode] = useState(() => localStorage.getItem('wogether-theme') || 'dark')

  useEffect(() => { applyTheme(mode) }, [mode])

  const changeMode = (m) => {
    setMode(m)
    localStorage.setItem('wogether-theme', m)
  }

  return (
    <ThemeContext.Provider value={{ mode, changeMode }}>
      {children}
    </ThemeContext.Provider>
  )
}

export const useTheme = () => useContext(ThemeContext)
