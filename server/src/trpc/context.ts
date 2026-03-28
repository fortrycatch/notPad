import type { CreateExpressContextOptions } from '@trpc/server/adapters/express'
import { auth } from '../solt.js'

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
            userAgent
        }
    }
    return {
        authenticated: authContext.ok,
        user_id: authContext.user_id,
        userAgent
    }
}

export type Context = Awaited<ReturnType<typeof createContext>>;
export { createContext };