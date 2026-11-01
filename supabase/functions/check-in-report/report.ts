// The day's list as the spreadsheet's rows (CI5, review 109 part 4): name,
// Team, In, Out, late and the place result, in the reader's language.
// Times come from the database already in the Space's time zone, with
// Western digits.

export type ReportRow = {
  name: string;
  team: string | null;
  in_time: string | null;
  out_time: string | null;
  in_late: boolean;
  out_late: boolean;
  // on_site, away, not_shared, or missed (no In).
  place: string | null;
};

export type Strings = Record<string, Record<string, string>>;

export function reportTable(rows: ReportRow[], locale: string, strings: Strings): string[][] {
  const t = strings[locale] ?? strings.en;
  const head = [t.name, t.team, t.in, t.out, t.late, t.place];
  const lines = rows.map((r) => {
    const late = [r.in_late ? t.in : null, r.out_late ? t.out : null].filter((x) => x).join(
      t.separator,
    );
    return [
      r.name,
      r.team ?? "",
      r.in_time ?? "",
      r.out_time ?? "",
      late,
      r.place ? t[`place_${r.place}`] ?? "" : "",
    ];
  });
  return [head, ...lines];
}
