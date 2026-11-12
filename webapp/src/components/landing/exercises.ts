/** Svalové partie a ich farba kotúča – zhodné s MuscleGroup v appke. */
export type MuscleGroup = "nohy" | "hrudnik" | "chrbat" | "ramena";

export const plateColor: Record<MuscleGroup, string> = {
  nohy: "#FF4D6A",
  chrbat: "#4D8BFF",
  hrudnik: "#FFC542",
  ramena: "#2BD98B",
};

export const groupLabel: Record<MuscleGroup, string> = {
  nohy: "Nohy",
  chrbat: "Chrbát",
  hrudnik: "Hrudník",
  ramena: "Ramená",
};

export type DemoExercise = {
  id: string;
  name: string;
  group: MuscleGroup;
  reps: number;
  weightKg: number;
};

export const demoExercises: DemoExercise[] = [
  { id: "drep", name: "Drep", group: "nohy", reps: 8, weightKg: 80 },
  { id: "tlak-lavica", name: "Tlak na lavici", group: "hrudnik", reps: 10, weightKg: 60 },
  { id: "pritahy", name: "Príťahy v predklone", group: "chrbat", reps: 10, weightKg: 50 },
  { id: "tlak-hlava", name: "Tlak nad hlavu", group: "ramena", reps: 8, weightKg: 35 },
];

export function formatKg(kg: number): string {
  return `${kg.toLocaleString("sk-SK", { maximumFractionDigits: 1 })} kg`;
}
