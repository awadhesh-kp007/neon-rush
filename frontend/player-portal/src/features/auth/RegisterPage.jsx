import { useState } from 'react';
import { useNavigate, Link } from 'react-router';
import { register } from '../../services/authService';
import { useAuth } from '../../app/App';

/**
 * RegisterPage — new player account creation form.
 */
export default function RegisterPage() {
  const navigate = useNavigate();
  const { setPlayer } = useAuth();
  const [form, setForm] = useState({ email: '', password: '', displayName: '' });
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
      const authData = await register(form.email, form.password, form.displayName);
      setPlayer(authData.player);
      navigate('/profile');
    } catch (err) {
      setError(err.response?.data?.error?.message || 'Registration failed. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={containerStyle}>
      <h2 style={titleStyle}>Create Account</h2>
      <form aria-label="Registration form" onSubmit={handleSubmit} style={formStyle}>
        <label htmlFor="register-display-name" style={labelStyle}>Display Name</label>
        <input
          id="register-display-name"
          type="text"
          name="displayName"
          value={form.displayName}
          onChange={handleChange}
          required
          minLength={3}
          maxLength={32}
          style={inputStyle}
          placeholder="YourRunnerName"
        />

        <label htmlFor="register-email" style={labelStyle}>Email</label>
        <input
          id="register-email"
          type="email"
          name="email"
          value={form.email}
          onChange={handleChange}
          required
          style={inputStyle}
          placeholder="you@example.com"
        />

        <label htmlFor="register-password" style={labelStyle}>Password</label>
        <input
          id="register-password"
          type="password"
          name="password"
          value={form.password}
          onChange={handleChange}
          required
          minLength={8}
          style={inputStyle}
          placeholder="Min 8 chars, upper + lower + digit"
        />

        {error && <p role="alert" aria-live="assertive" style={{ color: '#ff6b6b', margin: '0.25rem 0' }}>{error}</p>}

        <button type="submit" disabled={loading} style={submitStyle}>
          {loading ? 'Creating account…' : '🚀 Register'}
        </button>
      </form>
      <p style={{ color: '#aaa', marginTop: '1rem', textAlign: 'center' }}>
        Already have an account?{' '}
        <Link to="/login" style={{ color: '#4af7ff' }}>Login</Link>
      </p>
    </div>
  );
}

const containerStyle = {
  maxWidth: 420, margin: '3rem auto', background: '#1a0533',
  borderRadius: 12, padding: '2rem', border: '1px solid #4af7ff33',
};
const titleStyle = { color: '#4af7ff', textAlign: 'center', marginBottom: '1.5rem' };
const formStyle = { display: 'flex', flexDirection: 'column', gap: '0.75rem' };
const labelStyle = { color: '#ccc', fontSize: '0.9rem' };
const inputStyle = {
  padding: '0.6rem 0.75rem', borderRadius: 6, border: '1px solid #4af7ff55',
  background: '#0d0221', color: '#fff', fontSize: '1rem',
};
const submitStyle = {
  marginTop: '0.5rem', padding: '0.7rem', background: '#4af7ff',
  color: '#0d0221', border: 'none', borderRadius: 8, fontWeight: 700,
  fontSize: '1rem', cursor: 'pointer',
};
