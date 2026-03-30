import { router, needAuth } from '../trpc/trpc.js'
import { z } from 'zod'
import { groupData, groupMemberData, groupInviteData, userData } from '../utils/sqlData.js'
import crypto from 'node:crypto'
import { TRPCError } from '@trpc/server'

const roleOrder = { owner: 0, admin: 1, editor: 2, viewer: 3 } as const
type Role = keyof typeof roleOrder

function assertRole(actual: string | null, minRole: Role) {
  if (!actual || roleOrder[actual as Role] === undefined || roleOrder[actual as Role] > roleOrder[minRole])
    throw new TRPCError({ code: 'FORBIDDEN', message: '权限不足' })
}

export default router({
  create: needAuth.input(z.object({
    name: z.string().min(1).max(255),
    description: z.string().max(2000).default(''),
  })).mutation(async ({ ctx, input }) => {
    const id = crypto.randomUUID()
    const group = await groupData.create(id, input.name, input.description, ctx.user_id!)
    await groupMemberData.add(id, ctx.user_id!, 'owner')
    return group
  }),

  list: needAuth.query(async ({ ctx }) => {
    return await groupData.listByUser(ctx.user_id!)
  }),

  getById: needAuth.input(z.string()).query(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input, ctx.user_id!)
    if (!membership) throw new TRPCError({ code: 'FORBIDDEN', message: '非群组成员' })
    const group = await groupData.getById(input)
    const meta = await groupData.getMeta(input)
    return { ...group, role: membership.role, meta }
  }),

  update: needAuth.input(z.object({
    groupId: z.string(),
    name: z.string().min(1).max(255),
    description: z.string().max(2000).default(''),
  })).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    await groupData.update(input.groupId, input.name, input.description)
    return await groupData.getById(input.groupId)
  }),

  updateMeta: needAuth.input(z.object({
    groupId: z.string(),
    meta: z.record(z.string(), z.unknown()),
  })).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    const existing = await groupData.getMeta(input.groupId)
    await groupData.updateMeta(input.groupId, { ...existing, ...input.meta })
    return await groupData.getMeta(input.groupId)
  }),

  delete: needAuth.input(z.string()).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input, ctx.user_id!)
    assertRole(membership?.role ?? null, 'owner')
    return await groupData.remove(input)
  }),

  listMembers: needAuth.input(z.string()).query(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input, ctx.user_id!)
    if (!membership) throw new TRPCError({ code: 'FORBIDDEN', message: '非群组成员' })
    return await groupMemberData.listMembers(input)
  }),

  inviteUser: needAuth.input(z.object({
    groupId: z.string(),
    userId: z.string(),
    role: z.enum(['admin', 'editor', 'viewer']).default('editor'),
  })).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    const target = await userData.getUserById(input.userId)
    if (!target) throw new TRPCError({ code: 'NOT_FOUND', message: '用户不存在' })
    const existing = await groupMemberData.getMembership(input.groupId, input.userId)
    if (existing) throw new TRPCError({ code: 'CONFLICT', message: '该用户已是群组成员' })
    const id = crypto.randomUUID()
    return await groupInviteData.createDirectInvite(id, input.groupId, input.userId, input.role, ctx.user_id!)
  }),

  createInviteLink: needAuth.input(z.object({
    groupId: z.string(),
    role: z.enum(['admin', 'editor', 'viewer']).default('editor'),
    expiresInHours: z.number().positive().nullable().default(null),
  })).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    const id = crypto.randomUUID()
    const inviteCode = crypto.randomBytes(16).toString('base64url')
    const expiresAt = input.expiresInHours
      ? new Date(Date.now() + input.expiresInHours * 3600_000)
      : null
    return await groupInviteData.createLinkInvite(id, input.groupId, inviteCode, input.role, ctx.user_id!, expiresAt)
  }),

  acceptInvite: needAuth.input(z.object({
    inviteCode: z.string().optional(),
    inviteId: z.string().optional(),
  })).mutation(async ({ ctx, input }) => {
    let invite: Awaited<ReturnType<typeof groupInviteData.getByCode>> = null

    if (input.inviteCode) {
      invite = await groupInviteData.getByCode(input.inviteCode)
    } else if (input.inviteId) {
      invite = await groupInviteData.getDirectInvite('', ctx.user_id!)
      const [rows] = await (await import('../database.js')).pool.execute<any[]>(
        'SELECT * FROM group_invites WHERE id = ? AND invited_user_id = ? AND used_at IS NULL',
        [input.inviteId, ctx.user_id!]
      )
      invite = rows[0] ?? null
    }

    if (!invite) throw new TRPCError({ code: 'NOT_FOUND', message: '邀请不存在或已失效' })
    if (invite.expires_at && new Date(invite.expires_at) < new Date())
      throw new TRPCError({ code: 'BAD_REQUEST', message: '邀请已过期' })
    if (invite.invited_user_id && invite.invited_user_id !== ctx.user_id!)
      throw new TRPCError({ code: 'FORBIDDEN', message: '该邀请不属于你' })

    const existing = await groupMemberData.getMembership(invite.group_id, ctx.user_id!)
    if (existing) throw new TRPCError({ code: 'CONFLICT', message: '你已经是群组成员' })

    await groupMemberData.add(invite.group_id, ctx.user_id!, invite.role)
    if (invite.invited_user_id) await groupInviteData.markUsed(invite.id)
    return await groupData.getById(invite.group_id)
  }),

  getInviteInfo: needAuth.input(z.string()).query(async ({ input }) => {
    const invite = await groupInviteData.getByCode(input)
    if (!invite) throw new TRPCError({ code: 'NOT_FOUND', message: '邀请不存在或已失效' })
    if (invite.expires_at && new Date(invite.expires_at) < new Date())
      throw new TRPCError({ code: 'BAD_REQUEST', message: '邀请已过期' })
    const group = await groupData.getById(invite.group_id)
    return { groupName: group?.name, groupId: invite.group_id, role: invite.role }
  }),

  listPendingInvites: needAuth.input(z.string()).query(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    return await groupInviteData.listPending(input)
  }),

  listInviteCodes: needAuth.input(z.string()).query(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    return await groupInviteData.listLinkInvites(input)
  }),

  myInvites: needAuth.query(async ({ ctx }) => {
    return await groupInviteData.listForUser(ctx.user_id!)
  }),

  removeInvite: needAuth.input(z.string()).mutation(async ({ ctx, input }) => {
    const invite = await groupInviteData.getById(input)
    if (!invite) throw new TRPCError({ code: 'NOT_FOUND', message: '邀请不存在' })
    const membership = await groupMemberData.getMembership(invite.group_id, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    return await groupInviteData.remove(input)
  }),

  removeMember: needAuth.input(z.object({
    groupId: z.string(),
    userId: z.string(),
  })).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    const target = await groupMemberData.getMembership(input.groupId, input.userId)
    if (!target) throw new TRPCError({ code: 'NOT_FOUND', message: '该用户不是群组成员' })
    if (target.role === 'owner') throw new TRPCError({ code: 'FORBIDDEN', message: '不能移除群组所有者' })
    return await groupMemberData.remove(input.groupId, input.userId)
  }),

  updateMemberRole: needAuth.input(z.object({
    groupId: z.string(),
    userId: z.string(),
    role: z.enum(['admin', 'editor', 'viewer']),
  })).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    assertRole(membership?.role ?? null, 'admin')
    const target = await groupMemberData.getMembership(input.groupId, input.userId)
    if (!target) throw new TRPCError({ code: 'NOT_FOUND', message: '该用户不是群组成员' })
    if (target.role === 'owner') throw new TRPCError({ code: 'FORBIDDEN', message: '不能修改所有者角色' })
    return await groupMemberData.updateRole(input.groupId, input.userId, input.role)
  }),

  leave: needAuth.input(z.string()).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input, ctx.user_id!)
    if (!membership) throw new TRPCError({ code: 'NOT_FOUND', message: '你不是群组成员' })
    if (membership.role === 'owner')
      throw new TRPCError({ code: 'FORBIDDEN', message: '所有者不能离开群组，请先转移所有权' })
    return await groupMemberData.remove(input, ctx.user_id!)
  }),

  transferOwnership: needAuth.input(z.object({
    groupId: z.string(),
    newOwnerId: z.string(),
  })).mutation(async ({ ctx, input }) => {
    const membership = await groupMemberData.getMembership(input.groupId, ctx.user_id!)
    assertRole(membership?.role ?? null, 'owner')
    const target = await groupMemberData.getMembership(input.groupId, input.newOwnerId)
    if (!target) throw new TRPCError({ code: 'NOT_FOUND', message: '目标用户不是群组成员' })
    await groupMemberData.updateRole(input.groupId, input.newOwnerId, 'owner')
    await groupMemberData.updateRole(input.groupId, ctx.user_id!, 'admin')
    return true
  }),
})
