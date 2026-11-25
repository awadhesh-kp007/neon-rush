import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import RegisterPage from './RegisterPage';
import { register } from '../../services/authService';

vi.mock('../../services/authService', () => ({ register: vi.fn() }));
vi.mock('../../app/App', () => ({ useAuth: () => ({ setPlayer: vi.fn() }) }));

describe('RegisterPage', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('associates labels with required inputs', () => {
    render(<MemoryRouter><RegisterPage /></MemoryRouter>);

    expect(screen.getByRole('form', { name: 'Registration form' })).toHaveProperty('noValidate', false);
    expect(screen.getByLabelText('Display Name')).toBeRequired();
    expect(screen.getByLabelText('Email')).toBeRequired();
    expect(screen.getByLabelText('Password')).toBeRequired();
  });

  it('announces rejected registration and keeps the form present', async () => {
    register.mockRejectedValue(new Error('Registration failed'));
    render(<MemoryRouter><RegisterPage /></MemoryRouter>);

    fireEvent.submit(screen.getByRole('form', { name: 'Registration form' }));

    const alert = await screen.findByRole('alert');
    expect(alert).toHaveAttribute('aria-live', 'assertive');
    expect(alert).toHaveTextContent('Registration failed. Please try again.');
    await waitFor(() => expect(screen.getByRole('form', { name: 'Registration form' })).toBeInTheDocument());
  });
});