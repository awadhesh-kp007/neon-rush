import { useAuth } from '../../app/App';

/**
 * HomePage — landing page of the player portal.
 * Shows hero section and CTA to play/register.
 */
export default function HomePage() {
  const { player } = useAuth();

  return (
    <div style={{ textAlign: 'center', paddingTop: '3rem' }}>
      {/* Hero */}
      <h1
        style={{
          fontSize: '3.5rem',
          fontWeight: 900,
          background: 'linear-gradient(135deg, #4af7ff, #b44aff)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent',
          marginBottom: '0.5rem',
        }}
      >
        NEON RUSH
      </h1>
      <p style={{ color: '#c084fc', fontSize: '1.2rem', marginBottom: '2rem' }}>
        CITY ESCAPE — Run. Survive. Escape.
      </p>

      {/* Story blurb */}
      <p style={{ color: '#aaa', maxWidth: 560, margin: '0 auto 2.5rem', lineHeight: 1.7 }}>
        In 2095, the mega-city of <strong style={{ color: '#4af7ff' }}>Neo Lumis</strong> is
        controlled by an automated security network. You&apos;ve stumbled onto a secret energy core —
        and now the AXIOM Grid is hunting you. Run through neon-lit railway stations, dodge trains,
        collect energy coins, and escape.
      </p>

      {/* CTA */}
      {player ? (
        <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center' }}>
          <a href="/profile" style={primaryBtn}>👤 My Profile</a>
          <a href="/leaderboard" style={secondaryBtn}>🏆 Leaderboard</a>
        </div>
      ) : (
        <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center' }}>
          <a href="/register" style={primaryBtn}>🚀 Get Started</a>
          <a href="/leaderboard" style={secondaryBtn}>🏆 Leaderboard</a>
        </div>
      )}

      {/* Stats strip */}
      <div
        style={{
          display: 'flex', justifyContent: 'center', gap: '3rem',
          marginTop: '4rem', borderTop: '1px solid #4af7ff22', paddingTop: '2.5rem',
        }}
      >
        {[
          { label: 'Players', value: '—' },
          { label: 'Runs Today', value: '—' },
          { label: 'Top Score', value: '—' },
        ].map(({ label, value }) => (
          <div key={label}>
            <div style={{ color: '#4af7ff', fontSize: '2rem', fontWeight: 800 }}>{value}</div>
            <div style={{ color: '#888', fontSize: '0.85rem' }}>{label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

const primaryBtn = {
  display: 'inline-block', padding: '0.75rem 2rem', borderRadius: 8,
  background: '#4af7ff', color: '#0d0221', fontWeight: 700,
  fontSize: '1.05rem', textDecoration: 'none',
};
const secondaryBtn = {
  display: 'inline-block', padding: '0.75rem 2rem', borderRadius: 8,
  border: '2px solid #4af7ff', color: '#4af7ff', fontWeight: 700,
  fontSize: '1.05rem', textDecoration: 'none',
};
