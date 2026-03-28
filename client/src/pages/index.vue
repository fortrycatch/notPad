<template>
  <v-container class="timeline-page" fluid>
    <div class="row">
      <div class="page-head">
        <!-- <div class="page-icon">
          <v-icon size="24">mdi-timeline-clock-outline</v-icon>
        </div> -->
        <!-- <div>
          <div class="page-title">时间线</div>
          <div class="page-subtitle">记录你的每一次创造</div>
        </div> -->
      </div>
    </div>

    <template v-if="!authReady">
      <div class="timeline-skeleton">
        <v-skeleton-loader v-for="i in 5" :key="i" type="list-item-two-line" class="skeleton-item" />
      </div>
    </template>

    <template v-else-if="!authenticated">
      <div class="d-none" aria-hidden="true" />
    </template>

    <template v-else-if="loading && items.length === 0">
      <div class="timeline-skeleton">
        <v-skeleton-loader v-for="i in 5" :key="i" type="list-item-two-line" class="skeleton-item" />
      </div>
    </template>

    <template v-else-if="items.length === 0">
      <div class="empty-state">
        <v-icon size="64" color="primary" class="mb-4">mdi-clock-outline</v-icon>
        <div class="text-h6 mb-2">还没有任何活动</div>
        <div class="text-body-2 text-medium-emphasis mb-6">
          创建笔记、上传图片或文件、添加书签，它们都会出现在这里。
        </div>
        <div class="d-flex ga-3 flex-wrap justify-center">
          <v-btn color="primary" prepend-icon="mdi-note-plus" to="/notes">写笔记</v-btn>
          <v-btn variant="tonal" prepend-icon="mdi-image-plus" to="/image">传图片</v-btn>
          <v-btn variant="tonal" prepend-icon="mdi-upload" to="/file">传文件</v-btn>
          <v-btn variant="tonal" prepend-icon="mdi-bookmark-plus-outline" to="/bookmark">书签</v-btn>
        </div>
      </div>
    </template>

    <template v-else>
      <template v-for="(group, gi) in groupedItems" :key="gi">
        <div class="date-label">{{ group.label }}</div>
        <div class="timeline-group">
          <template
            v-for="item in group.items"
            :key="item.type + '-' + item.id"
          >
            <div v-if="isMurmur(item)" class="murmur-entry" @click="handleClick(item)">
              <div class="murmur-content">
                <v-icon size="16" class="murmur-icon">mdi-flash-outline</v-icon>
                <span class="murmur-text">{{ displayName(item) }}</span>
              </div>
              <span class="murmur-time">{{ formatTime(item.created_at) }}</span>
            </div>

            <div v-else class="timeline-entry" @click="handleClick(item)">
              <div class="entry-icon" :class="'entry-icon--' + item.type">
                <v-icon size="20">{{ typeIcon(item) }}</v-icon>
              </div>

              <div class="entry-body">
                <div class="entry-header">
                  <span class="entry-name">{{ displayName(item) }}</span>
                  <span class="entry-time">{{ formatTime(item.created_at) }}</span>
                </div>

                <div v-if="item.type === 'note' && item.summary" class="entry-summary">
                  {{ item.summary }}
                </div>

                <div v-if="item.type === 'bookmark' && item.summary" class="entry-summary">
                  {{ item.summary }}
                </div>

                <div v-if="item.type === 'image' && item.url" class="entry-thumb">
                  <v-img
                    :src="imageHost + item.url + '?x-oss-process=image/resize,w_480'"
                    :alt="item.name"
                    cover
                    class="thumb-img"
                  >
                    <template #placeholder>
                      <div class="d-flex align-center justify-center fill-height">
                        <v-progress-circular size="20" width="2" indeterminate color="grey" />
                      </div>
                    </template>
                  </v-img>
                </div>

                <div
                  v-if="item.type === 'bookmark' && item.bookmark_subtype === 'image' && bookmarkThumbSrc(item.url)"
                  class="entry-thumb"
                >
                  <v-img
                    :src="bookmarkThumbSrc(item.url)"
                    :alt="item.name"
                    cover
                    class="thumb-img"
                  >
                    <template #placeholder>
                      <div class="d-flex align-center justify-center fill-height">
                        <v-progress-circular size="20" width="2" indeterminate color="grey" />
                      </div>
                    </template>
                  </v-img>
                </div>

                <div v-if="item.size > 0" class="entry-meta">
                  {{ formatSize(item.size) }}
                </div>
              </div>
            </div>
          </template>
        </div>
      </template>

      <div v-if="loadingMore" class="timeline-loading">
        <v-progress-circular size="24" width="2" indeterminate color="primary" />
        <span class="text-body-2 text-medium-emphasis">加载更多...</span>
      </div>
      <div v-else-if="!hasMore" class="timeline-end text-body-2 text-medium-emphasis">
        没有更多了
      </div>
    </template>
  </v-container>

  <ImagePreviewDialog
    v-model="showImagePreview"
    :image-url="previewImageUrl"
    :image-name="previewImageName"
    :image-id="previewImageId"
    :image-size="previewImageSize"
    :image-date="previewImageDate"
  />

  <FileDownloadDialog
    v-model="showFileDialog"
    :file-name="fileDialogName"
    :file-url="fileDialogUrl"
    :file-size="fileDialogSize"
    :mime-type="fileDialogMimeType"
  />
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { storeToRefs } from 'pinia'
import { useRouter } from 'vue-router'
import { useMainStore } from '../store/mainStore'
import { server } from '../server'
import ImagePreviewDialog from '../components/compose/ImagePreviewDialog.vue'
import FileDownloadDialog from '../components/compose/FileDownloadDialog.vue'

