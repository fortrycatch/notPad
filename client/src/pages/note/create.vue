<template>
  <div class="note-create-page">
    <header class="note-create-topbar">
      <div class="note-create-topbar__main">
        <v-btn
          icon="mdi-arrow-left"
          variant="text"
          density="comfortable"
          @click="goBack"
          title="返回"
        />
        <div class="note-create-topbar__meta">
          <div class="note-create-topbar__title">新建笔记</div>
        </div>
      </div>
      <v-menu :close-on-content-click="false">
        <template #activator="{ props: tagMenuProps }">
          <v-btn
            variant="tonal"
            prepend-icon="mdi-tag-outline"
            v-bind="tagMenuProps"
          >
            标签{{ selectedTagIds.length > 0 ? ` (${selectedTagIds.length})` : '' }}
          </v-btn>
        </template>
        <v-list density="compact" min-width="200">
          <v-list-item
            v-for="tag in allTags"
            :key="tag.id"
            @click="toggleTag(tag.id)"
          >
            <template #prepend>
              <v-icon :color="selectedTagIds.includes(tag.id) ? 'primary' : undefined">
                {{ selectedTagIds.includes(tag.id) ? 'mdi-checkbox-marked' : 'mdi-checkbox-blank-outline' }}
              </v-icon>
            </template>
            <v-list-item-title>{{ tag.name }}</v-list-item-title>
          </v-list-item>
          <v-list-item v-if="allTags.length === 0" disabled>
            <v-list-item-title class="text-medium-emphasis">暂无标签</v-list-item-title>
          </v-list-item>
        </v-list>
      </v-menu>
    </header>

    <div v-if="selectedTagNames.length > 0" class="create-tags-row">
      <v-chip
        v-for="tag in selectedTagNames"
        :key="tag.id"
        size="small"
        closable
        @click:close="toggleTag(tag.id)"
      >
        {{ tag.name }}
      </v-chip>
    </div>

    <NoteMarkdownEditor
      v-model="form"
      :saving="saving"
      :save-disabled="!canSave"
      save-label="创建笔记"
      @cancel="goBack"
      @save="createNote"
    />

    <v-snackbar v-model="showSaveError" color="error" timeout="3000" location="top">
      <v-icon start>mdi-alert-circle</v-icon>
      {{ saveErrorMessage }}
    </v-snackbar>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import NoteMarkdownEditor from '../../components/note/NoteMarkdownEditor.vue'
import { useMainStore } from '../../store/mainStore'
import { trpc } from '../../trpc'

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

const router = useRouter()
const mainStore = useMainStore()

const form = ref({
  title: '',
  content: ''
})
const saving = ref(false)
const showSaveError = ref(false)
const saveErrorMessage = ref('')
const allTags = ref<TagItem[]>([])
const selectedTagIds = ref<number[]>([])

const canSave = computed(() => {
  return form.value.title.trim() !== ''
})

const selectedTagNames = computed(() =>
  allTags.value.filter((t) => selectedTagIds.value.includes(t.id))
)

const toggleTag = (id: number) => {
  const idx = selectedTagIds.value.indexOf(id)
  if (idx >= 0) {
    selectedTagIds.value.splice(idx, 1)
  } else {
    selectedTagIds.value.push(id)
  }
}

const createNote = async () => {
  if (!canSave.value || saving.value) return

  try {
    saving.value = true
    const created = await trpc.notepad.createNote.mutate({
      title: form.value.title.trim(),
      content: form.value.content.trim()
    }) as Note | null

    if (!created?.id) {
      throw new Error('创建笔记失败')
    }

    if (selectedTagIds.value.length > 0) {
      await Promise.all(
        selectedTagIds.value.map((tagId) =>
          trpc.notepad.addTagToNote.mutate({ note_id: created.id, tag_id: tagId })
        )
      )
    }

    mainStore.triggerRefresh()
    router.replace(`/note/${created.id}`)
  } catch (err: any) {
    console.error('创建笔记失败:', err)
    saveErrorMessage.value = err?.message || '创建失败，请稍后重试'
    showSaveError.value = true
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  allTags.value = await trpc.notepad.listTags.query() as TagItem[]
})

const goBack = () => {
  if (window.history.length > 1) {
    router.back()
    return
  }

  router.push('/notes')
}
</script>

<style scoped>
.note-create-page {
  --note-sticky-top: 72px;
  min-height: 100%;
  padding: 0 clamp(16px, 4vw, 32px) 48px;
}

.note-create-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  min-height: var(--note-sticky-top);
  padding: 14px 0;
  border-bottom: 1px solid rgba(var(--v-theme-on-surface), 0.08);
}

.note-create-topbar__main {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.note-create-topbar__meta {
  min-width: 0;
}

.note-create-topbar__title {
  font-size: 18px;
  font-weight: 700;
}

.create-tags-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 12px 0 0;
}

@media (max-width: 760px) {
  .note-create-page {
    padding: 0 12px 32px;
  }

  .note-create-topbar {
    min-height: auto;
    padding: 12px 0;
  }

  .note-create-topbar__main {
    align-items: flex-start;
  }
}
</style>
