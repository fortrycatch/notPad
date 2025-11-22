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
    })).mutation(async ({ input }) => {
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
            const token = await tokenData.createToken(user.id);
            
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
    })).mutation(async ({ input }) => {
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
            const token = await tokenData.createToken(user.id);
            
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
})