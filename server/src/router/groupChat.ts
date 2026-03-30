import { router, needAuth } from '../trpc/trpc.js'
import { z } from 'zod'
import { groupMemberData, groupChatData, type GroupChatMessageWithAvatar } from '../utils/sqlData.js'
import { TRPCError } from '@trpc/server'
import crypto from 'node:crypto'
import { publishGroupChatMessage, type GroupChatClientMessage } from '../groupChatBus.js'

const roleOrder = { owner: 0, admin: 1, editor: 2, viewer: 3 } as const
type Role = keyof typeof roleOrder

function assertCanPost(role: string | null) {
  if (!role || roleOrder[role as Role] === undefined || roleOrder[role as Role] > roleOrder.editor)
    throw new TRPCError({ code: 'FORBIDDEN', message: '只读成员不能发言' })
}

function rowToClient(row: GroupChatMessageWithAvatar): GroupChatClientMessage {
  const d = row.created_at
  return {
    id: row.id,
    group_id: row.group_id,
    user_id: row.user_id,
    user_name: row.user_name ?? '',
    user_avatar: row.user_avatar,
    content: row.content,
    created_at: d instanceof Date ? d.toISOString() : String(d),
  }
}

export default router({
  list: needAuth.input(z.object({
    groupId: z.string(),
    beforeId: z.string().nullable().optional(),
    limit: z.number().int().min(1).max(100).default(50),
  })).query(async ({ ctx, input }) => {
    const m = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    if (!m) throw new TRPCError({ code: 'FORBIDDEN', message: '非群组成员' })
    const rows = await groupChatData.list(input.groupId, {
      beforeId: input.beforeId ?? null,
      limit: input.limit,
    })
    return rows.map(rowToClient)
  }),

  send: needAuth.input(z.object({
    groupId: z.string(),
    content: z.string().min(1).max(4000),
  })).mutation(async ({ ctx, input }) => {
    const m = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    if (!m) throw new TRPCError({ code: 'FORBIDDEN', message: '非群组成员' })
    assertCanPost(m.role)
    const id = crypto.randomUUID()
    const row = await groupChatData.insert(id, input.groupId, ctx.user_id!, input.content.trim())
    const payload = rowToClient(row)
    publishGroupChatMessage(input.groupId, payload)
    return payload
  }),
})
