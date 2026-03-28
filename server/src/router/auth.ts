import { router, publicPro, needAuth } from '../trpc/trpc.js';
import { z } from 'zod';
import { userData, tokenData } from '../utils/sqlData.js';
import { getUUID } from '../utils/userCode.js';
import crypto from 'node:crypto';

// 验证密码
function verifyPassword(password: string, hashedPassword: string): boolean {
    const hash = crypto.createHash('sha256').update(password).update("yuanshen").digest('hex');
    return hash === hashedPassword;
}

export default router({
    register: publicPro.input(z.object({
        user_id: z.string().min(1, '用户ID不能为空'),
        name: z.string().min(1, '昵称不能为空'),
        email: z.string().email('邮箱格式不正确'),
        password: z.string().min(6, '密码长度至少6位')
    })).mutation(async ({ input, ctx }) => {
        try {
            // 检查用户ID是否已被注册
            const existingUserById = await userData.getUserById(input.user_id);
            if (existingUserById) {
                return {
                    success: false,
                    message: '该用户ID已被注册'
                };
            }
            
            // 检查邮箱是否已被注册
            const existingUserByEmail = await userData.getUserByEmail(input.email);
            if (existingUserByEmail) {
                return {
                    success: false,
                    message: '该邮箱已被注册'
                };
            }
            
            // name是昵称，可以重复，不需要检查
            
            // 创建用户（使用用户提供的user_id）
            const user = await userData.createUser(
                input.user_id,
                input.name,
                input.email,
                input.password
            );
            
            if (!user) {
                return {
                    success: false,
                    message: '注册失败，请稍后重试'
                };
            }
            
            // 自动登录：创建token
            const token = await tokenData.createToken(user.id, ctx.userAgent);
            
            return {
                success: true,
                token,
                user: {
                    id: user.id,
                    name: user.name,
                    email: user.email
                },
                message: '注册成功'
            };
        } catch (error: any) {
            console.error('注册失败:', error);
            return {
                success: false,
                message: error.message || '注册失败，请稍后重试'
            };
        }
    }),
    login: publicPro.input(z.object({
        username: z.string(),
        password: z.string()
    })).mutation(async ({ input, ctx }) => {
        try {
            // 先尝试通过用户ID查找用户
            let user = await userData.getUserById(input.username);
            
            // 如果没找到，再尝试通过邮箱查找
            if (!user) {
                user = await userData.getUserByEmail(input.username);
            }
            
            // 如果用户不存在，返回失败
            if (!user) {
                return {
                    success: false,
                    token: null,
                    message: '用户ID/邮箱或密码错误'
                };
            }
            
            // 验证密码
            if (!verifyPassword(input.password, user.password)) {
                return {
                    success: false,
                    token: null,
                    message: '用户ID/邮箱或密码错误'
                };
            }
            
            // 创建token
            const token = await tokenData.createToken(user.id, ctx.userAgent);
            
            return {
                success: true,
                token,
                user: {
                    id: user.id,
                    name: user.name,
                    email: user.email
                }
            };
        } catch (error) {
            console.error('登录失败:', error);
            return {
                success: false,
                token: null,
                message: '登录失败，请稍后重试'
            };
        }
    }),
    verifyToken: publicPro.input(z.string()).query(async ({ input }) => {
        try {
            const result = await tokenData.verifyToken(input);
            return result.ok;
        } catch (error) {
            console.error('验证token失败:', error);
            return false;
        }
    }),
    getProfile: needAuth.query(async ({ ctx }) => {
        const user = await userData.getUserById(ctx.user_id!);
        if (!user) throw new Error('用户不存在');
        return {
            id: user.id,
            name: user.name,
            email: user.email
        };
    }),
    updateProfile: needAuth.input(z.object({
        name: z.string().min(1, '昵称不能为空'),
        email: z.string().email('邮箱格式不正确'),
        password: z.string().optional()
    })).mutation(async ({ ctx, input }) => {
        const user = await userData.getUserById(ctx.user_id!);
        if (!user) throw new Error('用户不存在');

        let newPassword = user.password;
        if (input.password && input.password.length > 0) {
            if (input.password.length < 6) {
                 throw new Error('密码长度至少6位');
            }
            newPassword = crypto.createHash('sha256').update(input.password).update("yuanshen").digest('hex');
        }

        const updatedUser = await userData.updateUser(
            user.id,
            input.name,
            input.email,
            newPassword
        );
        
        return {
            success: true,
            user: {
                id: updatedUser?.id,
                name: updatedUser?.name,
                email: updatedUser?.email
            }
        };
    }),
    getTokens: needAuth.query(async ({ ctx }) => {
        const tokens = await tokenData.getTokenByUserId(ctx.user_id!);
        return tokens
            ? tokens.map((t) => ({
                  token: t.token,
                  created_at: t.created_at,
                  used_at: t.used_at,
                  user_agent: t.user_agent ?? null,
                  alias: t.alias ?? null
              }))
            : [];
    }),
    setTokenAlias: needAuth
        .input(
            z.object({
                tokenHash: z.string().min(1),
                alias: z.string().max(128).optional()
            })
        )
        .mutation(async ({ ctx, input }) => {
            const alias =
                input.alias === undefined || input.alias.trim() === ''
                    ? null
                    : input.alias.trim();
            const ok = await tokenData.updateTokenAlias(
                ctx.user_id!,
                input.tokenHash,
                alias
            );
            if (!ok) throw new Error('Token不存在或无权操作');
            return { success: true };
        }),
    revokeToken: needAuth.input(z.object({
        tokenHash: z.string()
    })).mutation(async ({ ctx, input }) => {
        const tokens = await tokenData.getTokenByUserId(ctx.user_id!);
        const targetToken = tokens?.find(t => t.token === input.tokenHash);
        
        if (!targetToken) {
            throw new Error('Token不存在或无权操作');
        }
        
        return await tokenData.deleteTokenByHash(input.tokenHash);
    }),
})