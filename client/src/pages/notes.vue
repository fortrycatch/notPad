<template>
  <div class="notes-container" ref="containerRef">
    <div class="row">
      <div class="page-head">
        <div class="page-icon">
          <v-icon icon="mdi-note-text-outline" size="22" />
        </div>
        <div>
          <div class="page-title">笔记</div>
        </div>
      </div>
      <div class="toolbar-actions desktop-toolbar">
        <v-btn icon="mdi-flash" variant="tonal" @click="showQuickCreate = true" />
        <v-btn variant="tonal" prepend-icon="mdi-tag-multiple" @click="showTagManager = true">
          标签管理
        </v-btn>
        <v-btn color="primary" prepend-icon="mdi-plus" @click="createNote">
          新建笔记
        </v-btn>
      </div>
    </div>

    <div v-if="tags.length > 0" class="tag-filter-row">
      <v-chip
        :color="activeTagId === null ? 'primary' : undefined"
        :variant="activeTagId === null ? 'elevated' : 'outlined'"
        @click="activeTagId = null"
      >
        全部
      </v-chip>
      <v-chip
        v-for="tag in tags"
        :key="tag.id"
        :color="activeTagId === tag.id ? 'primary' : undefined"
        :variant="activeTagId === tag.id ? 'elevated' : 'outlined'"
        @click="activeTagId = tag.id"
      >
        {{ tag.name }}
      </v-chip>
    </div>

    <div v-if="isInitialLoading" class="notes-grid">
      <v-skeleton-loader
        v-for="item in skeletonItems"
        :key="item"
        class="note-skeleton"
        type="article"
      />
    </div>

    <div v-else-if="store.notes.length > 0" class="notes-grid">
      <v-card
        v-for="note in store.notes"
        :key="note.id"
        class="note-card"
        hover
        elevation="2"
        @click="viewNote(note.id)"
      >
        <div class="note-card-header">
          <div class="note-card-title-wrap">
            <div class="note-card-title text-truncate">
              {{ note.title }}
            </div>
            <div class="note-card-date">
              {{ formatDate(note.updated_at) }}
            </div>
          </div>
          <v-menu>
            <template #activator="{ props }">
              <v-btn
                icon="mdi-dots-vertical"
                variant="text"
                size="small"
                v-bind="props"
                @click.stop
              />
            </template>
            <v-list>
              <v-list-item @click.stop="editNote(note.id)">
                <template #prepend>
                  <v-icon>mdi-pencil</v-icon>
                </template>
                <v-list-item-title>编辑</v-list-item-title>
              </v-list-item>
              <v-list-item @click.stop="openBookmarkForNote(note)">
                <template #prepend>
                  <v-icon>mdi-bookmark-plus-outline</v-icon>
                </template>
                <v-list-item-title>收藏</v-list-item-title>
              </v-list-item>
              <v-list-item @click.stop="deleteNote(note.id)" color="error">
                <template #prepend>
                  <v-icon color="error">mdi-delete</v-icon>
                </template>
                <v-list-item-title>删除</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
        </div>

        <div class="note-card-content">
          {{ truncateContent(note.content) }}
        </div>

        <div v-if="noteTagsMap[note.id]?.length" class="note-card-footer">
          <v-chip
            v-for="tag in noteTagsMap[note.id]"
            :key="tag.id"
            size="small"
            variant="tonal"
            color="primary"
            class="note-chip"
          >
            {{ tag.name }}
          </v-chip>
        </div>
      </v-card>
    </div>

    <div v-else class="empty-state">
      <v-icon size="64" color="primary" class="mb-4">
        mdi-note-text-outline
      </v-icon>
      <h3 class="text-h6 mb-2">还没有笔记</h3>
      <p class="empty-description">点击右上角按钮创建你的第一篇笔记</p>
    </div>

    <div v-if="loadingMore" class="pagination">
      <v-progress-circular indeterminate color="primary" size="32" />
    </div>
    <div v-else-if="!hasMore && store.notes.length > 0" class="pagination pagination-text">
      没有更多笔记了
    </div>
  </div>

  <div class="mobile-toolbar">
    <v-btn variant="text" prepend-icon="mdi-flash" @click="showQuickCreate = true">
      速记
    </v-btn>
    <v-btn variant="text" prepend-icon="mdi-tag-multiple" @click="showTagManager = true">
      标签
    </v-btn>
    <v-btn color="primary" prepend-icon="mdi-plus" @click="createNote">
      新建笔记
    </v-btn>
  </div>

  <v-dialog v-model="showQuickCreate" max-width="480">
    <v-card class="quick-create-card">
      <v-card-title class="quick-create-title">
        <v-icon size="20" class="mr-2">mdi-flash</v-icon>
        速记
      </v-card-title>
      <v-card-text class="quick-create-body">
        <v-text-field
          v-model="quickTitle"
          label="标题"
          variant="outlined"
          density="comfortable"
          hide-details
          autofocus
          @keydown.enter="submitQuickCreate"
        />
        <v-textarea
          v-model="quickContent"
          label="内容（可选）"
          variant="outlined"
          density="comfortable"
          hide-details
          rows="3"
          no-resize
        />
        <div v-if="tags.length > 0" class="quick-create-tags">
          <div class="text-caption text-medium-emphasis mb-1">标签</div>
          <div class="tag-chips-row">
            <v-chip
              v-for="tag in tags"
              :key="tag.id"
              :color="quickSelectedTagIds.includes(tag.id) ? 'primary' : undefined"
              :variant="quickSelectedTagIds.includes(tag.id) ? 'elevated' : 'outlined'"
              size="small"
              @click="toggleQuickTag(tag.id)"
            >
              {{ tag.name }}
            </v-chip>
          </div>
        </div>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn variant="text" @click="showQuickCreate = false">取消</v-btn>
        <v-btn color="primary" :loading="quickCreating" @click="submitQuickCreate">创建</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <v-dialog v-model="showTagManager" max-width="480">
    <v-card>
      <v-card-title class="dialog-title">标签管理</v-card-title>
      <v-card-text class="tag-manager-body">
        <div class="tag-create-row">
          <v-text-field
            v-model="newTagName"
            label="新标签名称"
            variant="outlined"
            density="comfortable"
            hide-details
            @keydown.enter="handleCreateTag"
          />
          <v-btn color="primary" :loading="creatingTag" @click="handleCreateTag">添加</v-btn>
        </div>
        <v-list v-if="tags.length > 0" density="compact" class="tag-list">
          <v-list-item v-for="tag in tags" :key="tag.id">
            <v-list-item-title>{{ tag.name }}</v-list-item-title>
            <template #append>
              <v-btn
                icon="mdi-delete-outline"
                size="small"
                variant="text"
                color="error"
                @click="handleDeleteTag(tag.id)"
              />
            </template>
          </v-list-item>
        </v-list>
        <div v-else class="text-medium-emphasis text-center pa-4">暂无标签</div>
      </v-card-text>
      <v-card-actions>
        <v-spacer />
        <v-btn @click="showTagManager = false">关闭</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <v-dialog v-model="showDeleteDialog" max-width="400">
    <v-card>
      <v-card-title class="text-h6">
        确认删除
      </v-card-title>
      <v-card-text>
        确定要删除这篇笔记吗？此操作无法撤销。
      </v-card-text>
      <v-card-actions>
        <v-spacer></v-spacer>
        <v-btn @click="showDeleteDialog = false">
          取消
        </v-btn>
        <v-btn color="error" @click="confirmDelete" :loading="deleting">
          删除
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <AddBookmarkDialog
    v-model="showBookmarkDialog"
    resource-type="note"
    :resource-id="bookmarkNoteId"
    :resource-title="bookmarkNoteTitle"
    :resource-description="bookmarkNoteDesc"
  />
