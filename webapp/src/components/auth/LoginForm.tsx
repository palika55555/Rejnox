"use client";

import Link from "next/link";
import { useActionState } from "react";
import { login } from "@/app/(auth)/actions";
import { Field, FormMessage, SubmitButton } from "./FormParts";

export function LoginForm() {
  const [state, action, pending] = useActionState(login, undefined);

  return (
    <form action={action} noValidate className="space-y-5">
      <FormMessage message={state?.message} />
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
        autoComplete="current-password"
        required
        error={state?.errors?.password}
      />
      <SubmitButton pending={pending} label="Prihlásiť sa" />
      <p className="text-center text-sm text-muted">
        Nemáš účet?{" "}
        <Link href="/registracia" className="font-semibold text-ink underline-offset-4 hover:underline">
          Zaregistruj sa
        </Link>
      </p>
    </form>
  );
}