type BookmarkSubtype = 'url' | 'image' | 'note' | 'file'

interface TimelineItem {
  type: 'note' | 'image' | 'file' | 'bookmark'
  id: string
  name: string
  summary: string
  url: string | null
  size: number
  created_at: string
  bookmark_subtype?: BookmarkSubtype | null
  ref_id?: string | null
}

interface TimelineGroup {
  label: string
  items: TimelineItem[]
}

const imageHost = 'https://monika.jkloli.net/'
const PAGE_SIZE = 30

const router = useRouter()
const mainStore = useMainStore()
const { authenticated, authReady } = storeToRefs(mainStore)

const items = ref<TimelineItem[]>([])
const page = ref(0)
const loading = ref(false)
const loadingMore = ref(false)
const hasMore = ref(true)

const groupedItems = computed<TimelineGroup[]>(() => {
  const now = new Date()
  const todayStr = toDateKey(now)
  const yesterday = new Date(now)
  yesterday.setDate(yesterday.getDate() - 1)
  const yesterdayStr = toDateKey(yesterday)

  const map = new Map<string, TimelineItem[]>()

  for (const item of items.value) {
    const key = toDateKey(new Date(item.created_at))
    let arr = map.get(key)
    if (!arr) {
      arr = []
      map.set(key, arr)
    }
    arr.push(item)
  }

  const groups: TimelineGroup[] = []
  for (const [key, list] of map) {
    let label: string
    if (key === todayStr) {
      label = '今天'
    } else if (key === yesterdayStr) {
      label = '昨天'
    } else {
      label = key
    }
    groups.push({ label, items: list })
  }
  return groups
})

