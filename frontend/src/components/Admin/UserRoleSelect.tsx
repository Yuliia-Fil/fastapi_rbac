import type { ComponentProps } from "react"
import { z } from "zod"
import type { UserRole } from "@/client"
import { cn } from "@/lib/utils"

export const roleLabels = {
  admin: "Admin",
  manager: "Manager",
  member: "Member",
} satisfies Record<UserRole, string>

const roles = Object.keys(roleLabels) as UserRole[]
export const userRoleSchema = z.enum(roles)

export function UserRoleSelect({
  className,
  ...props
}: ComponentProps<"select">) {
  return (
    <select
      className={cn(
        "h-9 w-full rounded-md border border-input bg-background px-3 text-sm focus-visible:ring-2 focus-visible:ring-ring",
        className,
      )}
      {...props}
    >
      {roles.map((role) => (
        <option key={role} value={role}>
          {roleLabels[role]}
        </option>
      ))}
    </select>
  )
}
