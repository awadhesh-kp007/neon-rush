import { fireEvent, render, screen } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import App from './App';
import { login, register } from '../services/authService';

vi.mock('../services/authService', () => ({
  getStoredPlayer: vi.fn(() => null),
  isLoggedIn: vi.fn(() => false),
  logout: vi.fn().mockResolvedValue(undefined),
  login: vi.fn(),
  register: vi.fn(),
}));

vi.mock('../services/apiClient', () => ({
  default: { get: vi.fn().mockResolvedValue({ data: { data: { entries: [] } } }) },
}));

describe('App routes', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    login.mockResolvedValue({ player: { username: 'TestRunner', email: 'runner@example.com' } });
    register.mockResolvedValue({ player: { username: 'NewRunner', email: 'new@example.com' } });
    window.history.replaceState({}, '', '/');
  });

  it.each([
    ['/', 'heading', 'NEON RUSH'],
    ['/login', 'form', 'Login form'],
    ['/register', 'form', 'Registration form'],
    ['/leaderboard', 'heading', /Leaderboard/],
  ])('renders the public route %s', (path, role, accessibleName) => {
    window.history.replaceState({}, '', path);
    render(<App />);

    expect(screen.getByRole(role, { name: accessibleName })).toBeInTheDocument();
  });

  it('redirects an unauthenticated profile visit to login', () => {
    window.history.replaceState({}, '', '/profile');
    render(<App />);

    expect(screen.getByRole('form', { name: 'Login form' })).toBeInTheDocument();
    expect(window.location.pathname).toBe('/login');
  });

  it('redirects an unknown route to home', () => {
    window.history.replaceState({}, '', '/not-a-route');
    render(<App />);

    expect(screen.getByRole('heading', { name: 'NEON RUSH' })).toBeInTheDocument();
    expect(window.location.pathname).toBe('/');
  });

  it('navigates to profile after successful login', async () => {
    window.history.replaceState({}, '', '/login');
    render(<App />);
    fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'runner@example.com' } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Password123' } });
    fireEvent.submit(screen.getByRole('form', { name: 'Login form' }));

    expect(await screen.findByRole('heading', { name: 'TestRunner' })).toBeInTheDocument();
    expect(window.location.pathname).toBe('/profile');
  });

  it('navigates to profile after successful registration', async () => {
    window.history.replaceState({}, '', '/register');
    render(<App />);
    fireEvent.change(screen.getByLabelText('Display Name'), { target: { value: 'NewRunner' } });
    fireEvent.change(screen.getByLabelText('Email'), { target: { value: 'new@example.com' } });
    fireEvent.change(screen.getByLabelText('Password'), { target: { value: 'Password123' } });
    fireEvent.submit(screen.getByRole('form', { name: 'Registration form' }));

    expect(await screen.findByRole('heading', { name: 'NewRunner' })).toBeInTheDocument();
    expect(window.location.pathname).toBe('/profile');
  });
});