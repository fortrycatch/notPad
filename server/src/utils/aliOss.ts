import OSS from 'ali-oss';
import config from '../config.js';
import { generateUserCode, getUUID } from './userCode.js';

export type OssPathKey = keyof typeof config.aliOss.paths;

const publicHost = config.aliOss.publicHost.replace(/\/$/, '');
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

export function getObjectPrefix(pathKey: OssPathKey) {
    return config.aliOss.paths[pathKey];
}

export function getPublicUrl(filename: string) {
    return `${publicHost}/${filename}`;
}

export async function list(userId: string, pathKey: OssPathKey = 'image') {
    const res = await aliOss.list({
        prefix: getObjectPrefix(pathKey) + '/' + generateUserCode(userId),
    })
    // console.log(res)
    return res.objects
}

export async function getUploadUrl(
    userId: string,
    pathKey: OssPathKey,
    suffix: string,
    type: string
) {
    const filename = getObjectPrefix(pathKey) + '/' + generateUserCode(userId) + "-" + Date.now() + "-" + getUUID() + suffix
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