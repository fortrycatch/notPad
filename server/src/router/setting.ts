import { router, needAuth } from '../trpc/trpc.js';
import { z } from 'zod';
import { settingData, usageStatsData } from '../utils/sqlData.js';

export default router({
    getAll: needAuth.query(async ({ ctx }) => {
        return await settingData.getAll(ctx.user_id!)
    }),
    set: needAuth
        .input(z.object({ key: z.string().min(1).max(128), value: z.string() }))
        .mutation(async ({ ctx, input }) => {
            await settingData.set(ctx.user_id!, input.key, input.value)
            return { success: true }
        }),
    remove: needAuth
        .input(z.object({ key: z.string().min(1).max(128) }))
        .mutation(async ({ ctx, input }) => {
            return { success: await settingData.remove(ctx.user_id!, input.key) }
        }),
    getUsageStats: needAuth.query(async ({ ctx }) => {
        return await usageStatsData.get(ctx.user_id!, ctx.group_id)
    }),
    recalculateStats: needAuth.mutation(async ({ ctx }) => {
        return await usageStatsData.recalculate(ctx.user_id!, ctx.group_id)
    }),
})
