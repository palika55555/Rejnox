/** Kostry stránok trénerskej zóny: ukážu sa hneď po kliknutí, kým prídu dáta. */

function Bar({ className }: { className: string }) {
  return <div className={`skeleton rounded-xl ${className}`} />;
}

function Shell({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div aria-busy="true" aria-live="polite">
      <span className="sr-only">{label}</span>
      {children}
    </div>
  );
}

export function GridSkeleton({ label = "Načítavam…" }: { label?: string }) {
  return (
    <Shell label={label}>
      <Bar className="h-4 w-32" />
      <Bar className="mt-3 h-14 w-72 max-w-full" />
      <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <Bar key={i} className="h-32 rounded-3xl" />
        ))}
      </div>
      <div className="mt-10 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
        {[0, 1, 2].map((i) => (
          <Bar key={i} className="h-56 rounded-3xl" />
        ))}
      </div>
    </Shell>
  );
}

export function ClientSkeleton() {
  return (
    <Shell label="Načítavam klienta…">
      <Bar className="h-4 w-28" />
      <div className="mt-5 flex items-center gap-4">
        <Bar className="size-16 rounded-3xl" />
        <div className="space-y-2">
          <Bar className="h-10 w-64 max-w-full" />
          <Bar className="h-4 w-40" />
        </div>
      </div>
      <Bar className="mt-8 h-10 w-56" />
      <div className="mt-6 space-y-3">
        {[0, 1, 2].map((i) => (
          <Bar key={i} className="h-24 rounded-3xl" />
        ))}
      </div>
    </Shell>
  );
}

export function CalendarSkeleton() {
  return (
    <Shell label="Načítavam kalendár…">
      <Bar className="h-4 w-24" />
      <Bar className="mt-3 h-14 w-80 max-w-full" />
      <div className="mt-8 grid gap-3 sm:grid-cols-2 lg:grid-cols-4 xl:grid-cols-7">
        {[0, 1, 2, 3, 4, 5, 6].map((i) => (
          <Bar key={i} className="h-44 rounded-3xl" />
        ))}
      </div>
    </Shell>
  );
}

export function EditorSkeleton() {
  return (
    <Shell label="Načítavam jedálniček…">
      <Bar className="h-4 w-28" />
      <Bar className="mt-3 h-12 w-72 max-w-full" />
      <div className="mt-6 grid gap-6 lg:grid-cols-[1fr_18rem]">
        <div className="space-y-6">
          <Bar className="h-20 rounded-3xl" />
          <Bar className="h-52 rounded-3xl" />
          <Bar className="h-64 rounded-3xl" />
        </div>
        <Bar className="h-48 rounded-3xl" />
      </div>
    </Shell>
  );
}
