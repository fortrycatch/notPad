<template>
  <div class="bookmark-detail-page">
    <div v-if="loading" class="bookmark-state">
      <v-progress-circular indeterminate color="primary" size="56" />
      <p>正在加载书签...</p>
    </div>

    <div v-else-if="error" class="bookmark-state bookmark-state-error">
      <v-icon size="52" color="error">mdi-alert-circle</v-icon>
      <h3>{{ error }}</h3>
      <div class="bookmark-state-actions">
        <v-btn color="primary" prepend-icon="mdi-refresh" @click="fetchBookmark">重试</v-btn>
        <v-btn variant="text" prepend-icon="mdi-arrow-left" @click="goBack">返回</v-btn>
      </div>
    </div>

    <div v-else-if="bookmark" class="bookmark-shell">
      <header class="bookmark-topbar">
        <div class="bookmark-topbar-main">
          <v-btn
            icon="mdi-arrow-left"
            variant="text"
            density="comfortable"
            @click="goBack"
            title="返回"
          />
          <div class="bookmark-topbar-meta">
            <div class="bookmark-topbar-time">
              <v-icon size="16" class="mr-1">{{ typeIconMap[bookmark.type] || 'mdi-bookmark' }}</v-icon>
              <span>{{ formatDate(bookmark.created_at) }}</span>
            </div>
          </div>
        </div>

        <div class="bookmark-topbar-actions">
          <v-btn
            v-if="bookmark.url"
            variant="text"
            density="comfortable"
            prepend-icon="mdi-open-in-new"
            title="打开链接"
            @click="openExternalUrl(bookmark.url)"
          >
            <span class="bookmark-topbar-btn-label">打开链接</span>
          </v-btn>
          <v-btn
            variant="text"
            density="comfortable"
            prepend-icon="mdi-delete"
            color="error"
            title="删除"
            @click="showDeleteDialog = true"
          >
            <span class="bookmark-topbar-btn-label">删除</span>
          </v-btn>
        </div>
      </header>

      <div class="bookmark-body">
        <div v-if="bookmark.type === 'image' && bookmark.url" class="bookmark-image-preview">
          <v-img
            :src="imageBookmarkDetailSrc(bookmark.url)"
            :alt="bookmark.title"
            max-height="min(72vh, 900px)"
            contain
            class="bookmark-image-preview__img"
          >
            <template #placeholder>
              <div class="d-flex align-center justify-center fill-height py-12">
                <v-progress-circular indeterminate color="primary" />
              </div>
            </template>
          </v-img>
        </div>

        <h1 class="bookmark-title">{{ bookmark.title }}</h1>

        <div v-if="bookmark.url" class="bookmark-source-url">
          <v-icon size="14" class="mr-1">mdi-link-variant</v-icon>
          <a
            :href="bookmark.url"
            target="_blank"
            rel="noopener noreferrer"
            class="bookmark-source-link"
          >
            {{ bookmark.url }}
          </a>
        </div>

        <div v-if="bookmark.description && !bookmark.content" class="bookmark-description">
          {{ bookmark.description }}
        </div>

        <article
          v-if="renderedHtml"
          class="bookmark-markdown"
          v-html="renderedHtml"
        />

        <div
          v-if="!bookmark.content && !bookmark.description && !(bookmark.type === 'image' && bookmark.url)"
          class="bookmark-empty"
        >
          <v-icon size="40" color="primary">mdi-text-box-remove-outline</v-icon>
          <p>暂无内容</p>
        </div>
      </div>
    </div>

    <v-dialog v-model="showDeleteDialog" max-width="400">
      <v-card>
        <v-card-title class="dialog-title">确认删除</v-card-title>
        <v-card-text>确定要删除这个书签吗？</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn @click="showDeleteDialog = false">取消</v-btn>
          <v-btn color="error" :loading="deleting" @click="doDelete">删除</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </div>
</template>

<script setup lang="ts">
import MarkdownIt from 'markdown-it'
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { server } from '../../server'

interface BookmarkDetail {
  id: number
  type: string
  title: string
  description: string
  content: string | null
  url: string
  ref_id: string | null
  created_at: string | Date
}

