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
    </header>

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
import { computed, ref } from 'vue'
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

const router = useRouter()
const mainStore = useMainStore()

const form = ref({
  title: '',
  content: ''
})
const saving = ref(false)
const showSaveError = ref(false)
const saveErrorMessage = ref('')

const canSave = computed(() => {
  return form.value.title.trim() !== '' && form.value.content.trim() !== ''
})

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
