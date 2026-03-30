import { initTRPC , TRPCError } from '@trpc/server';
import type { Context } from './context.js';

const t = initTRPC.context<Context>().create();

const needAuth = t.procedure.use(async ({ ctx, next }) => {
    if (!ctx.authenticated) {
        throw new TRPCError({ code: 'UNAUTHORIZED' });
    }
    return next({ ctx });
})

const needGroupEditor = needAuth.use(async ({ ctx, next }) => {
    if (ctx.group_id && !['owner', 'admin', 'editor'].includes(ctx.group_role!))
        throw new TRPCError({ code: 'FORBIDDEN' });
    return next({ ctx });
})

const needGroupAdmin = needAuth.use(async ({ ctx, next }) => {
    if (ctx.group_id && !['owner', 'admin'].includes(ctx.group_role!))
        throw new TRPCError({ code: 'FORBIDDEN' });
    return next({ ctx });
})

export const router = t.router;
export const publicPro = t.procedure;
export { needAuth, needGroupEditor, needGroupAdmin }