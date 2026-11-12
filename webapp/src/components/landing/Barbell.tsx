type Props = {
  /** Farby nasadených kotúčov, od objímky smerom von. */
  plates: { key: string; color: string }[];
  total: number;
  className?: string;
};

const HEIGHT = 64;
const PLATE_W = 13;
const GAP = 5;
const START = 22;

/** Progres ako činka: každý splnený krok pridá farebný kotúč na tyč. */
export function Barbell({ plates, total, className }: Props) {
  // Za kotúčmi ostane voľná tyč, aby činka vyplnila šírku karty.
  const width = START + total * (PLATE_W + GAP) + 130;
  const mid = HEIGHT / 2;

  return (
    <svg
      viewBox={`0 0 ${width} ${HEIGHT}`}
      className={className}
      preserveAspectRatio="xMinYMid meet"
      role="img"
      aria-label={`Splnené ${plates.length} z ${total}`}
    >
      {/* Tyč a objímka */}
      <rect x="0" y={mid - 3.5} width={width} height="7" rx="3.5" fill="#1E1B45" />
      <rect x="4" y={mid - 9} width="12" height="18" rx="3" fill="#8B88B5" />

      {Array.from({ length: total }, (_, i) => {
        // Kotúče sa smerom von zmenšujú, ako na skutočnej čince.
        const h = Math.max(30, HEIGHT - i * 5);
        const x = START + i * (PLATE_W + GAP);
        const plate = plates[i];
        return plate ? (
          <rect
            key={plate.key}
            className="plate-on"
            x={x}
            y={mid - h / 2}
            width={PLATE_W}
            height={h}
            rx="3"
            fill={plate.color}
          />
        ) : (
          <rect
            key={`empty-${i}`}
            x={x + 0.75}
            y={mid - h / 2 + 0.75}
            width={PLATE_W - 1.5}
            height={h - 1.5}
            rx="3"
            fill="none"
            stroke="rgb(169 155 255 / 0.22)"
            strokeWidth="1.5"
            strokeDasharray="3 3"
          />
        );
      })}
    </svg>
  );
}
