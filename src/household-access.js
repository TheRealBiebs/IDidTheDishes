// `owner` is the existing database/API value for a household admin.
export const isHouseholdAdmin = member => member?.role === 'owner'
export const adminCount = members => members.filter(isHouseholdAdmin).length
export const canRemoveAdmin = (member, members) => !isHouseholdAdmin(member) || adminCount(members) > 1
