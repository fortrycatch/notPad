import { EventEmitter } from 'node:events'

const bus = new EventEmitter()
bus.setMaxListeners(500)

function channel(groupId: string) {
  return `groupChat:${groupId}`
}

export type GroupChatClientMessage = {
  id: string
  group_id: string
  user_id: string
  user_name: string
  user_avatar: string
  content: string
  created_at: string
}

export function publishGroupChatMessage(groupId: string, message: GroupChatClientMessage) {
  bus.emit(channel(groupId), message)
}

export function subscribeGroupChat(groupId: string, handler: (message: GroupChatClientMessage) => void) {
  const ch = channel(groupId)
  const fn = (message: GroupChatClientMessage) => handler(message)
  bus.on(ch, fn)
  return () => {
    bus.off(ch, fn)
  }
}
