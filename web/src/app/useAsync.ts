// Loading a resource in a component: loading, ready or error, with a reload. The latest request wins.

import { useCallback, useEffect, useRef, useState } from 'preact/hooks';

export type AsyncState<T> =
  | { readonly status: 'loading' }
  | { readonly status: 'ready'; readonly data: T }
  | { readonly status: 'error'; readonly error: unknown };

export function useAsync<T>(load: () => Promise<T>, deps: readonly unknown[]): { state: AsyncState<T>; reload: () => void } {
  const [state, setState] = useState<AsyncState<T>>({ status: 'loading' });
  const [attempt, setAttempt] = useState(0);
  const latest = useRef(0);
  useEffect(() => {
    const id = latest.current + 1;
    latest.current = id;
    setState({ status: 'loading' });
    load().then(
      (data) => {
        if (latest.current === id) setState({ status: 'ready', data });
      },
      (error: unknown) => {
        if (latest.current === id) setState({ status: 'error', error });
      },
    );
    // `load` is a closure over `deps`, which are the real inputs of the request.
  }, [...deps, attempt]);
  const reload = useCallback(() => {
    setAttempt((value) => value + 1);
  }, []);
  return { state, reload };
}
