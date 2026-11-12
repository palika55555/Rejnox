import type { InputHTMLAttributes } from "react";

type FieldProps = InputHTMLAttributes<HTMLInputElement> & {
  name: string;
  label: string;
  hint?: string;
  error?: string;
};

/** Textové pole s popisom, nápovedou a chybou prepojenými cez aria. */
export function Field({ name, label, hint, error, ...input }: FieldProps) {
  const describedBy = error ? `${name}-error` : hint ? `${name}-hint` : undefined;
  return (
    <div>
      <label htmlFor={name} className="block text-sm font-semibold">
        {label}
      </label>
      <input
        id={name}
        name={name}
        aria-invalid={error ? true : undefined}
        aria-describedby={describedBy}
        className={`mt-2 w-full rounded-xl border bg-night/60 px-4 py-3 text-base outline-none transition-colors placeholder:text-muted/60 focus:border-brand-violet ${
          error ? "border-plate-red" : "border-line"
        }`}
        {...input}
      />
      {error ? (
        <p id={`${name}-error`} className="mt-1.5 text-sm text-plate-red">
          {error}
        </p>
      ) : hint ? (
        <p id={`${name}-hint`} className="mt-1.5 text-sm text-muted">
          {hint}
        </p>
      ) : null}
    </div>
  );
}

export function FormMessage({ message }: { message?: string }) {
  if (!message) return null;
  return (
    <p role="alert" className="rounded-xl border border-plate-red/40 bg-plate-red/10 px-4 py-3 text-sm">
      {message}
    </p>
  );
}

export function SubmitButton({ pending, label }: { pending: boolean; label: string }) {
  return (
    <button
      type="submit"
      disabled={pending}
      className="btn-action w-full rounded-xl py-3.5 font-bold text-white transition-opacity disabled:opacity-60"
    >
      {pending ? "Chvíľu strpenia…" : label}
    </button>
  );
}