</template>

<script setup lang="ts">
import { ref, onMounted, computed, onUnmounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { trpc } from '../trpc'
import noteStore from '../store/noteStore'
import { useMainStore } from '../store/mainStore'
import AddBookmarkDialog from '../components/compose/AddBookmarkDialog.vue'

interface Note {
  id: string
  title: string
  content: string
  created_at: string | Date
  updated_at: string | Date
}

interface TagItem {
  id: number
  name: string
}

const store = noteStore()
const mainStore = useMainStore()
const router = useRouter()
const route = useRoute()
const page = ref(0)
const containerRef = ref<HTMLElement | null>(null)
const loading = ref(false)
const loadingMore = ref(false)
const hasMore = ref(true)
const PAGE_SIZE = 30
const skeletonItems = Array.from({ length: 8 }, (_, index) => index)

const showDeleteDialog = ref(false)
const deletingNoteId = ref('')
const deleting = ref(false)
const showQuickCreate = ref(false)
const quickTitle = ref('')
const quickContent = ref('')
const quickCreating = ref(false)

const tags = ref<TagItem[]>([])
const activeTagId = ref<number | null>(null)
const showTagManager = ref(false)
const newTagName = ref('')
const creatingTag = ref(false)
const noteTagsMap = ref<Record<string, TagItem[]>>({})
const quickSelectedTagIds = ref<number[]>([])

const showBookmarkDialog = ref(false)
const bookmarkNoteId = ref('')
const bookmarkNoteTitle = ref('')
const bookmarkNoteDesc = ref('')

const openBookmarkForNote = (note: Note) => {
  bookmarkNoteId.value = note.id
  bookmarkNoteTitle.value = note.title
  bookmarkNoteDesc.value = note.content?.slice(0, 200) || ''
  showBookmarkDialog.value = true
}

const isInitialLoading = computed(() => loading.value && store.notes.length === 0)

// 重置并刷新笔记列表
const refreshNotes = async () => {
  page.value = 0
  hasMore.value = true
  store.notes = []
  await fetchNotes()
}

const loadTags = async () => {
  tags.value = await trpc.notepad.listTags.query() as TagItem[]
}

const loadNoteTagsBatch = async (notes: Note[]) => {
  const results = await Promise.all(
    notes.map((n) => trpc.notepad.getNoteTags.query({ note_id: n.id }) as Promise<TagItem[]>)
  )
  for (let i = 0; i < notes.length; i++) {
    noteTagsMap.value[notes[i].id] = results[i]
  }
}

const fetchNotes = async (isLoadMore = false) => {
  if (loading.value || loadingMore.value) return

  try {
    if (isLoadMore) {
      loadingMore.value = true
    } else {
      loading.value = true
    }

    const result = await trpc.notepad.getNotes.query({
      page: page.value,
      tag_id: activeTagId.value
    }) as Note[]

    if (page.value === 0) {
      store.notes = result as any
      noteTagsMap.value = {}
    } else if (result.length > 0) {
      store.notes.push(...(result as any))
    }

    if (result.length > 0) {
      await loadNoteTagsBatch(result)
    }

    hasMore.value = result.length >= PAGE_SIZE

    if (result.length > 0) {
      page.value++
    }
  } catch (error) {
    console.error('获取笔记列表失败:', error)
    hasMore.value = false
  } finally {
    loading.value = false
    loadingMore.value = false
  }
}

// 加载更多
const loadMore = () => {
  if (!loading.value && !loadingMore.value && hasMore.value) {
    fetchNotes(true)
  }
}

// 滚动监听 - 触底加载
let scrollTimer: number | null = null
const handleScroll = () => {
  if (scrollTimer) {
    clearTimeout(scrollTimer)
  }
  
  scrollTimer = window.setTimeout(() => {
    if (loadingMore.value || !hasMore.value) return
    
    const container = containerRef.value?.parentElement || window
    const scrollTop = container === window 
      ? window.scrollY || document.documentElement.scrollTop
      : (container as HTMLElement).scrollTop
    const scrollHeight = container === window
      ? document.documentElement.scrollHeight
      : (container as HTMLElement).scrollHeight
    const clientHeight = container === window
      ? window.innerHeight
      : (container as HTMLElement).clientHeight
    
    // 距离底部100px时触发加载
    if (scrollTop + clientHeight >= scrollHeight - 100) {
      loadMore()
    }
  }, 200) // 防抖200ms
}

// 查看笔记详情
const viewNote = (id: string) => {
  router.push(`/note/${id}`)
}

// 新建笔记
const createNote = () => {
  router.push('/note/create')
}

// 编辑笔记
const editNote = (noteId: string) => {
  router.push({
    path: `/note/${noteId}`,
    query: {
      mode: 'edit'
    }
  })
}

// 删除笔记
const deleteNote = (id: string) => {
  deletingNoteId.value = id
  showDeleteDialog.value = true
}

// 确认删除
const confirmDelete = async () => {
  try {
    deleting.value = true
    await trpc.notepad.deleteNote.mutate({ id: deletingNoteId.value })
    await refreshNotes() // 删除后刷新列表
    showDeleteDialog.value = false
  } catch (error) {
    console.error('删除笔记失败:', error)
  } finally {
    deleting.value = false
  }
}

const toggleQuickTag = (id: number) => {
  const idx = quickSelectedTagIds.value.indexOf(id)
  if (idx >= 0) {
    quickSelectedTagIds.value.splice(idx, 1)
  } else {
    quickSelectedTagIds.value.push(id)
  }
}

const submitQuickCreate = async () => {
  const title = quickTitle.value.trim()
  if (!title || quickCreating.value) return

  quickCreating.value = true
  try {
    const created = await trpc.notepad.createNote.mutate({ title, content: quickContent.value }) as Note | null
    if (created?.id && quickSelectedTagIds.value.length > 0) {
      await Promise.all(
        quickSelectedTagIds.value.map((tagId) =>
          trpc.notepad.addTagToNote.mutate({ note_id: created.id, tag_id: tagId })
        )
      )
    }
    showQuickCreate.value = false
    quickTitle.value = ''
    quickContent.value = ''
    quickSelectedTagIds.value = []
    await refreshNotes()
  } catch (error) {
    console.error('快速创建笔记失败:', error)
  } finally {
    quickCreating.value = false
  }
}

const handleCreateTag = async () => {
  const name = newTagName.value.trim()
  if (!name || creatingTag.value) return

  creatingTag.value = true
  try {
    await trpc.notepad.createTag.mutate({ name })
    newTagName.value = ''
    await loadTags()
  } catch (error) {
    console.error('创建标签失败:', error)
  } finally {
    creatingTag.value = false
  }
}

const handleDeleteTag = async (id: number) => {
  try {
    await trpc.notepad.deleteTag.mutate({ id })
    if (activeTagId.value === id) {
      activeTagId.value = null
    }
    await loadTags()
    await refreshNotes()
  } catch (error) {
    console.error('删除标签失败:', error)
  }
}

const truncateContent = (content: string) => {
  return content.length > 100 ? content.substring(0, 100) + '...' : content
}

// 格式化日期
const formatDate = (dateString: string | Date) => {
  const date = typeof dateString === 'string' ? new Date(dateString) : dateString
  return date.toLocaleDateString('zh-CN')
}

watch(activeTagId, () => {
  refreshNotes()
})

watch(
  () => [mainStore.authenticated, mainStore.refreshTrigger, route.path],
  ([authenticated, , path]) => {
    if (authenticated && path === '/notes') {
      refreshNotes()
    }
  },
  { immediate: false }
)

onMounted(() => {
  loadTags()
  fetchNotes()
  window.addEventListener('scroll', handleScroll, { passive: true })
})

onUnmounted(() => {
  // 移除滚动监听
  window.removeEventListener('scroll', handleScroll)
  if (scrollTimer) {
    clearTimeout(scrollTimer)
  }
})
</script>

<style scoped>
.notes-container {
  min-height: 100%;
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
  min-width: 0;
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

.toolbar-actions {
  display: flex;
  align-items: center;
  gap: 16px;
  flex: 1;
  justify-content: flex-end;
}

.notes-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 16px;
  padding: 20px 0 16px;
}

.note-card,
.note-skeleton {
  border-radius: 20px;
}

.note-card {
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 18px;
  cursor: pointer;
}

.note-card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.note-card-title-wrap {
  min-width: 0;
  flex: 1;
}

.note-card-title {
  font-size: 18px;
  font-weight: 600;
  color: rgb(var(--v-theme-on-surface));
}

.note-card-date {
  margin-top: 6px;
  font-size: 13px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.note-card-content {
  margin-top: 14px;
  flex: 1;
  color: rgb(var(--v-theme-on-surface-variant));
  display: -webkit-box;
  -webkit-line-clamp: 4;
  line-clamp: 4;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.65;
  min-height: 105px;
  white-space: pre-wrap;
  word-break: break-word;
}

.tag-filter-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 16px 0 0;
}

.note-card-footer {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding-top: 16px;
}

.note-chip {
  font-size: 12px;
}

.dialog-title {
  font-size: 18px;
  font-weight: 700;
}

.tag-manager-body {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.tag-create-row {
  display: flex;
  align-items: center;
  gap: 12px;
}

.tag-list {
  max-height: 300px;
  overflow-y: auto;
}

.tag-chips-row {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  min-height: 320px;
  margin: 24px 0;
  padding: 32px 24px;
  border-radius: 20px;
  background: rgb(var(--v-theme-surface));
}

.empty-description {
  color: rgb(var(--v-theme-on-surface-variant));
}

.pagination {
  display: flex;
  justify-content: center;
  padding: 8px 0 24px;
}

.pagination-text {
  color: rgb(var(--v-theme-on-surface-variant));
}

.quick-create-title {
  display: flex;
  align-items: center;
  font-size: 18px;
  font-weight: 700;
  padding-bottom: 0;
}

.quick-create-body {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.mobile-toolbar {
  display: none;
}

@media (max-width: 760px) {
  .desktop-toolbar {
    display: none;
  }

  .notes-container {
    padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 104px);
  }

  .page-title {
    font-size: 24px;
  }

  .mobile-toolbar {
    position: fixed;
    left: 0;
    right: 0;
    bottom: 0;
    z-index: 30;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 10px;
    padding: 10px 12px calc(env(safe-area-inset-bottom, 0px) + 10px);
    border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
    background: rgba(var(--v-theme-surface), 0.96);
    backdrop-filter: blur(12px);
    box-shadow: 0 12px 28px rgba(15, 23, 42, 0.16);
  }

  .mobile-toolbar > * {
    flex: 1 1 auto;
    min-width: 0;
  }
}
</style>