const route = useRoute()
const router = useRouter()

const IMAGE_HOST = 'https://monika.jkloli.net/'

const resolveImageBookmarkUrl = (url: string) => {
  const t = url.trim()
  if (t.startsWith('http://') || t.startsWith('https://')) return t
  return IMAGE_HOST + t.replace(/^\//, '')
}

const imageBookmarkDetailSrc = (url: string) => {
  const full = resolveImageBookmarkUrl(url)
  if (!full.includes('monika.jkloli.net')) return full
  const sep = full.includes('?') ? '&' : '?'
  return `${full}${sep}x-oss-process=image/resize,w_960`
}

const bookmark = ref<BookmarkDetail | null>(null)
const loading = ref(true)
const error = ref('')
const showDeleteDialog = ref(false)
const deleting = ref(false)

const typeIconMap: Record<string, string> = {
  url: 'mdi-web',
  image: 'mdi-image',
  note: 'mdi-note-text',
  file: 'mdi-file'
}

const markdown = new MarkdownIt({
  html: false,
  linkify: true,
  breaks: true,
  typographer: true
})

const defaultLinkOpen = markdown.renderer.rules.link_open?.bind(markdown.renderer.rules)

markdown.renderer.rules.link_open = (tokens, idx, options, env, self) => {
  const href = tokens[idx].attrGet('href') || ''
  if (!href.startsWith('#')) {
    tokens[idx].attrSet('target', '_blank')
    tokens[idx].attrSet('rel', 'noopener noreferrer')
  }
  return defaultLinkOpen
    ? defaultLinkOpen(tokens, idx, options, env, self)
    : self.renderToken(tokens, idx, options)
}

const renderedHtml = computed(() => {
  if (!bookmark.value?.content) return ''
  return markdown.render(bookmark.value.content)
})

const formatDate = (v: string | Date) => {
  const d = typeof v === 'string' ? new Date(v) : v
  return d.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

const openExternalUrl = (url: string) => {
  window.open(url, '_blank', 'noopener,noreferrer')
}

const goBack = () => {
  if (window.history.length > 1) {
    router.back()
  } else {
    router.push('/bookmark')
  }
}

const fetchBookmark = async () => {
  const id = Number(route.params.id)
  if (!id || isNaN(id)) {
    error.value = '无效的书签 ID'
    loading.value = false
    return
  }

  loading.value = true
  error.value = ''
  try {
    bookmark.value = await server.bookmark.getById.query({ id }) as BookmarkDetail
  } catch (err: any) {
    error.value = err?.message || '加载书签失败'
  } finally {
    loading.value = false
  }
}

const doDelete = async () => {
  if (!bookmark.value) return
  deleting.value = true
  try {
    await server.bookmark.remove.mutate({ id: bookmark.value.id })
    router.push('/bookmark')
  } catch (err) {
    console.error('删除书签失败:', err)
  } finally {
    deleting.value = false
  }
}

onMounted(() => {
  fetchBookmark()
})
</script>

<style scoped>
.bookmark-detail-page {
  min-height: 100%;
}

.bookmark-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  gap: 16px;
  min-height: 400px;
}

.bookmark-state-error h3 {
  color: rgb(var(--v-theme-error));
}

.bookmark-state-actions {
  display: flex;
  gap: 12px;
  margin-top: 8px;
}

.bookmark-shell {
  max-width: 820px;
  margin: 0 auto;
}

.bookmark-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  flex-wrap: wrap;
}

.bookmark-topbar-main {
  display: flex;
  align-items: center;
  gap: 8px;
}

