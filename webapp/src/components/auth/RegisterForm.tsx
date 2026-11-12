"use client";

import Link from "next/link";
import { useActionState } from "react";
import { register } from "@/app/(auth)/actions";
import { Field, FormMessage, SubmitButton } from "./FormParts";

const roles = [
  { value: "member", label: "Cvičím", text: "Zapisujem si tréningy a mám plán od trénera." },
  { value: "trainer", label: "Som tréner", text: "Vediem klientov, píšem im plány a sledujem progres." },
];

export function RegisterForm() {
  const [state, action, pending] = useActionState(register, undefined);
  const selectedRole = state?.values?.role ?? "member";

  return (
    <form action={action} noValidate className="space-y-5">
      <FormMessage message={state?.message} />
      <Field
        name="displayName"
        label="Meno"
        autoComplete="name"
        maxLength={60}
        required
        defaultValue={state?.values?.displayName}
        error={state?.errors?.displayName}
      />
      <Field
        name="email"
        label="E-mail"
        type="email"
        autoComplete="email"
        required
        defaultValue={state?.values?.email}
        error={state?.errors?.email}
      />
      <Field
        name="password"
        label="Heslo"
        type="password"
        autoComplete="new-password"
        minLength={8}
        required
        hint="Aspoň 8 znakov."
        error={state?.errors?.password}
      />

      <fieldset>
        <legend className="text-sm font-semibold">Ako budeš Rejnox používať?</legend>
        <div className="mt-2 grid gap-2 sm:grid-cols-2">
          {roles.map((role) => (
            <label
              key={role.value}
              className="cursor-pointer rounded-xl border border-line p-4 transition-colors has-[:checked]:border-brand-violet has-[:checked]:bg-surface-hi has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-accent"
            >
              <input
                type="radio"
                name="role"
                value={role.value}
                defaultChecked={role.value === selectedRole}
                className="sr-only"
              />
              <span className="block font-display font-extrabold">{role.label}</span>
              <span className="mt-1 block text-sm leading-snug text-muted">{role.text}</span>
            </label>
          ))}
        </div>
        {state?.errors?.role && <p className="mt-1.5 text-sm text-plate-red">{state.errors.role}</p>}
      </fieldset>

      <SubmitButton pending={pending} label="Vytvoriť účet" />
      <p className="text-center text-xs leading-relaxed text-muted">
        Vytvorením účtu berieš na vedomie, ako spracúvame tvoje údaje podľa{" "}
        <Link href="/ochrana-osobnych-udajov" className="text-ink underline underline-offset-4">
          zásad ochrany osobných údajov
        </Link>
        .
      </p>
      <p className="text-center text-sm text-muted">
        Už máš účet?{" "}
        <Link href="/prihlasenie" className="font-semibold text-ink underline-offset-4 hover:underline">
          Prihlás sa
        </Link>
      </p>
    </form>
  );
}
