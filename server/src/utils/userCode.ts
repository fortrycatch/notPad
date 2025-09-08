import crypto from 'node:crypto'
export function generateUserCode(name:string) {
    return crypto.hash('sha1',name).slice(0,10)
}
export function getUUID(){
    return crypto.randomUUID()
}