const toDateKey = (d: Date) => {
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${day}`
}

const isMurmur = (item: TimelineItem) => item.type === 'note' && !item.summary

const typeIcon = (item: TimelineItem) => {
  if (item.type === 'bookmark') {
    const sub = item.bookmark_subtype
    if (sub === 'url') return 'mdi-web'
    if (sub === 'image') return 'mdi-image-outline'
    if (sub === 'note') return 'mdi-note-text-outline'
    if (sub === 'file') return 'mdi-file-outline'
    return 'mdi-bookmark-multiple-outline'
  }
  if (item.type === 'note') return 'mdi-note-text-outline'
  if (item.type === 'image') return 'mdi-image-outline'
  return 'mdi-file-outline'
}

const bookmarkThumbSrc = (url: string | null) => {
  if (!url?.trim()) return ''
  const t = url.trim()
  const full = t.startsWith('http://') || t.startsWith('https://') ? t : imageHost + t.replace(/^\//, '')
  if (!full.includes('monika.jkloli.net')) return full
  const sep = full.includes('?') ? '&' : '?'
  return `${full}${sep}x-oss-process=image/resize,w_480`
}

const displayName = (item: TimelineItem) => {
  const raw = item.name || ''
  return raw.split('/').pop() || raw
}

const formatTime = (dateStr: string) => {
  const d = new Date(dateStr)
  return d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })
}

const formatSize = (bytes: number) => {
  if (!bytes) return ''
  const units = ['B', 'KB', 'MB', 'GB']
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  return `${(bytes / 1024 ** i).toFixed(i === 0 ? 0 : 1)} ${units[i]}`
}

const fetchPage = async (pageIndex: number): Promise<TimelineItem[]> => {
  return await server.timeline.query(pageIndex) as TimelineItem[]
}

const loadInitial = async () => {
  loading.value = true
  page.value = 0
  items.value = []
  hasMore.value = true

  const data = await fetchPage(0)
  items.value = data
  hasMore.value = data.length >= PAGE_SIZE
  page.value = 1
  loading.value = false
}

const loadMore = async () => {
  if (!authenticated.value || !authReady.value) return
  if (loadingMore.value || !hasMore.value) return

  loadingMore.value = true
  const data = await fetchPage(page.value)
  if (data.length === 0) {
    hasMore.value = false
  } else {
    items.value.push(...data)
    hasMore.value = data.length >= PAGE_SIZE
    page.value++
  }
  loadingMore.value = false
}

const showImagePreview = ref(false)
const previewImageUrl = ref('')
const previewImageName = ref('')
const previewImageId = ref(0)
const previewImageSize = ref(0)
const previewImageDate = ref('')

const showFileDialog = ref(false)
const fileDialogName = ref('')
const fileDialogUrl = ref('')
const fileDialogSize = ref(0)
const fileDialogMimeType = ref('')

const resolveBookmarkImageUrl = (url: string) => {
  const t = url.trim()
  if (t.startsWith('http://') || t.startsWith('https://')) return t
  return imageHost + t.replace(/^\//, '')
}

const handleClick = async (item: TimelineItem) => {
  if (item.type === 'note') {
    router.push(`/note/${item.id}`)
    return
  }

  if (item.type === 'bookmark') {
    const sub = item.bookmark_subtype
    if (sub === 'note' && item.ref_id) {
      router.push(`/note/${item.ref_id}`)
      return
    }
    if (sub === 'image' && item.url) {
      previewImageUrl.value = resolveBookmarkImageUrl(item.url)
      previewImageName.value = displayName(item)
      previewImageId.value = item.ref_id ? Number(item.ref_id) : 0
      previewImageSize.value = 0
      previewImageDate.value = item.created_at
      showImagePreview.value = true
      return
    }
    if (sub === 'file' && item.url) {
      fileDialogName.value = displayName(item)
      fileDialogUrl.value = item.url
      fileDialogSize.value = 0
      fileDialogMimeType.value = ''
      showFileDialog.value = true
      return
    }
    router.push(`/bookmark/${item.id}`)
    return
  }

  if (item.type === 'image' && item.url) {
    previewImageUrl.value = imageHost + item.url
    previewImageName.value = displayName(item)
    previewImageId.value = Number(item.id)
    previewImageSize.value = item.size
    previewImageDate.value = item.created_at
    showImagePreview.value = true
    return
  }

  if (item.type === 'file') {
    fileDialogName.value = displayName(item)
    fileDialogSize.value = item.size
    fileDialogMimeType.value = item.summary
    fileDialogUrl.value = ''
    showFileDialog.value = true
    try {
      const result = await server.file_drive.getDownloadUrl.query({ file_id: Number(item.id) })
      fileDialogUrl.value = result.url
    } catch { /* download button stays disabled */ }
    return
  }
}

let scrollTimer: number | null = null

const handleScroll = () => {
  if (scrollTimer) window.clearTimeout(scrollTimer)

  scrollTimer = window.setTimeout(() => {
    if (!authenticated.value || !authReady.value) return
    if (loading.value || loadingMore.value || !hasMore.value) return

    const scrollTop = window.scrollY || document.documentElement.scrollTop
    const scrollHeight = document.documentElement.scrollHeight
    const clientHeight = window.innerHeight

    if (scrollTop + clientHeight >= scrollHeight - 200) {
      void loadMore()
    }
  }, 150)
}

watch(
  () => [authenticated.value, authReady.value] as const,
  ([auth, ready]) => {
    if (!ready) return
    if (!auth) {
      items.value = []
      page.value = 0
      hasMore.value = true
      loading.value = false
      loadingMore.value = false
      return
    }
    void loadInitial()
  },
  { immediate: true }
)

onMounted(() => {
  window.addEventListener('scroll', handleScroll, { passive: true })
})

onUnmounted(() => {
  window.removeEventListener('scroll', handleScroll)
  if (scrollTimer) window.clearTimeout(scrollTimer)
})
</script>

<style scoped>
.timeline-page {
  max-width: 720px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding-bottom: 48px;
}

.row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
}

.page-head {
  display: flex;
  align-items: center;
  gap: 14px;
}

.page-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 44px;
  height: 44px;
  border-radius: 14px;
  background: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-primary));
  flex-shrink: 0;
}

.page-title {
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
}

.page-subtitle {
  margin-top: 4px;
  color: rgb(var(--v-theme-on-surface-variant));
  font-size: 14px;
}

.timeline-skeleton {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.skeleton-item {
  border-radius: 16px;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  min-height: 400px;
  padding: 32px 24px;
  border-radius: 20px;
  background: rgb(var(--v-theme-surface));
}

.date-label {
  font-size: 15px;
  font-weight: 700;
  color: rgb(var(--v-theme-on-surface-variant));
  padding: 8px 0 4px;
}

.timeline-group {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.timeline-entry {
  display: flex;
  gap: 14px;
  padding: 14px 16px;
  border-radius: 16px;
  background: rgb(var(--v-theme-surface));
  cursor: pointer;
  transition: background 0.15s;
}

.timeline-entry:hover {
  background: rgba(var(--v-theme-on-surface), 0.06);
}

.entry-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border-radius: 12px;
  flex-shrink: 0;
}

.entry-icon--note {
  background: rgba(var(--v-theme-primary), 0.12);
  color: rgb(var(--v-theme-primary));
}

.entry-icon--image {
  background: rgba(76, 175, 80, 0.12);
  color: #4caf50;
}

.entry-icon--file {
  background: rgba(255, 152, 0, 0.12);
  color: #ff9800;
}

.entry-icon--bookmark {
  background: rgba(156, 39, 176, 0.12);
  color: #9c27b0;
}

.entry-body {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.entry-header {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.entry-name {
  font-size: 15px;
  font-weight: 600;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 0;
}

.entry-time {
  font-size: 13px;
  color: rgb(var(--v-theme-on-surface-variant));
  white-space: nowrap;
  flex-shrink: 0;
}

.entry-summary {
  font-size: 13px;
  color: rgb(var(--v-theme-on-surface-variant));
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.5;
}

.entry-thumb {
  border-radius: 10px;
  overflow: hidden;
  max-width: 280px;
}

.thumb-img {
  aspect-ratio: 16 / 10;
  border-radius: 10px;
}

.entry-meta {
  font-size: 12px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.timeline-loading,
.timeline-end {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 24px 0;
}

.murmur-entry {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 10px 16px;
  border-radius: 20px;
  background: rgba(var(--v-theme-primary), 0.08);
  cursor: pointer;
  transition: background 0.15s;
}

.murmur-entry:hover {
  background: rgba(var(--v-theme-primary), 0.14);
}

.murmur-content {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}

.murmur-icon {
  flex-shrink: 0;
  color: rgb(var(--v-theme-primary));
}

.murmur-text {
  font-size: 15px;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  min-width: 0;
}

.murmur-time {
  font-size: 12px;
  color: rgb(var(--v-theme-on-surface-variant));
  white-space: nowrap;
  flex-shrink: 0;
}

@media (max-width: 760px) {
  .timeline-page {
    padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 48px);
  }

  .page-title {
    font-size: 22px;
  }

  .page-subtitle {
    display: none;
  }

  .timeline-entry {
    padding: 12px;
  }

  .entry-thumb {
    max-width: 100%;
  }
}
</style>
