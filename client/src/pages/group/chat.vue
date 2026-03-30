<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted, nextTick, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useMainStore } from '../../store/mainStore';
import { server } from '../../server';

type ChatMsg = {
  id: string;
  group_id: string;
  user_id: string;
  user_name: string;
  user_avatar?: string;
  content: string;
  created_at: string;
};

const IMAGE_HOST = 'https://monika.jkloli.net/';

function avatarThumb(url: string | undefined) {
  const u = (url || '').trim();
  if (!u) return '';
  const full = u.startsWith('http') ? u : IMAGE_HOST + u;
  const sep = full.includes('?') ? '&' : '?';
  return `${full}${sep}x-oss-process=image/resize,w_80`;
}

const mainStore = useMainStore();
const router = useRouter();
const messages = ref<ChatMsg[]>([]);
const loading = ref(true);
const sending = ref(false);
const draft = ref('');
const listEl = ref<HTMLElement | null>(null);
let es: EventSource | null = null;

const groupId = computed(() => mainStore.activeGroupId);

const canPost = computed(() => {
  const r = mainStore.activeGroup?.role;
  return Boolean(r && ['owner', 'admin', 'editor'].includes(r));
});

function streamUrl() {
  const base = import.meta.env.DEV ? 'http://localhost:4000' : '';
  const q = new URLSearchParams({ groupId: groupId.value!, token: mainStore.token });
  return `${base}/api/group-chat/stream?${q}`;
}

function mergeIncoming(msg: ChatMsg) {
  if (messages.value.some(m => m.id === msg.id)) return;
  messages.value.push({ ...msg, user_avatar: msg.user_avatar ?? '' });
  void scrollBottom();
}

async function scrollBottom() {
  await nextTick();
  const el = listEl.value;
  if (el) el.scrollTop = el.scrollHeight;
}

async function load() {
  const gid = groupId.value;
  if (!gid) return;
  loading.value = true;
  try {
    messages.value = await server.groupChat.list.query({ groupId: gid, limit: 80 });
    await scrollBottom();
  } finally {
    loading.value = false;
  }
}

function connectEs() {
  es?.close();
  es = null;
  const gid = groupId.value;
  if (!gid || !mainStore.token) return;
  const source = new EventSource(streamUrl());
  es = source;
  source.onmessage = (ev) => {
    try {
      const data = JSON.parse(ev.data) as { type: string; message?: ChatMsg };
      if (data.type === 'message' && data.message) mergeIncoming(data.message);
    } catch { /* ignore */ }
  };
}

async function send() {
  const gid = groupId.value;
  const t = draft.value.trim();
  if (!gid || !t || sending.value || !canPost.value) return;
  sending.value = true;
  try {
    const msg = await server.groupChat.send.mutate({ groupId: gid, content: t });
    draft.value = '';
    mergeIncoming(msg);
  } finally {
    sending.value = false;
  }
}

watch(groupId, () => {
  void load();
  connectEs();
});

onMounted(() => {
  if (!mainStore.activeGroupId) {
    router.replace('/group');
    return;
  }
  void load();
  connectEs();
});

onUnmounted(() => {
  es?.close();
});
</script>

<template>
  <div class="group-chat">
    <!-- <header class="channel-header d-flex align-center ga-2">
      <v-icon size="22" color="medium-emphasis">mdi-pound</v-icon>
      <span class="text-subtitle-1 font-weight-semibold">群聊</span>
    </header> -->

    <div ref="listEl" class="messages">
      <div v-if="loading" class="messages-loading text-medium-emphasis">加载中…</div>
      <div v-else class="messages-stack">
        <div v-if="messages.length === 0" class="empty-hint text-medium-emphasis">
          暂无消息，说点什么吧
        </div>
        <div
          v-for="m in messages"
          :key="m.id"
          class="chat-row d-flex ga-3 align-start"
        >
          <v-avatar size="40" color="primary" variant="tonal" class="flex-shrink-0 mt-0">
            <v-img v-if="m.user_avatar" :src="avatarThumb(m.user_avatar)" cover />
            <v-icon v-else size="22">mdi-account</v-icon>
          </v-avatar>
          <div class="chat-body flex-grow-1 min-w-0">
            <div class="chat-meta text-caption text-medium-emphasis">
              <span class="font-weight-medium text-high-emphasis">{{ m.user_name || m.user_id.slice(0, 8) }}</span>
              <span class="ml-2">{{ new Date(m.created_at).toLocaleString() }}</span>
            </div>
            <div class="text-body-2 text-pre-wrap">{{ m.content }}</div>
          </div>
        </div>
      </div>
    </div>

    <footer class="composer d-flex align-center ga-2">
      <v-textarea
        v-model="draft"
        variant="solo-filled"
        flat
        rounded="lg"
        density="comfortable"
        rows="1"
        hide-details
        auto-grow
        max-rows="6"
        :placeholder="canPost ? '输入消息' : '只读成员无法发言'"
        class="composer-input flex-grow-1"
        :disabled="sending || !canPost"
        @keydown.enter.exact.prevent="send"
      />
      <v-btn
        icon="mdi-send"
        color="primary"
        variant="flat"
        rounded="lg"
        :loading="sending"
        :disabled="!canPost || !draft.trim()"
        class="flex-shrink-0"
        @click="send"
      />
    </footer>
  </div>
</template>

<style scoped>
.group-chat {
  flex: 1 1 0;
  min-height: 0;
  display: flex;
  flex-direction: column;
  margin: -10px;
  width: calc(100% + 20px);
  overflow: hidden;
  background: rgb(var(--v-theme-surface));
}

.channel-header {
  flex-shrink: 0;
  padding: 10px 16px;
  border-bottom: thin solid rgba(var(--v-border-color), var(--v-border-opacity));
}

.messages {
  flex: 1 1 0;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  display: flex;
  flex-direction: column;
  padding: 8px 16px 4px;
}

.messages-loading {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 120px;
}

.messages-stack {
  margin-top: auto;
  width: 100%;
  display: flex;
  flex-direction: column;
  padding-bottom: 8px;
}

.chat-row + .chat-row {
  margin-top: 12px;
}

.empty-hint {
  padding: 12px 0 8px;
  text-align: center;
}

.composer {
  flex-shrink: 0;
  padding: 12px 16px 16px;
  border-top: thin solid rgba(var(--v-border-color), var(--v-border-opacity));
  background: rgb(var(--v-theme-surface));
}

.composer-input :deep(.v-field) {
  box-shadow: none;
}

.text-pre-wrap {
  white-space: pre-wrap;
  word-break: break-word;
}
</style>
