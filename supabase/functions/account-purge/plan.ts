// The rows of accounts_due_for_purge(), one per stored file (bucket and name
// null when the account has none), grouped per account and bucket.

export type DueRow = { profile_id: string; bucket: string | null; name: string | null };

export type DueAccount = { id: string; files: Map<string, string[]> };

export function groupDue(rows: DueRow[]): DueAccount[] {
  const byId = new Map<string, DueAccount>();
  for (const r of rows) {
    let account = byId.get(r.profile_id);
    if (!account) {
      account = { id: r.profile_id, files: new Map() };
      byId.set(r.profile_id, account);
    }
    if (r.bucket && r.name) {
      const names = account.files.get(r.bucket) ?? [];
      names.push(r.name);
      account.files.set(r.bucket, names);
    }
  }
  return [...byId.values()];
}
