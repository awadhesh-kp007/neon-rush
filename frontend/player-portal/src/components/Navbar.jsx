import { Link } from 'react-router';
import { useAuth } from '../app/App';

/**
 * Navbar — top navigation bar for the player portal.
 * Shows login/register when logged out; username + logout when logged in.
 */
export default function Navbar() {
  const { player, doLogout } = useAuth();

  return (
    <nav
      style={{
        background: 'linear-gradient(90deg, #0d0221 0%, #1a0533 100%)',
        padding: '0.75rem 1.5rem',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        borderBottom: '2px solid #4af7ff',
        marginBottom: '1.5rem',
      }}
    >
      {/* Brand */}
      <Link
        to="/"
        style={{
          color: '#4af7ff',
          fontWeight: 900,
          fontSize: '1.3rem',
          textDecoration: 'none',
          letterSpacing: '0.08em',
        }}
      >
        ⚡ NEON RUSH
      </Link>

      {/* Nav links */}
      <div style={{ display: 'flex', gap: '1.25rem', alignItems: 'center' }}>
        <NavLink to="/leaderboard">🏆 Leaderboard</NavLink>
        {player ? (
          <>
            <NavLink to="/profile">👤 {player.username}</NavLink>
            <button
              onClick={doLogout}
              style={btnStyle}
            >
              Logout
            </button>
          </>
        ) : (
          <>
            <NavLink to="/login">Login</NavLink>
            <Link to="/register" style={{ ...btnStyle, background: '#4af7ff', color: '#0d0221' }}>
              Register
            </Link>
          </>
        )}
      </div>
    </nav>
  );
}

function NavLink({ to, children }) {
  return (
    <Link
      to={to}
      style={{ color: '#ccc', textDecoration: 'none', fontSize: '0.95rem' }}
    >
      {children}
    </Link>
  );
}

const btnStyle = {
  padding: '0.4rem 1rem',
  borderRadius: 6,
  border: '1px solid #4af7ff',
  background: 'transparent',
  color: '#4af7ff',
  cursor: 'pointer',
  fontSize: '0.9rem',
  textDecoration: 'none',
};
