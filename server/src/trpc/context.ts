import type { CreateHTTPContextOptions } from "@trpc/server/adapters/standalone";
import { auth } from '../solt.js';
async function createContext(opts: CreateHTTPContextOptions) {
    const authContext = await auth(opts);
    if(!authContext.ok){
        return {
            "authenticated": false,
            "user_id": null
        }
    }else{
        return {
            "authenticated": authContext.ok,
            "user_id": authContext.user_id
        }
    }
}

export type Context = Awaited<ReturnType<typeof createContext>>;
export { createContext };