import { useEffect, useMemo, useState } from 'react';
import { getAbilities } from '../services/api';
import type { AbilitiesResp } from '../types';

const DEFAULT_KEYS = [
  'membership:assign',
  'membership:revoke',
  'position:create',
  'policy:write',
  'event:create',
  'event:manage',
  'post:create',
  'post:moderate',
];

export function useAbilities(orgPath?: string) {
  const [abilities, setAbilities] = useState<Record<string, boolean>>({});
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const path = (orgPath || '').trim();

  const refetch = async () => {
    if (!path) { setAbilities({}); return; }
    try {
      setLoading(true);
      setError(null);
      const res: AbilitiesResp = await getAbilities(path);
      const map = res?.abilities || {};
      // Ensure all default keys exist for stability
      const filled: Record<string, boolean> = {};
      for (const k of DEFAULT_KEYS) filled[k] = !!map[k];
      setAbilities(filled);
    } catch (e: any) {
      setError(e?.message || 'Failed to load abilities');
      setAbilities({});
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { refetch(); /* eslint-disable react-hooks/exhaustive-deps */ }, [path]);

  return useMemo(() => ({ abilities, loading, error, refetch }), [abilities, loading, error]);
}

export default useAbilities;

