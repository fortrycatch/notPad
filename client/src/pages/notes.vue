<template>
  <v-row>
    <v-col cols="12">
      <div class="d-flex justify-space-between align-center mb-6">
        <h1 class="text-h4 font-weight-bold">我的笔记</h1>
        <v-btn color="primary" prepend-icon="mdi-plus" @click="showCreateDialog = true" size="large">
          新建笔记
        </v-btn>
      </div>
    </v-col>
  </v-row>

  <v-row v-if="store.notes.length > 0">
    <v-col v-for="note in store.notes" :key="note.id" cols="12" sm="6" md="4" lg="3">
      <v-card class="note-card" @click="viewNote(note.id)" hover elevation="2">
        <v-card-title class="d-flex justify-space-between align-start">
          <span class="text-truncate">{{ note.title }}</span>
          <v-menu>
            <template v-slot:activator="{ props }">
              <v-btn icon="mdi-dots-vertical" variant="text" size="small" v-bind="props" @click.stop></v-btn>
            </template>
            <v-list>
              <v-list-item @click="editNote(note)">
                <template v-slot:prepend>
                  <v-icon>mdi-pencil</v-icon>
                </template>
                <v-list-item-title>编辑</v-list-item-title>
              </v-list-item>
              <v-list-item @click="deleteNote(note.id)" color="error">
                <template v-slot:prepend>
                  <v-icon color="error">mdi-delete</v-icon>
                </template>
                <v-list-item-title>删除</v-list-item-title>
              </v-list-item>
            </v-list>
          </v-menu>
        </v-card-title>

        <v-card-text>
          <p class="text-body-2 text-truncate-2">
            {{ truncateContent(note.content) }}
          </p>
        </v-card-text>

        <v-card-actions>
          <v-chip size="small" color="grey" class="text-caption">
            {{ formatDate(note.updated_at) }}
          </v-chip>
        </v-card-actions>
      </v-card>
    </v-col>
    <v-btn @click="fetchNotes()">加载更多</v-btn>
  </v-row>

  <v-row v-else>
    <v-col cols="12" class="text-center">
      <v-card class="empty-state" elevation="0">
        <v-card-text>
          <v-icon size="64" color="grey-lighten-1" class="mb-4">
            mdi-note-text-outline
          </v-icon>
          <h3 class="text-h6 mb-2">还没有笔记</h3>
          <p class="text-body-2 text-medium-emphasis">
            点击上方按钮创建你的第一篇笔记
          </p>
        </v-card-text>
      </v-card>
    </v-col>
  </v-row>

  <!-- 创建/编辑笔记对话框 -->
  <v-dialog v-model="showDialog" max-width="600" persistent>
    <v-card>
      <v-card-title class="d-flex justify-space-between align-center">
        <span>{{ showEditDialog ? '编辑笔记' : '新建笔记' }}</span>
        <v-btn icon="mdi-close" variant="text" @click="closeDialog"></v-btn>
      </v-card-title>

      <v-card-text>
        <v-form @submit.prevent="saveNote">
          <v-text-field v-model="noteForm.title" label="标题" placeholder="请输入笔记标题" required class="mb-4"></v-text-field>

          <v-textarea v-model="noteForm.content" label="内容" placeholder="请输入笔记内容" rows="10" auto-grow
            required></v-textarea>
        </v-form>
      </v-card-text>

      <v-card-actions class="pa-4">
        <v-spacer></v-spacer>
        <v-btn @click="closeDialog" class="mr-2">
          取消
        </v-btn>
        <v-btn color="primary" @click="saveNote" :loading="saving">
          保存
        </v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>

  <!-- 删除确认对话框 -->
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
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { trpc } from '../trpc'
import noteStore from '../store/noteStore'
const store = noteStore()
const router = useRouter()
const page = ref(0)
interface Note {
  id: string
  title: string
  content: string
  created_at: string
  updated_at: string
  userId: string
}

const showCreateDialog = ref(false)
const showEditDialog = ref(false)
const showDeleteDialog = ref(false)
const editingNoteId = ref('')
const deletingNoteId = ref('')
const saving = ref(false)
const deleting = ref(false)
const noteForm = ref({
  title: '',
  content: ''
})

const showDialog = computed(() => showCreateDialog.value || showEditDialog.value)

// 获取笔记列表
const fetchNotes = async () => {
  try {
    const result = await trpc.notepad.getNotes.query(page.value)
    store.notes.push(...result)
    page.value++
  } catch (error) {
    console.error('获取笔记列表失败:', error)
  }
}

// 查看笔记详情
const viewNote = (id: string) => {
  router.push(`/note/${id}`)
}

// 编辑笔记
const editNote = (note: Note) => {
  editingNoteId.value = note.id
  noteForm.value = {
    title: note.title,
    content: note.content
  }
  showEditDialog.value = true
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
    await fetchNotes()
    showDeleteDialog.value = false
  } catch (error) {
    console.error('删除笔记失败:', error)
  } finally {
    deleting.value = false
  }
}

// 保存笔记
const saveNote = async () => {
  if (!noteForm.value.title.trim() || !noteForm.value.content.trim()) {
    return
  }

  try {
    saving.value = true
    if (showEditDialog.value) {
      await trpc.notepad.updateNote.mutate({
        id: editingNoteId.value,
        title: noteForm.value.title,
        content: noteForm.value.content
      })
    } else {
      await trpc.notepad.createNote.mutate({
        title: noteForm.value.title,
        content: noteForm.value.content
      })
    }

    closeDialog()
    await fetchNotes()
  } catch (error) {
    console.error('保存笔记失败:', error)
  } finally {
    saving.value = false
  }
}

// 关闭对话框
const closeDialog = () => {
  showCreateDialog.value = false
  showEditDialog.value = false
  editingNoteId.value = ''
  noteForm.value = { title: '', content: '' }
}

// 截断内容
const truncateContent = (content: string) => {
  return content.length > 100 ? content.substring(0, 100) + '...' : content
}

// 格式化日期
const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleDateString('zh-CN')
}

onMounted(() => {
  fetchNotes()
})
</script>

<style scoped>
.note-card {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.note-card .v-card-title {
  flex-grow: 0;
}

.note-card .v-card-text {
  flex-grow: 1;
}

.note-card .v-card-actions {
  flex-grow: 0;
}

.text-truncate-2 {
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}

.empty-state {
  padding: 60px 20px;
}
</style>
