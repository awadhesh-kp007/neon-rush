import { afterEach, describe, expect, it, vi } from 'vitest';
import axios from 'axios';
import apiClient from './apiClient';

describe('apiClient authentication failures', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('settles concurrent 401 requests without a refresh token and redirects once', async () => {
    const values = new Map([
      ['accessToken', 'expired-access-token'],
      ['player', '{"id":"player-1"}'],
      ['unrelated-setting', 'keep-me'],
    ]);
    const storage = {
      getItem: vi.fn((key) => values.get(key) ?? null),
      setItem: vi.fn((key, value) => values.set(key, value)),
      removeItem: vi.fn((key) => values.delete(key)),
    };
    let redirectedTo = null;
    const location = {};
    Object.defineProperty(location, 'href', {
      set: vi.fn((value) => {
        redirectedTo = value;
      }),
    });
    vi.stubGlobal('localStorage', storage);
    vi.stubGlobal('window', { location });

    const originalAdapter = apiClient.defaults.adapter;
    apiClient.defaults.adapter = (config) => Promise.reject({
      config,
      response: { status: 401 },
    });

    try {
      const results = await Promise.allSettled([
        apiClient.get('/protected/one'),
        apiClient.get('/protected/two'),
        apiClient.get('/protected/three'),
      ]);

      expect(results).toHaveLength(3);
      expect(results.every(({ status }) => status === 'rejected')).toBe(true);
      expect(values.has('accessToken')).toBe(false);
      expect(values.has('refreshToken')).toBe(false);
      expect(values.has('player')).toBe(false);
      expect(values.get('unrelated-setting')).toBe('keep-me');
      expect(location.href).toBeUndefined();
      expect(redirectedTo).toBe('/login');
      expect(Object.getOwnPropertyDescriptor(location, 'href').set).toHaveBeenCalledTimes(1);
    } finally {
      apiClient.defaults.adapter = originalAdapter;
    }
  });

  it('rejects actual requests queued during refresh failure and clears auth state once', async () => {
    const values = new Map([
      ['accessToken', 'expired-access-token'],
      ['refreshToken', 'expired-refresh-token'],
      ['player', '{"id":"player-1"}'],
      ['unrelated-setting', 'keep-me'],
    ]);
    const storage = {
      getItem: vi.fn((key) => values.get(key) ?? null),
      setItem: vi.fn((key, value) => values.set(key, value)),
      removeItem: vi.fn((key) => values.delete(key)),
    };
    let redirectedTo = null;
    const location = {};
    Object.defineProperty(location, 'href', {
      set: vi.fn((value) => {
        redirectedTo = value;
      }),
    });
    vi.stubGlobal('localStorage', storage);
    vi.stubGlobal('window', { location });

    let rejectRefresh;
    const refreshRequest = new Promise((resolve, reject) => {
      rejectRefresh = reject;
    });
    const refreshPost = vi.spyOn(axios, 'post').mockReturnValue(refreshRequest);
    const originalAdapter = apiClient.defaults.adapter;
    const originalAuthorization = apiClient.defaults.headers.Authorization;
    apiClient.defaults.headers.Authorization = 'Bearer stale-default-token';
    const requestedUrls = [];
    apiClient.defaults.adapter = (config) => {
      requestedUrls.push(config.url);
      return Promise.reject({ config, response: { status: 401 } });
    };

    try {
      const requestResults = Promise.allSettled([
        apiClient.get('/protected/one'),
        apiClient.get('/protected/two'),
        apiClient.get('/protected/three'),
      ]);
      let settledCount = 0;
      requestResults.then((results) => {
        settledCount = results.length;
      });

      await vi.waitFor(() => {
        expect(requestedUrls).toHaveLength(3);
        expect(refreshPost).toHaveBeenCalledTimes(1);
      });
      expect(settledCount).toBe(0);

      rejectRefresh(new Error('refresh endpoint unavailable'));
      const results = await requestResults;

      expect(results).toHaveLength(3);
      expect(results.every(({ status }) => status === 'rejected')).toBe(true);
      expect(refreshPost).toHaveBeenCalledTimes(1);
      expect(values.has('accessToken')).toBe(false);
      expect(values.has('refreshToken')).toBe(false);
      expect(values.has('player')).toBe(false);
      expect(values.get('unrelated-setting')).toBe('keep-me');
      expect(apiClient.defaults.headers.Authorization).toBeUndefined();
      expect(redirectedTo).toBe('/login');
      expect(Object.getOwnPropertyDescriptor(location, 'href').set).toHaveBeenCalledTimes(1);
    } finally {
      apiClient.defaults.adapter = originalAdapter;
      if (originalAuthorization === undefined) {
        delete apiClient.defaults.headers.Authorization;
      } else {
        apiClient.defaults.headers.Authorization = originalAuthorization;
      }
    }
  });

  it('does not send a stale default Authorization header without a local access token', async () => {
    const storage = {
      getItem: vi.fn(() => null),
      setItem: vi.fn(),
      removeItem: vi.fn(),
    };
    vi.stubGlobal('localStorage', storage);

    const originalAdapter = apiClient.defaults.adapter;
    const originalAuthorization = apiClient.defaults.headers.Authorization;
    apiClient.defaults.headers.Authorization = 'Bearer stale-default-token';
    let requestAuthorization;
    apiClient.defaults.adapter = (config) => {
      requestAuthorization = config.headers.Authorization;
      return Promise.resolve({ config, data: {}, status: 200, statusText: 'OK', headers: {} });
    };

    try {
      await apiClient.get('/public');
      expect(requestAuthorization).toBeUndefined();
    } finally {
      apiClient.defaults.adapter = originalAdapter;
      if (originalAuthorization === undefined) {
        delete apiClient.defaults.headers.Authorization;
      } else {
        apiClient.defaults.headers.Authorization = originalAuthorization;
      }
    }
  });
});