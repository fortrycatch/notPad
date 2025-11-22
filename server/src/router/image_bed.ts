import { router, publicPro, needAuth } from '../trpc/trpc.js';
import { z } from 'zod';
import { getInfo, getUploadUrl,list,test } from '../utils/aliOss.js';
import { TRPCError } from '@trpc/server';
import { imageData } from '../utils/sqlData.js';
function mimeToExtension(mime:string){
    const table = {
        'image/jpeg': '.jpg',
        'image/png': '.png',
        'image/webp': '.webp',
        'image/avif': '.avif',
        'image/svg+xml': '.svg',
        'image/gif': '.gif',
        'image/bmp': '.bmp',
        'image/tiff': '.tiff',
    }
    return table[mime] || '.png'
}
export default router({
    getUploadUrl: needAuth.input(z.object({
        filename: z.string(),
        type: z.string()
    })).query(async ({ input,ctx }) => {
        const type = input.type.split('/')
        if(type[0] !== 'image'){
            throw new TRPCError({ code: 'BAD_REQUEST', message: '类型错误' });
        }
        const res =  await getUploadUrl(ctx.user_id,mimeToExtension(input.type),input.type);
        return res
    }),
    addImage: needAuth.input(z.object({
        name: z.string(),
        filename: z.string(),
        remark: z.string()
    })).mutation(async ({ input,ctx }) => {
        const info = await getInfo(input.filename)
        if(!info){
            throw new TRPCError({ code: 'BAD_REQUEST', message: '图片不存在' });
        }
        console.log(info)
        return await imageData.addImage(input.name,input.filename, info.res.headers['content-length'],ctx.user_id, input.remark);
    }),
    test: needAuth.query(async () => {
        return await test();
    }),
    list: needAuth.input(z.object({
        user_id: z.string(),
        offset: z.number(),
        sort: z.enum(['time', 'time_desc', 'name']).optional(),
        search: z.string().optional()
    })).query(async ({ input,ctx }) => {
        // return await list(input);
        input.search = input.search || ''
        return await imageData.getImageList(ctx.user_id,input.offset,input.sort || 'time_desc',input.search)
    }),
})