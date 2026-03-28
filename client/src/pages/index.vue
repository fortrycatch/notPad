<template>
  <v-container class="timeline-page" fluid>
    <div class="row">
      <div class="page-head">
        <div class="page-icon">
          <v-icon size="24">mdi-timeline-clock-outline</v-icon>
        </div>
        <div>
          <div class="page-title">时间线</div>
          <div class="page-subtitle">记录你的每一次创造</div>
        </div>
      </div>
      <v-btn
        variant="tonal"
        prepend-icon="mdi-refresh"
        :loading="refreshing"
        @click="refresh"
      >
        刷新
      </v-btn>
    </div>

    <template v-if="loading && items.length === 0">
      <div class="timeline-skeleton">
        <v-skeleton-loader v-for="i in 5" :key="i" type="list-item-two-line" class="skeleton-item" />
      </div>
    </template>

    <template v-else-if="items.length === 0">
      <div class="empty-state">
        <v-icon size="64" color="primary" class="mb-4">mdi-clock-outline</v-icon>
        <div class="text-h6 mb-2">还没有任何活动</div>
        <div class="text-body-2 text-medium-emphasis mb-6">
          创建笔记、上传图片或文件，它们都会出现在这里。
        </div>
        <div class="d-flex ga-3 flex-wrap justify-center">
          <v-btn color="primary" prepend-icon="mdi-note-plus" to="/notes">写笔记</v-btn>
          <v-btn variant="tonal" prepend-icon="mdi-image-plus" to="/image">传图片</v-btn>
          <v-btn variant="tonal" prepend-icon="mdi-upload" to="/file">传文件</v-btn>
        </div>
      </div>
    </template>

    <template v-else>
      <template v-for="(group, gi) in groupedItems" :key="gi">
        <div class="date-label">{{ group.label }}</div>
        <div class="timeline-group">
          <div
            v-for="item in group.items"
            :key="item.type + '-' + item.id"
            class="timeline-entry"
            @click="handleClick(item)"
          >
            <div class="entry-icon" :class="'entry-icon--' + item.type">
              <v-icon size="20">{{ typeIcon(item.type) }}</v-icon>
            </div>

            <div class="entry-body">
              <div class="entry-header">
                <span class="entry-name">{{ displayName(item) }}</span>
                <span class="entry-time">{{ formatTime(item.created_at) }}</span>
              </div>

              <div v-if="item.type === 'note' && item.summary" class="entry-summary">
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

              <div v-if="item.size > 0" class="entry-meta">
                {{ formatSize(item.size) }}
              </div>
            </div>
          </div>
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
</template>

<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { server } from '../server'

interface TimelineItem {
  type: 'note' | 'image' | 'file'
  id: string
  name: string
  summary: string
  url: string | null
  size: number
  created_at: string
}

interface TimelineGroup {
  label: string
  items: TimelineItem[]
}

const imageHost = 'https://monika.jkloli.net/'
const PAGE_SIZE = 30

const router = useRouter()
const items = ref<TimelineItem[]>([])
const page = ref(0)
const loading = ref(false)
const loadingMore = ref(false)
const refreshing = ref(false)
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

const typeIcon = (type: string) => {
  if (type === 'note') return 'mdi-note-text-outline'
  if (type === 'image') return 'mdi-image-outline'
  return 'mdi-file-outline'
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

const refresh = async () => {
  refreshing.value = true
  await loadInitial()
  refreshing.value = false
}

const handleClick = (item: TimelineItem) => {
  if (item.type === 'note') {
    router.push({ path: '/notes', query: { id: item.id } })
  } else if (item.type === 'image') {
    router.push('/image')
  } else {
    router.push('/file')
  }
}

let scrollTimer: number | null = null

const handleScroll = () => {
  if (scrollTimer) window.clearTimeout(scrollTimer)

  scrollTimer = window.setTimeout(() => {
    if (loading.value || loadingMore.value || !hasMore.value) return

    const scrollTop = window.scrollY || document.documentElement.scrollTop
    const scrollHeight = document.documentElement.scrollHeight
    const clientHeight = window.innerHeight

    if (scrollTop + clientHeight >= scrollHeight - 200) {
      void loadMore()
    }
  }, 150)
}

onMounted(() => {
  void loadInitial()
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

@media (max-width: 600px) {
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
