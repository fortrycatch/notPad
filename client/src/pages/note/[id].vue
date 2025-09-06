<template>
  <v-container>
    <v-row>
      <v-col cols="12">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
          <v-btn
            prepend-icon="mdi-arrow-left"
            
            @click="goBack"
          >
            返回
          </v-btn>
          <div class="tool-bar">
            <v-btn
              prepend-icon="mdi-pencil"
              color="primary"
              @click="editMode = true"
              v-if="!editMode"
            >
              编辑
            </v-btn>
            <v-btn
              prepend-icon="mdi-delete"
              color="error"
              @click="showDeleteDialog = true"
              v-if="!editMode"
            >
              删除
            </v-btn>
          </div>
        </div>
      </v-col>
    </v-row>

    <v-row v-if="loading">
      <v-col cols="12" style="text-align: center;">
        <v-progress-circular
          indeterminate
          color="primary"
          size="64"
        ></v-progress-circular>
        <p style="margin-top: 16px;" class="text-body-1">加载中...</p>
      </v-col>
    </v-row>

    <v-row v-else-if="note">
      <v-col cols="12">
        <v-card elevation="2">
          <div v-if="!editMode" class="view-mode">
            <v-card-title class="text-h4 font-weight-bold" style="padding: 24px;">
              {{ note.title }}
            </v-card-title>
            
            <v-card-subtitle style="padding: 24px; padding-top: 0;">
              <div style="display: flex; gap: 16px;">
                <v-chip
                  size="small"
                  color="grey"
                  
                  prepend-icon="mdi-calendar-plus"
                >
                  创建时间: {{ formatDate(note.created_at) }}
                </v-chip>
                <v-chip
                  size="small"
                  color="grey"
                  
                  prepend-icon="mdi-calendar-edit"
                >
                  更新时间: {{ formatDate(note.updated_at) }}
                </v-chip>
              </div>
            </v-card-subtitle>

            <v-card-text style="padding: 24px; padding-top: 0;">
              <div class="text-body-1" style="white-space: pre-wrap; line-height: 1.8;">
                {{ note.content }}
              </div>
            </v-card-text>
          </div>

          <div v-else class="edit-mode" style="padding: 24px;">
            <v-form @submit.prevent="saveChanges">
              <v-text-field
                v-model="editForm.title"
                label="标题"
                placeholder="请输入笔记标题"
                
                required
                style="margin-bottom: 16px;"
              ></v-text-field>

              <v-textarea
                v-model="editForm.content"
                label="内容"
                placeholder="请输入笔记内容"
                
                rows="20"
                auto-grow
                required
              ></v-textarea>
            </v-form>

            <div style="display: flex; justify-content: flex-end; gap: 8px; margin-top: 24px;">
              <v-btn
                
                @click="cancelEdit"
              >
                取消
              </v-btn>
              <v-btn
                color="primary"
                @click="saveChanges"
                :loading="saving"
              >
                保存
              </v-btn>
            </div>
          </div>
        </v-card>
      </v-col>
    </v-row>

    <v-row v-else>
      <v-col cols="12" style="text-align: center;">
        <v-card class="error-state" elevation="0">
          <v-card-text>
            <v-icon size="64" color="error" style="margin-bottom: 16px;">
              mdi-alert-circle-outline
            </v-icon>
            <h2 class="text-h5" style="margin-bottom: 8px;">笔记不存在</h2>
            <p class="text-body-2 text-medium-emphasis" style="margin-bottom: 16px;">
              该笔记可能已被删除或不存在
            </p>
            <v-btn
              prepend-icon="mdi-arrow-left"
              
              @click="goBack"
            >
              返回列表
            </v-btn>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <!-- 删除确认对话框 -->
    <v-dialog v-model="showDeleteDialog" max-width="400">
      <v-card>
        <v-card-title class="text-h6">
          <v-icon color="error" style="margin-right: 8px;">mdi-alert</v-icon>
          确认删除
        </v-card-title>
        <v-card-text>
          确定要删除这篇笔记吗？此操作无法撤销。
        </v-card-text>
        <v-card-actions>
          <v-spacer></v-spacer>
          <v-btn
            
            @click="showDeleteDialog = false"
          >
            取消
          </v-btn>
          <v-btn
            color="error"
            @click="deleteNote"
            :loading="deleting"
          >
            删除
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { server } from '../../server'
const route = useRoute()
const router = useRouter()

interface Note {
  id: string
  title: string
  content: string
  created_at: string
  updated_at: string
  userId: string
}

const note = ref<Note | null>(null)
const loading = ref(true)
const editMode = ref(false)
const showDeleteDialog = ref(false)
const saving = ref(false)
const deleting = ref(false)
const editForm = ref({
  title: '',
  content: ''
})

// 获取笔记详情
const fetchNote = async () => {
  try {
    const id = route.params.id as string
    const result = await server.notepad.getNoteById.query({ id })
    note.value = result
    editForm.value = {
      title: result.title,
      content: result.content
    }
  } catch (error) {
    console.error('获取笔记详情失败:', error)
    note.value = null
  } finally {
    loading.value = false
  }
}

// 返回上一页
const goBack = () => {
  router.push('/notes')
}

// 删除笔记
const deleteNote = async () => {
  if (!note.value) return
  
  try {
    deleting.value = true
    await server.notepad.deleteNote.mutate({ id: note.value.id })
    router.push('/notes')
  } catch (error) {
    console.error('删除笔记失败:', error)
  } finally {
    deleting.value = false
  }
}

// 取消编辑
const cancelEdit = () => {
  editMode.value = false
  if (note.value) {
    editForm.value = {
      title: note.value.title,
      content: note.value.content
    }
  }
}

// 保存更改
const saveChanges = async () => {
  if (!note.value || !editForm.value.title.trim() || !editForm.value.content.trim()) {
    return
  }

  try {
    saving.value = true
    const updatedNote = await server.notepad.updateNote.mutate({
      id: note.value.id,
      title: editForm.value.title,
      content: editForm.value.content
    })
    
    note.value = updatedNote
    editMode.value = false
  } catch (error) {
    console.error('保存笔记失败:', error)
  } finally {
    saving.value = false
  }
}

// 格式化日期
const formatDate = (dateString: string) => {
  return new Date(dateString).toLocaleString('zh-CN')
}

onMounted(() => {
  fetchNote()
})
</script>

<style scoped>
.error-state {
  padding: 60px 20px;
}
.tool-bar {
  >* {
    margin-left: 8px;
  }
}
</style>
