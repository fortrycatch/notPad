import type { CreateHTTPContextOptions } from "@trpc/server/adapters/standalone";
import { basicData } from "./basicData";
async function auth(opts: CreateHTTPContextOptions) {
    const { req } = opts;
    const token = req.headers.token == basicData.token;
    if (!token) {
        return false;
    }
    return true;
}

export { auth };