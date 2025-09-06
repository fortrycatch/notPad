import { basicData } from '../basicData.js';
import { router, publicPro, needAuth } from '../trpc/trpc.js';
import { z } from 'zod';
export default router({
    login: publicPro.input(z.object({
        username: z.string(),
        password: z.string()
    })).mutation(({ input }) => {
        if(input.username === 'admin' && input.password === '123456') {
            let token = Math.random().toString(36).substring(2, 15);
            basicData.token = token
            return {
                success: true,
                token
            }
        } else {
            return {
                success: false,
                token: null
            }
        }
    }),
    verifyToken: publicPro.input(z.string()).query(async ({ input }) => {
        return input == basicData.token;
    }),
})