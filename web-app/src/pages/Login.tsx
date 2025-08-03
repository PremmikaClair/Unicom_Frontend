import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

export default function Login() {
  const navigate = useNavigate()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  const handleMockLogin = () => {
    // Optional: add simple localStorage flag
    localStorage.setItem('isLoggedIn', 'true')
    navigate('/main')
  }

  return (
    <div className="flex flex-col justify-center items-center min-h-screen px-6 bg-white">
      <h1 className="text-2xl font-semibold text-center text-green-700 mb-6">
        KU Student Login
      </h1>

      <button
        onClick={handleMockLogin}
        className="w-full max-w-md bg-green-700 text-white py-3 rounded-xl mb-4"
      >
        Login with KU ALL‑Login (Mock)
      </button>

      <p className="text-gray-500 my-2">or</p>

      <input
        type="email"
        placeholder="Email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        className="w-full max-w-md border border-gray-300 rounded-lg px-4 py-3 mb-3 text-base"
      />
      <input
        type="password"
        placeholder="Password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        className="w-full max-w-md border border-gray-300 rounded-lg px-4 py-3 mb-4 text-base"
      />

      <button
        onClick={handleMockLogin}
        className="w-full max-w-md bg-blue-600 text-white py-3 rounded-xl"
      >
        Login (Mock)
      </button>

      <p className="text-xs text-gray-400 mt-6">
        Having trouble? Visit KU IT support.
      </p>
    </div>
  )
}
