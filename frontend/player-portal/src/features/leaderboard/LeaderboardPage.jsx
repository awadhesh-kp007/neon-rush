import { useEffect, useState } from 'react';
import apiClient from '../../services/apiClient';

/**
 * LeaderboardPage — displays global top scores.
 * Public page — no authentication required.
 */
export default function LeaderboardPage() {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [tab, setTab] = useState('global'); // 'global' | 'weekly'

  useEffect(() => {
    fetchLeaderboard(tab);
  }, [tab]);

  const fetchLeaderboard = async (type) => {
    setLoading(true);
    setError('');
    try {
      const endpoint = type === 'weekly'
        ? '/game/leaderboard/weekly?limit=100'
        : '/game/leaderboard?limit=100';
      const { data } = await apiClient.get(endpoint);
      setEntries(data.data?.entries || []);
    } catch {
      setError('Failed to load leaderboard. Try again later.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <h2 style={{ color: '#4af7ff', marginBottom: '0.5rem' }}>🏆 Leaderboard</h2>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: '1rem', marginBottom: '1.5rem' }}>
        {['global', 'weekly'].map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            style={{
              padding: '0.4rem 1.2rem',
              borderRadius: 20,
              border: '1px solid #4af7ff',
              background: tab === t ? '#4af7ff' : 'transparent',
              color: tab === t ? '#0d0221' : '#4af7ff',
              cursor: 'pointer',
              fontWeight: 600,
              textTransform: 'capitalize',
            }}
          >
            {t}
          </button>
        ))}
      </div>

      {loading && <p style={{ color: '#aaa' }}>Loading…</p>}
      {error && <p style={{ color: '#ff6b6b' }}>{error}</p>}

      {!loading && !error && entries.length === 0 && (
        <p style={{ color: '#888' }}>No scores yet. Be the first runner!</p>
      )}

      {!loading && entries.length > 0 && (
        <table style={tableStyle}>
          <thead>
            <tr>
              {['Rank', 'Player', 'Score', 'Distance'].map((h) => (
                <th key={h} style={thStyle}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {entries.map((entry) => (
              <tr key={entry.playerId} style={trStyle(entry.rank)}>
                <td style={tdStyle}>{rankEmoji(entry.rank)}</td>
                <td style={tdStyle}>{entry.username}</td>
                <td style={{ ...tdStyle, color: '#ffe87a', fontWeight: 700 }}>
                  {entry.score.toLocaleString()}
                </td>
                <td style={tdStyle}>{entry.distance.toFixed(0)}m</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}

function rankEmoji(rank) {
  if (rank === 1) return '🥇 1';
  if (rank === 2) return '🥈 2';
  if (rank === 3) return '🥉 3';
  return `#${rank}`;
}

const tableStyle = {
  width: '100%', borderCollapse: 'collapse', fontSize: '0.95rem',
};
const thStyle = {
  textAlign: 'left', color: '#4af7ff', borderBottom: '1px solid #4af7ff44',
  padding: '0.6rem 0.75rem', fontWeight: 700,
};
const tdStyle = { padding: '0.55rem 0.75rem', color: '#ddd' };
const trStyle = (rank) => ({
  background: rank <= 3 ? '#1a0533' : 'transparent',
  borderBottom: '1px solid #ffffff0a',
});
