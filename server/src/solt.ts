import type { CreateHTTPContextOptions } from "@trpc/server/adapters/standalone";
import { tokenData } from "./utils/sqlData.js";

async function auth(opts: CreateHTTPContextOptions): Promise<{ok: boolean, user_id: string | null}> {
    try {
        const { req } = opts;
        const token = req.headers.token as string | undefined;
        
        if (!token || typeof token !== 'string') {
            return {
                ok: false,
                user_id: null
            };
        }
        
        const result = await tokenData.verifyToken(token);
        if(!result.ok){
            return result;
        }
        return result;
    } catch (error) {
        console.error('认证失败:', error);
        return {
            ok: false,
            user_id: null
        };
    }
}

export { auth };