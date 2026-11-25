import { useSuspenseQuery } from "@tanstack/react-query"
import { createFileRoute } from "@tanstack/react-router"
import { Suspense } from "react"

import { type UserPublic, UsersService } from "@/client"
import AddUser from "@/components/Admin/AddUser"
import { columns, type UserTableData } from "@/components/Admin/columns"
import { ProtectedRouteError } from "@/components/Common/AccessDenied"
import { DataTable } from "@/components/Common/DataTable"
import PendingUsers from "@/components/Pending/PendingUsers"
import useAuth from "@/hooks/useAuth"
import { hasCapability, requireCapability } from "@/lib/permissions"

const readOnlyColumns = columns.filter((column) => column.id !== "actions")

function getUsersQueryOptions() {
  return {
    queryFn: async () =>
      (await UsersService.readUsers({ query: { skip: 0, limit: 100 } })).data,
    queryKey: ["users"],
  }
}

export const Route = createFileRoute("/_layout/admin")({
  component: Admin,
  errorComponent: ProtectedRouteError,
  beforeLoad: ({ context }) => {
    requireCapability(context.currentUser, "list_users")
  },
  head: () => ({
    meta: [
      {
        title: "Users - FastAPI Template",
      },
    ],
  }),
})

function UsersTableContent() {
  const { user: currentUser } = useAuth()
  const { data: users } = useSuspenseQuery(getUsersQueryOptions())

  const tableData: UserTableData[] = users.data.map((user: UserPublic) => ({
    ...user,
    isCurrentUser: currentUser?.id === user.id,
  }))

  const canManageUsers =
    hasCapability(currentUser, "update_any_user") ||
    hasCapability(currentUser, "delete_any_user")
  return (
    <DataTable
      columns={canManageUsers ? columns : readOnlyColumns}
      data={tableData}
    />
  )
}

function UsersTable() {
  return (
    <Suspense fallback={<PendingUsers />}>
      <UsersTableContent />
    </Suspense>
  )
}

function Admin() {
  const { user } = useAuth()
  const { currentUser } = Route.useRouteContext()
  const viewer = user ?? currentUser
  requireCapability(viewer, "list_users")
  const canCreateUser = hasCapability(viewer, "create_user")

  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Users</h1>
          <p className="text-muted-foreground">
            {canCreateUser
              ? "Manage user accounts and permissions"
              : "View user accounts and roles"}
          </p>
        </div>
        {canCreateUser && <AddUser />}
      </div>
      <UsersTable />
    </div>
  )
}
