import { useSuspenseQuery } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { MetricsService } from "@/client"
import { ProtectedRouteError } from "@/components/Common/AccessDenied"
import { requireCapability } from "@/lib/permissions"

export const Route = createFileRoute("/_layout/metrics")({
  beforeLoad: ({ context }) => {
    requireCapability(context.currentUser, "view_metrics")
  },
  component: Metrics,
  errorComponent: ProtectedRouteError,
  pendingComponent: () => <p role="status">Loading metrics…</p>,
  head: () => ({ meta: [{ title: "Metrics - FastAPI Template" }] }),
})

function Metrics() {
  const { data } = useSuspenseQuery({
    queryKey: ["metrics"],
    queryFn: async () => (await MetricsService.readMetrics()).data,
  })

  return (
    <section>
      <h1 className="text-2xl font-bold tracking-tight">Metrics</h1>
      <p className="mt-2 text-muted-foreground">{data.message}</p>
    </section>
  )
}
