import { useAuth } from '../../app/App';

/**
 * ProfilePage — displays the authenticated player's stats and info.
 * Protected route — redirects to /login if not authenticated.
 */
export default function ProfilePage() {
  const { player, doLogout } = useAuth();

  if (!player) return null;

  return (
    <div style={{ maxWidth: 600, margin: '2rem auto' }}>
      <div style={cardStyle}>
        {/* Avatar placeholder */}
        <div style={avatarStyle}>
          {player.username?.[0]?.toUpperCase() || '?'}
        </div>
        <h2 style={{ color: '#4af7ff', margin: '0.75rem 0 0.25rem' }}>
          {player.username}
        </h2>
        <p style={{ color: '#888', fontSize: '0.9rem' }}>{player.email}</p>
        <span style={roleBadge}>{player.role}</span>

        <hr style={{ borderColor: '#4af7ff22', margin: '1.5rem 0' }} />

        {/* Stats grid — populated once backend stats API is live */}
        <div style={statsGrid}>
          {[
            { label: 'High Score', value: '—' },
            { label: 'Total Runs', value: '—' },
            { label: 'Best Distance', value: '—' },
            { label: 'Total Coins', value: '—' },
          ].map(({ label, value }) => (
            <div key={label} style={statBox}>
              <div style={{ color: '#ffe87a', fontSize: '1.6rem', fontWeight: 800 }}>{value}</div>
              <div style={{ color: '#888', fontSize: '0.8rem' }}>{label}</div>
            </div>
          ))}
        </div>

        <hr style={{ borderColor: '#4af7ff22', margin: '1.5rem 0' }} />

        <button onClick={doLogout} style={logoutBtn}>Logout</button>
      </div>
    </div>
  );
}

const cardStyle = {
  background: '#1a0533', borderRadius: 14, padding: '2.5rem',
  border: '1px solid #4af7ff33', textAlign: 'center',
};
const avatarStyle = {
  width: 80, height: 80, borderRadius: '50%',
  background: 'linear-gradient(135deg, #4af7ff, #b44aff)',
  display: 'flex', alignItems: 'center', justifyContent: 'center',
  fontSize: '2.5rem', fontWeight: 900, color: '#0d0221', margin: '0 auto',
};
const roleBadge = {
  display: 'inline-block', padding: '0.2rem 0.75rem', borderRadius: 20,
  background: '#4af7ff22', color: '#4af7ff', fontSize: '0.8rem',
  border: '1px solid #4af7ff55', marginTop: '0.5rem',
};
const statsGrid = {
  display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem',
};
const statBox = {
  background: '#0d0221', borderRadius: 10, padding: '1rem',
  border: '1px solid #ffffff0a',
};
const logoutBtn = {
  padding: '0.6rem 2rem', borderRadius: 8,
  border: '1px solid #ff6b6b', background: 'transparent',
  color: '#ff6b6b', cursor: 'pointer', fontWeight: 600,
};
