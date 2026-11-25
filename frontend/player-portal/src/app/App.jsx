import { BrowserRouter, Routes, Route, Navigate } from 'react-router';
import { useState, createContext, useContext } from 'react';
import { getStoredPlayer, isLoggedIn, logout } from '../services/authService';
import LoginPage from '../features/auth/LoginPage';
import RegisterPage from '../features/auth/RegisterPage';
import LeaderboardPage from '../features/leaderboard/LeaderboardPage';
import ProfilePage from '../features/profile/ProfilePage';
import HomePage from '../features/home/HomePage';
import Navbar from '../components/Navbar';

// ─────────────────────────────────────────────────────────────────────────────
// Auth Context — shared auth state across the app
// ─────────────────────────────────────────────────────────────────────────────

export const AuthContext = createContext(null);

export function useAuth() {
  return useContext(AuthContext);
}

// ─────────────────────────────────────────────────────────────────────────────
// Protected Route — redirects to /login if not authenticated
// ─────────────────────────────────────────────────────────────────────────────

function ProtectedRoute({ children }) {
  const { player } = useAuth();
  return player ? children : <Navigate to="/login" replace />;
}

// ─────────────────────────────────────────────────────────────────────────────
// App Root
// ─────────────────────────────────────────────────────────────────────────────

export default function App() {
  const [player, setPlayer] = useState(getStoredPlayer());

  const authValue = {
    player,
    setPlayer,
    loggedIn: isLoggedIn(),
    doLogout: async () => {
      await logout();
      setPlayer(null);
    },
  };

  return (
    <AuthContext.Provider value={authValue}>
      <BrowserRouter>
        <Navbar />
        <main style={{ padding: '0 1rem', maxWidth: 960, margin: '0 auto' }}>
          <Routes>
            {/* Public */}
            <Route path="/" element={<HomePage />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/register" element={<RegisterPage />} />
            <Route path="/leaderboard" element={<LeaderboardPage />} />

            {/* Protected */}
            <Route
              path="/profile"
              element={
                <ProtectedRoute>
                  <ProfilePage />
                </ProtectedRoute>
              }
            />

            {/* Fallback */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
      </BrowserRouter>
    </AuthContext.Provider>
  );
}
