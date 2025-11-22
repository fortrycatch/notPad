<template>
  <div class="note-detail-container">
    <!-- 加载状态 -->
    <div v-if="loading" class="d-flex justify-center align-center" style="min-height: 400px">
      <v-progress-circular indeterminate color="primary" size="64"></v-progress-circular>
    </div>

    <!-- 错误状态 -->
    <v-card v-else-if="error" class="error-card">
      <v-card-text class="text-center">
        <v-icon size="64" color="error" class="mb-4">mdi-alert-circle</v-icon>
        <h3 class="text-h6 mb-2">{{ error }}</h3>
        <v-btn color="primary" @click="fetchNote" prepend-icon="mdi-refresh">重试</v-btn>
        <v-btn class="ml-2" @click="goBack" prepend-icon="mdi-arrow-left">返回</v-btn>
      </v-card-text>
    </v-card>

    <!-- 笔记内容 -->
    <div v-else-if="note" class="note-content">
      <!-- 工具栏 -->
      <v-card class="toolbar-card mb-4" elevation="2">
        <v-card-actions class="pa-3">
          <v-btn icon="mdi-arrow-left" variant="text" @click="goBack" title="返回"></v-btn>
          <v-spacer></v-spacer>
          
          <!-- 查看模式下的操作 -->
          <template v-if="!isEditing">
            <v-chip size="small" color="grey" class="mr-2">
              <v-icon start size="small">mdi-clock-outline</v-icon>
              创建于 {{ formatDate(note.created_at) }}
            </v-chip>
            <v-chip size="small" color="grey" class="mr-2">
              <v-icon start size="small">mdi-update</v-icon>
              更新于 {{ formatDate(note.updated_at) }}
            </v-chip>
            <v-btn
              color="primary"
              prepend-icon="mdi-pencil"
              @click="enterEditMode"
              :disabled="saving"
            >
              编辑
            </v-btn>
            <v-menu>
              <template v-slot:activator="{ props }">
                <v-btn icon="mdi-dots-vertical" variant="text" v-bind="props"></v-btn>
              </template>
              <v-list>
                <v-list-item @click="deleteNote" color="error">
                  <template v-slot:prepend>
                    <v-icon color="error">mdi-delete</v-icon>
                  </template>
                  <v-list-item-title>删除笔记</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-menu>
          </template>

          <!-- 编辑模式下的操作 -->
          <template v-else>
            <v-btn
              @click="cancelEdit"
              :disabled="saving"
              class="mr-2"
            >
              取消
            </v-btn>
            <v-btn
              color="primary"
              prepend-icon="mdi-content-save"
              @click="saveNote"
              :loading="saving"
              :disabled="!canSave"
            >
              保存
            </v-btn>
          </template>
        </v-card-actions>
      </v-card>

      <!-- 笔记标题和内容 -->
      <v-card class="content-card" elevation="2">
        <!-- 查看模式 -->
        <template v-if="!isEditing">
          <v-card-title class="note-title-view">
            <h1 class="text-h4 font-weight-bold">{{ note.title }}</h1>
          </v-card-title>
          <v-divider></v-divider>
          <v-card-text class="note-content-view">
            <div class="content-text" v-html="formatContent(note.content)"></div>
          </v-card-text>
        </template>

        <!-- 编辑模式 -->
        <template v-else>
          <v-card-text class="pa-6">
            <v-form @submit.prevent="saveNote">
              <v-text-field
                v-model="editForm.title"
                label="标题"
                placeholder="请输入笔记标题"
                variant="outlined"
                required
                class="mb-4"
                :rules="[v => !!v || '标题不能为空']"
                autofocus
              ></v-text-field>

              <v-textarea
                v-model="editForm.content"
                label="内容"
                placeholder="请输入笔记内容"
                variant="outlined"
                rows="15"
                auto-grow
                required
                :rules="[v => !!v || '内容不能为空']"
                class="content-textarea"
              ></v-textarea>
            </v-form>
          </v-card-text>
        </template>
      </v-card>
    </div>

    <!-- 删除确认对话框 -->
    <v-dialog v-model="showDeleteDialog" max-width="400">
      <v-card>
        <v-card-title class="text-h6">
          <v-icon color="error" class="mr-2">mdi-alert</v-icon>
          确认删除
        </v-card-title>
        <v-card-text>
          <p>确定要删除这篇笔记吗？</p>
          <p class="text-medium-emphasis text-caption mt-2">此操作无法撤销，请谨慎操作。</p>
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn @click="showDeleteDialog = false" :disabled="deleting">
            取消
          </v-btn>
          <v-btn color="error" @click="confirmDelete" :loading="deleting">
            删除
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- 保存成功提示 -->
    <v-snackbar v-model="showSaveSuccess" color="success" timeout="2000" location="top">
      <v-icon start>mdi-check-circle</v-icon>
      保存成功
    </v-snackbar>

    <!-- 保存失败提示 -->
    <v-snackbar v-model="showSaveError" color="error" timeout="3000" location="top">
      <v-icon start>mdi-alert-circle</v-icon>
      {{ saveErrorMessage }}
    </v-snackbar>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { trpc } from '../../trpc'
import { useMainStore } from '../../store/mainStore'

const router = useRouter()
const route = useRoute()
const mainStore = useMainStore()

