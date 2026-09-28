/** Lowercased username stored as usersv2.usernameLower for case-insensitive search. */
export function usernameLowerOf(username: unknown): string {
  return typeof username === "string" ? username.trim().toLowerCase() : "";
}
