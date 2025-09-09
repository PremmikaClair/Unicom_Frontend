import React, { useEffect, useState } from "react";
import { getAbilitiesWhere } from "../../services/api";

type WhereResp = {
  action: string;
  orgs: { org_path: string; label?: string }[];
  version?: string;
};

const EventsPage: React.FC = () => {
  const [loading, setLoading] = useState(true);
  const [orgs, setOrgs] = useState<WhereResp["orgs"]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        setLoading(true);
        const resp = await getAbilitiesWhere("event:create");
        setOrgs(resp.orgs || []);
      } catch (e: any) {
        setError(e?.message ?? "Failed to check abilities");
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const canCreate = orgs.length > 0;

  if (loading) return <div className="p-4 text-gray-600">Checking permission…</div>;
  if (error)   return <div className="p-4 text-red-600">{error}</div>;

  return (
    <div className="p-4 space-y-3">
      <h1 className="text-xl font-semibold">Events</h1>

      {canCreate ? (
        <div className="space-y-2">
          <button
            type="button"
            className="px-3 py-1.5 bg-blue-600 text-white rounded"
            onClick={() => {
              // For testing, we just show where you could create.
              const first = orgs[0]?.org_path ?? "";
              alert(`You have permission to create events. Example org: ${first}`);
            }}
          >
            Create Event
          </button>

          {/* Optional debug list so you can see where it's allowed */}
          <div className="text-sm text-gray-600">
            You can create under:
            <ul className="list-disc ml-5">
              {orgs.map((g) => (
                <li key={g.org_path}>{g.label ?? g.org_path}</li>
              ))}
            </ul>
          </div>
        </div>
      ) : (
        <div className="text-gray-700">No permission to create events.</div>
      )}
    </div>
  );
};

export default EventsPage;