import type { CreateExpressContextOptions } from '@trpc/server/adapters/express'
import { auth } from '../solt.js'
import { groupMemberData } from '../utils/sqlData.js'

function readUserAgent(req: CreateExpressContextOptions['req']): string | null {
    const raw = req.headers['user-agent']
    if (typeof raw !== 'string' || raw.length === 0) return null
    return raw.length > 512 ? raw.slice(0, 512) : raw
}

async function createContext(opts: CreateExpressContextOptions) {
    const userAgent = readUserAgent(opts.req)
    const authContext = await auth(opts)
    if (!authContext.ok) {
        return {
            authenticated: false,
            user_id: null,
            userAgent,
            group_id: null as string | null,
            group_role: null as string | null,
        }
    }

    let group_id: string | null = null
    let group_role: string | null = null
    const rawGroupId = opts.req.headers['x-group-id']
    if (typeof rawGroupId === 'string' && rawGroupId.length > 0) {
        const membership = await groupMemberData.getMembership(rawGroupId, authContext.user_id!)
        if (membership) {
            group_id = rawGroupId
            group_role = membership.role
        }
    }

    return {
        authenticated: authContext.ok,
        user_id: authContext.user_id,
        userAgent,
        group_id,
        group_role,
    }
}

export type Context = Awaited<ReturnType<typeof createContext>>;
export { createContext };