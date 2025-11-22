import OSS from 'ali-oss';
import config from '../config.js';
const path = config.aliOss.path;
import { generateUserCode, getUUID } from './userCode.js';
export const aliOss = new OSS({
    accessKeyId: config.aliOss.accessKeyId,
    accessKeySecret: config.aliOss.accessKeySecret,
    endpoint: config.aliOss.endpoint,
    bucket: config.aliOss.bucket,
    region: config.aliOss.region,
    authorizationV4: true
} as any)

export async function test() {
    return await aliOss.list()
}
export async function list(userId: string) {
    const res = await aliOss.list({
        prefix: path + '/' + generateUserCode(userId),
    })
    // console.log(res)
    return res.objects
}
export async function getUploadUrl(userId: string, filename: string, type: string) {
    filename = path + '/' + generateUserCode(userId) + "-" + Date.now() + "-" + getUUID() + filename
    const url = await aliOss.signatureUrlV4('PUT', 3600, {
        headers: {
            'content-type': type
        }
    }, filename)
    return {
        url,
        filename
    }
}

export async function getInfo(filename: string) {
    try {
        const res = await aliOss.head(filename)
        return res
    } catch (error) {
        return null
    }
}