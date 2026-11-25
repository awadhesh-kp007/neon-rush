import apiClient from './apiClient';

// ─────────────────────────────────────────────────────────────────────────────
// Auth Service — wraps auth API calls with helpers for token persistence.
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Register a new player account.
 * @param {string} email
 * @param {string} password
 * @param {string} displayName
 * @returns {Promise<{player, accessToken, refreshToken}>}
 */
export async function register(email, password, displayName) {
  const { data } = await apiClient.post('/auth/register', {
    email,
    password,
    displayName,
  });
  _storeTokens(data.data);
  return data.data;
}

/**
 * Login with email and password.
 * @param {string} email
 * @param {string} password
 * @returns {Promise<{player, accessToken, refreshToken}>}
 */
export async function login(email, password) {
  const { data } = await apiClient.post('/auth/login', { email, password });
  _storeTokens(data.data);
  return data.data;
}

/**
 * Logout — clears local tokens and calls server logout.
 */
export async function logout() {
  try {
    await apiClient.post('/auth/logout');
  } finally {
    _clearTokens();
  }
}

/**
 * Returns the stored player info (from localStorage), or null.
 */
export function getStoredPlayer() {
  const raw = localStorage.getItem('player');
  return raw ? JSON.parse(raw) : null;
}

/**
 * Returns true if the user has a stored access token.
 */
export function isLoggedIn() {
  return Boolean(localStorage.getItem('accessToken'));
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function _storeTokens(authResponse) {
  localStorage.setItem('accessToken', authResponse.accessToken);
  localStorage.setItem('refreshToken', authResponse.refreshToken);
  localStorage.setItem('player', JSON.stringify(authResponse.player));
}

function _clearTokens() {
  localStorage.removeItem('accessToken');
  localStorage.removeItem('refreshToken');
  localStorage.removeItem('player');
}
