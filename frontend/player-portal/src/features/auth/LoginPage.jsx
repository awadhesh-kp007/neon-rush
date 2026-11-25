import { useState } from 'react';
import { useNavigate, Link } from 'react-router';
import { login } from '../../services/authService';
import { useAuth } from '../../app/App';

/**
 * LoginPage — email/password login form for the player portal.
 */
export default function LoginPage() {
  const navigate = useNavigate();
  const { setPlayer } = useAuth();
  const [form, setForm] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleChange = (e) => {
    setForm((prev) => ({ ...prev, [e.target.name]: e.target.value }));
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const authData = await login(form.email, form.password);
      setPlayer(authData.player);
      navigate('/profile');
    } catch (err) {
      setError(err.response?.data?.error?.message || 'Login failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={containerStyle}>
      <h2 style={titleStyle}>Login</h2>
      <form aria-label="Login form" onSubmit={handleSubmit} style={formStyle}>
        <label htmlFor="login-email" style={labelStyle}>Email</label>
        <input
          id="login-email"
          type="email"
          name="email"
          value={form.email}
          onChange={handleChange}
          required
          autoComplete="email"
          style={inputStyle}
          placeholder="you@example.com"
        />

        <label htmlFor="login-password" style={labelStyle}>Password</label>
        <input
          id="login-password"
          type="password"
          name="password"
          value={form.password}
          onChange={handleChange}
          required
          autoComplete="current-password"
          style={inputStyle}
          placeholder="••••••••"
        />

        {error && <p role="alert" aria-live="assertive" style={{ color: '#ff6b6b', margin: '0.25rem 0' }}>{error}</p>}

        <button type="submit" disabled={loading} style={submitStyle}>
          {loading ? 'Logging in…' : '▶ Login'}
        </button>
      </form>
      <p style={{ color: '#aaa', marginTop: '1rem', textAlign: 'center' }}>
        No account?{' '}
        <Link to="/register" style={{ color: '#4af7ff' }}>
          Register here
        </Link>
      </p>
    </div>
  );
}

// ── Styles ──────────────────────────────────────────────────────────────────
const containerStyle = {
  maxWidth: 420,
  margin: '3rem auto',
  background: '#1a0533',
  borderRadius: 12,
  padding: '2rem',
  border: '1px solid #4af7ff33',
};
const titleStyle = { color: '#4af7ff', textAlign: 'center', marginBottom: '1.5rem' };
const formStyle = { display: 'flex', flexDirection: 'column', gap: '0.75rem' };
const labelStyle = { color: '#ccc', fontSize: '0.9rem' };
const inputStyle = {
  padding: '0.6rem 0.75rem',
  borderRadius: 6,
  border: '1px solid #4af7ff55',
  background: '#0d0221',
  color: '#fff',
  fontSize: '1rem',
};
const submitStyle = {
  marginTop: '0.5rem',
  padding: '0.7rem',
  background: '#4af7ff',
  color: '#0d0221',
  border: 'none',
  borderRadius: 8,
  fontWeight: 700,
  fontSize: '1rem',
  cursor: 'pointer',
};
