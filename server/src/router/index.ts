import { router, publicPro, needAuth } from '../trpc/trpc.js';
import { z } from 'zod';
import auth from './auth.js';
import notepad from './notepad.js';
import image_bed from './image_bed.js';
import file_drive from './file_drive.js';
import bookmark from './bookmark.js';
import setting from './setting.js';
import group from './group.js';
import groupChat from './groupChat.js';
import { timelineData } from '../utils/sqlData.js';
const appRouter = router({
    hello: publicPro.input(z.string()).query(({ input }) => {
        return `Hello, ${input}!`
    }),
    hello2: needAuth.input(z.string()).query(({ input }) => {
        return `Hello, ${input}!`
    }),
    timeline: needAuth.input(z.number().int().min(0)).query(async ({ input, ctx }) => {
        return await timelineData.getTimeline(ctx.user_id!, ctx.group_id, input)
    }),
    auth,
    notepad,
    image_bed,
    file_drive,
    bookmark,
    setting,
    group,
    groupChat,
})
export default appRouter;
export type AppRouter = typeof appRouter;