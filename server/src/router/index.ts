import { router, publicPro, needAuth } from '../trpc/trpc.js';
import { z } from 'zod';
import auth from './auth.js';
import notepad from './notepad.js';
import image_bed from './image_bed.js';
const appRouter = router({
    hello: publicPro.input(z.string()).query(({ input }) => {
        return `Hello, ${input}!`
    }),
    hello2: needAuth.input(z.string()).query(({ input }) => {
        return `Hello, ${input}!`
    }),
    auth,
    notepad,
    image_bed,
})
export default appRouter;
export type AppRouter = typeof appRouter;