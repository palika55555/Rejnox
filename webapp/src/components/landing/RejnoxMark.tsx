import { useId } from "react";

/** Znak Rejnox: biele „R“ s fialovým pruhom (rovnaká geometria ako v appke). */
export function RejnoxMark({ className = "w-9", title = "Rejnox" }: { className?: string; title?: string }) {
  const gradientId = useId();
  return (
    <svg viewBox="0 0 492 305" className={className} role="img" aria-label={title}>
      <defs>
        <linearGradient id={gradientId} x1="0" y1="0" x2="235" y2="0" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#9B5CFF" />
          <stop offset="1" stopColor="#5B6CFF" />
        </linearGradient>
      </defs>
      <path
        fill="#fff"
        d="M68 0H385A107 107 0 0 1 385 214L400 215L478 305H365L235 155H385A38.5 38.5 0 0 0 385 78H130Z"
      />
      <path
        fill={`url(#${gradientId})`}
        d="M150 155H235L135 280Q115 305 85 305H0L100 180Q120 155 150 155Z"
      />
    </svg>
  );
}
