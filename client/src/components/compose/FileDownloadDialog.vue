<template>
  <v-dialog
    :model-value="modelValue"
    max-width="480"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <v-card class="file-dialog">
      <v-card-title class="file-header">
        <v-avatar size="48" color="surface-variant" variant="flat" rounded="lg">
          <v-icon size="24">{{ fileIcon }}</v-icon>
        </v-avatar>
        <div class="file-header__meta">
          <div class="file-name">{{ fileName }}</div>
          <div v-if="fileSize > 0" class="file-meta-line">{{ formatFileSize(fileSize) }}</div>
        </div>
        <v-btn icon="mdi-close" variant="text" @click="close" />
      </v-card-title>

      <v-card-text v-if="!fileUrl" class="d-flex align-center justify-center pa-6">
        <v-progress-circular indeterminate color="primary" size="28" />
        <span class="ml-3 text-body-2 text-medium-emphasis">正在获取下载链接...</span>
      </v-card-text>

      <v-card-actions class="file-actions">
        <v-btn
          color="primary"
          prepend-icon="mdi-download"
          :disabled="!fileUrl"
          @click="download"
        >
          下载
        </v-btn>
        <v-btn
          prepend-icon="mdi-link-variant"
          :disabled="!fileUrl"
          @click="copyUrl"
        >
          复制链接
        </v-btn>
        <v-spacer />
        <v-btn variant="text" @click="close">关闭</v-btn>
      </v-card-actions>
    </v-card>
  </v-dialog>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { formatFileSize, getFileIcon } from '../../utils/format'
import { downloadUrl } from '../../utils/download'

const props = withDefaults(defineProps<{
  modelValue: boolean
  fileName: string
  fileUrl: string
  fileSize?: number
  mimeType?: string
}>(), {
  fileSize: 0,
  mimeType: ''
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void
}>()

const close = () => emit('update:modelValue', false)

const fileIcon = computed(() => getFileIcon(props.mimeType))

const download = () => {
  if (!props.fileUrl) return
  downloadUrl(props.fileUrl)
}

const copyUrl = () => {
  if (props.fileUrl) {
    navigator.clipboard.writeText(props.fileUrl)
  }
}
</script>

<style scoped>
.file-header {
  display: flex;
  align-items: center;
  gap: 14px;
}

.file-header__meta {
  flex: 1;
  min-width: 0;
}

.file-name {
  font-size: 17px;
  font-weight: 600;
  word-break: break-word;
}

.file-meta-line {
  margin-top: 2px;
  font-size: 13px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.file-actions {
  flex-wrap: wrap;
  gap: 8px;
  padding: 0 24px 24px;
}
</style>
