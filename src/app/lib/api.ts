const API_BASE = import.meta.env.VITE_API_BASE || '/api';
const DEFAULT_TIMEOUT_MS = 15_000;

export type ApiRequestInit = RequestInit & {
  timeoutMs?: number;
};

export class ApiError extends Error {
  status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
  }
}

export async function api<T>(path: string, init: ApiRequestInit = {}): Promise<T> {
  const { timeoutMs = DEFAULT_TIMEOUT_MS, signal: callerSignal, ...fetchInit } = init;
  const headers = new Headers(fetchInit.headers);
  if (fetchInit.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }
  headers.set('X-Requested-With', 'XMLHttpRequest');

  const controller = new AbortController();
  let timedOut = false;
  const abortFromCaller = () => controller.abort(callerSignal?.reason);
  if (callerSignal?.aborted) abortFromCaller();
  else callerSignal?.addEventListener('abort', abortFromCaller, { once: true });

  const timer = window.setTimeout(() => {
    timedOut = true;
    controller.abort();
  }, timeoutMs);

  try {
    const response = await fetch(`${API_BASE}${path}`, {
      ...fetchInit,
      headers,
      credentials: 'include',
      signal: controller.signal,
    });

    const contentType = response.headers.get('content-type') || '';
    const data = contentType.includes('application/json')
      ? await response.json()
      : { message: await response.text() };

    if (!response.ok) {
      throw new ApiError(data.message || 'Request failed.', response.status);
    }

    return data as T;
  } catch (error) {
    if (timedOut) {
      throw new ApiError(
        'Request timed out. Please check your connection and try again. / 请求超时，请检查网络后重试。',
        408,
      );
    }
    throw error;
  } finally {
    window.clearTimeout(timer);
    callerSignal?.removeEventListener('abort', abortFromCaller);
  }
}
