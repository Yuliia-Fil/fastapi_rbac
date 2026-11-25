import type { Capability, CurrentUserPublic } from "@/client"

export class AccessDeniedError extends Error {}

export function hasCapability(
  user: CurrentUserPublic | undefined,
  capability: Capability,
) {
  return user?.capabilities.includes(capability) ?? false
}

export function requireCapability(
  user: CurrentUserPublic,
  capability: Capability,
) {
  if (!hasCapability(user, capability)) {
    throw new AccessDeniedError()
  }
}
