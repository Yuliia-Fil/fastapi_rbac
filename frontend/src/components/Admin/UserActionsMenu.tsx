import { EllipsisVertical } from "lucide-react"
import { useState } from "react"

import type { UserPublic } from "@/client"
import { Button } from "@/components/ui/button"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import useAuth from "@/hooks/useAuth"
import { hasCapability } from "@/lib/permissions"
import DeleteUser from "./DeleteUser"
import EditUser from "./EditUser"

interface UserActionsMenuProps {
  user: UserPublic
}

export const UserActionsMenu = ({ user }: UserActionsMenuProps) => {
  const [open, setOpen] = useState(false)
  const { user: currentUser } = useAuth()
  const canEdit = hasCapability(currentUser, "update_any_user")
  const canDelete =
    hasCapability(currentUser, "delete_any_user") && user.id !== currentUser?.id

  if (!canEdit && !canDelete) {
    return null
  }

  return (
    <DropdownMenu open={open} onOpenChange={setOpen}>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon">
          <EllipsisVertical />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {canEdit && <EditUser user={user} onSuccess={() => setOpen(false)} />}
        {canDelete && (
          <DeleteUser id={user.id} onSuccess={() => setOpen(false)} />
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
