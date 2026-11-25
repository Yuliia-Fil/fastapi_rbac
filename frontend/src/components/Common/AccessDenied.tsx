import { isAxiosError } from "axios"
import { AccessDeniedError } from "@/lib/permissions"
import ErrorComponent from "./ErrorComponent"

export function ProtectedRouteError({ error }: { error: unknown }) {
  if (
    error instanceof AccessDeniedError ||
    (isAxiosError(error) && error.response?.status === 403)
  ) {
    return (
      <section className="mx-auto max-w-7xl p-6">
        <h1 className="text-2xl font-bold">Access denied</h1>
        <p className="mt-2 text-muted-foreground">
          Your account does not have permission to view this page.
        </p>
      </section>
    )
  }

  return <ErrorComponent />
}
