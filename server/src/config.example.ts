export default {
    port: 4000,
    db: {
        host: 'localhost',
        port: 3306,
        user: 'root',
        password: '',
        database: 'notpad',
    },
    aliOss: {
        accessKeyId: '',
        accessKeySecret: '',
        endpoint: 'https://oss-cn-beijing.aliyuncs.com',
        region: 'cn-beijing',
        bucket: '',
        publicHost: '',
        paths: {
            image: 'image_bed',
            file: 'file'
        }
    },
    /** Jina Reader (r.jina.ai)，用于书签抓取网页标题与摘要 */
    jina: {
        apiKey: ''
    }
};