.bookmark-topbar-meta {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.bookmark-topbar-time {
  display: flex;
  align-items: center;
  font-size: 13px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.bookmark-topbar-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.bookmark-body {
  padding: 24px 0 48px;
}

.bookmark-image-preview {
  margin: 0 0 20px;
  border-radius: 16px;
  overflow: hidden;
  background: rgba(var(--v-theme-on-surface), 0.06);
}

.bookmark-image-preview__img {
  width: 100%;
}

.bookmark-title {
  margin: 0;
  font-size: clamp(28px, 4vw, 42px);
  line-height: 1.15;
  word-break: break-word;
}

.bookmark-source-url {
  display: flex;
  align-items: center;
  margin-top: 12px;
  font-size: 13px;
  color: rgb(var(--v-theme-on-surface-variant));
  overflow: hidden;
}

.bookmark-source-link {
  color: rgb(var(--v-theme-primary));
  text-decoration: none;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.bookmark-source-link:hover {
  text-decoration: underline;
}

.bookmark-description {
  margin-top: 20px;
  color: rgb(var(--v-theme-on-surface-variant));
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

.bookmark-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
  margin-top: 48px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.dialog-title {
  font-size: 18px;
  font-weight: 700;
}

.bookmark-markdown {
  padding: 24px 0 0;
  font-size: 16px;
  line-height: 1.85;
  color: rgb(var(--v-theme-on-surface));
  word-break: break-word;
}

.bookmark-markdown :deep(h1),
.bookmark-markdown :deep(h2),
.bookmark-markdown :deep(h3),
.bookmark-markdown :deep(h4) {
  margin: 1.9em 0 0.7em;
  line-height: 1.2;
}

.bookmark-markdown :deep(h1:first-child),
.bookmark-markdown :deep(h2:first-child) {
  margin-top: 0;
}

.bookmark-markdown :deep(p),
.bookmark-markdown :deep(ul),
.bookmark-markdown :deep(ol),
.bookmark-markdown :deep(blockquote),
.bookmark-markdown :deep(pre),
.bookmark-markdown :deep(table) {
  margin: 0 0 1.1em;
}

.bookmark-markdown :deep(ul),
.bookmark-markdown :deep(ol) {
  padding-left: 1.4em;
}

.bookmark-markdown :deep(li + li) {
  margin-top: 0.35em;
}

.bookmark-markdown :deep(a) {
  color: rgb(var(--v-theme-primary));
  text-decoration: none;
}

.bookmark-markdown :deep(a:hover) {
  text-decoration: underline;
}

.bookmark-markdown :deep(code) {
  padding: 0.15em 0.42em;
  border-radius: 6px;
  background: rgba(var(--v-theme-on-surface), 0.08);
  font-size: 0.9em;
}

.bookmark-markdown :deep(pre) {
  overflow-x: auto;
  padding: 16px 18px;
  background: rgba(var(--v-theme-on-surface), 0.06);
}

.bookmark-markdown :deep(pre code) {
  padding: 0;
  background: transparent;
}

.bookmark-markdown :deep(blockquote) {
  padding: 4px 0 4px 16px;
  border-left: 3px solid rgba(var(--v-theme-primary), 0.55);
  color: rgba(var(--v-theme-on-surface), 0.72);
}

.bookmark-markdown :deep(table) {
  width: 100%;
  border-collapse: collapse;
}

.bookmark-markdown :deep(th),
.bookmark-markdown :deep(td) {
  border: 1px solid rgba(var(--v-theme-on-surface), 0.1);
  padding: 10px 12px;
  text-align: left;
}

.bookmark-markdown :deep(img) {
  display: block;
  max-width: 100%;
  height: auto;
  margin: 1.25rem auto;
  border-radius: 12px;
}

@media (max-width: 760px) {
  .bookmark-body {
    padding: 16px 0 32px;
  }

  .bookmark-topbar {
    flex-wrap: nowrap;
    gap: 4px;
  }

  .bookmark-topbar-main {
    flex: 1 1 0;
    min-width: 0;
  }

  .bookmark-topbar-time {
    min-width: 0;
    overflow: hidden;
  }

  .bookmark-topbar-time span {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .bookmark-topbar-actions {
    flex-wrap: nowrap;
    flex-shrink: 0;
    gap: 0;
  }

  .bookmark-topbar-actions :deep(.v-btn) {
    min-width: 40px;
    padding-inline: 4px;
  }

  .bookmark-topbar-btn-label {
    display: none;
  }
}
</style>