interface Note {
  id: string
  title: string
  content: string
  created_at: string | Date
  updated_at: string | Date
}

const note = ref<Note | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)
const isEditing = ref(false)
const saving = ref(false)
const deleting = ref(false)
const showDeleteDialog = ref(false)
const showSaveSuccess = ref(false)
const showSaveError = ref(false)
const saveErrorMessage = ref('')

const editForm = ref({
  title: '',
  content: ''
})

// 是否可以保存（表单验证）
const canSave = computed(() => {
  return editForm.value.title.trim() !== '' && editForm.value.content.trim() !== ''
})

// 获取笔记ID
const noteId = computed(() => route.params.id as string)

// 获取笔记详情
const fetchNote = async () => {
  if (!noteId.value) {
    error.value = '笔记ID不存在'
    return
  }

  try {
    loading.value = true
    error.value = null
    const result = await trpc.notepad.getNoteById.query({ id: noteId.value }) as Note
    note.value = result
    // 初始化编辑表单
    editForm.value = {
      title: result.title,
      content: result.content
    }
  } catch (err: any) {
    console.error('获取笔记失败:', err)
    error.value = err?.message || '获取笔记失败，请稍后重试'
  } finally {
    loading.value = false
  }
}

// 进入编辑模式
const enterEditMode = () => {
  if (!note.value) return
  editForm.value = {
    title: note.value.title,
    content: note.value.content
  }
  isEditing.value = true
}

// 取消编辑
const cancelEdit = () => {
  if (!note.value) return
  // 恢复原始内容
  editForm.value = {
    title: note.value.title,
    content: note.value.content
  }
  isEditing.value = false
}

// 保存笔记
const saveNote = async () => {
  if (!canSave.value || !note.value) return

  try {
    saving.value = true
    const result = await trpc.notepad.updateNote.mutate({
      id: note.value.id,
      title: editForm.value.title.trim(),
      content: editForm.value.content.trim()
    }) as Note
    
    // 更新本地数据
    note.value = result
    isEditing.value = false
    showSaveSuccess.value = true
    
    // 触发主store刷新，以便列表页更新
    mainStore.triggerRefresh()
  } catch (err: any) {
    console.error('保存笔记失败:', err)
    saveErrorMessage.value = err?.message || '保存失败，请稍后重试'
    showSaveError.value = true
  } finally {
    saving.value = false
  }
}

// 删除笔记
const deleteNote = () => {
  showDeleteDialog.value = true
}

// 确认删除
const confirmDelete = async () => {
  if (!note.value) return

  try {
    deleting.value = true
    await trpc.notepad.deleteNote.mutate({ id: note.value.id })
    // 删除成功后返回笔记列表
    router.push('/notes')
    // 触发主store刷新
    mainStore.triggerRefresh()
  } catch (err: any) {
    console.error('删除笔记失败:', err)
    saveErrorMessage.value = err?.message || '删除失败，请稍后重试'
    showSaveError.value = true
    showDeleteDialog.value = false
  } finally {
    deleting.value = false
  }
}

// 返回上一页
const goBack = () => {
  router.back()
  // 如果无法返回，则跳转到笔记列表
  if (window.history.length <= 1) {
    router.push('/notes')
  }
}

// 格式化内容（将换行符转换为HTML）
const formatContent = (content: string) => {
  if (!content) return ''
  // 转义HTML特殊字符
  const escaped = content
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
  // 将换行符转换为<br>
  return escaped.replace(/\n/g, '<br>')
}

// 格式化日期
const formatDate = (dateString: string | Date) => {
  const date = typeof dateString === 'string' ? new Date(dateString) : dateString
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// 监听路由变化
watch(() => route.params.id, (newId) => {
  if (newId) {
    fetchNote()
  }
}, { immediate: false })

// 监听认证状态
watch(() => mainStore.authenticated, (authenticated) => {
  if (authenticated && noteId.value) {
    fetchNote()
  }
})

onMounted(() => {
  if (mainStore.authenticated) {
    fetchNote()
  }
})
</script>

<style scoped>
.note-detail-container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 20px;
}

.toolbar-card {
  border-radius: 8px;
}

.content-card {
  border-radius: 8px;
  min-height: 400px;
}

.note-title-view {
  padding: 32px 32px 24px;
  word-break: break-word;
}

.note-content-view {
  padding: 24px 32px 32px;
  min-height: 300px;
}

.content-text {
  font-size: 16px;
  line-height: 1.8;
  color: rgba(0, 0, 0, 0.87);
  white-space: pre-wrap;
  word-break: break-word;
}

.content-textarea {
  font-family: inherit;
}

.content-textarea :deep(.v-field__input) {
  font-size: 16px;
  line-height: 1.8;
}

.error-card {
  margin: 40px auto;
  max-width: 500px;
  border-radius: 8px;
}

/* 响应式设计 */
@media (max-width: 960px) {
  .note-detail-container {
    padding: 12px;
  }

  .note-title-view {
    padding: 24px 20px 16px;
  }

  .note-content-view {
    padding: 16px 20px 24px;
  }

  .content-text {
    font-size: 15px;
  }
}

/* 打印样式 */
@media print {
  .toolbar-card {
    display: none;
  }

  .content-card {
    box-shadow: none;
    border: 1px solid #ddd;
  }
}
</style>
