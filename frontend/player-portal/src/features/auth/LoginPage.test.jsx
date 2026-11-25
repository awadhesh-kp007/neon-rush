import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import LoginPage from './LoginPage';
import { login } from '../../services/authService';

vi.mock('../../services/authService', () => ({ login: vi.fn() }));
vi.mock('../../app/App', () => ({ useAuth: () => ({ setPlayer: vi.fn() }) }));

describe('LoginPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('associates labels with required inputs', () => {
    render(<MemoryRouter><LoginPage /></MemoryRouter>);

    expect(screen.getByRole('form', { name: 'Login form' })).toHaveProperty('noValidate', false);
    expect(screen.getByLabelText('Email')).toBeRequired();
    expect(screen.getByLabelText('Password')).toBeRequired();
  });

  it('announces rejected login and keeps the form present', async () => {
    login.mockRejectedValue(new Error('Login failed'));
    render(<MemoryRouter><LoginPage /></MemoryRouter>);

    fireEvent.submit(screen.getByRole('form', { name: 'Login form' }));

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveAttribute('aria-live', 'assertive');
    expect(alert).toHaveTextContent('Login failed. Please try again.');
    await waitFor(() => expect(screen.getByRole('form', { name: 'Login form' })).toBeInTheDocument());
  });
});