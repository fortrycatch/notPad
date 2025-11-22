<template>
    <v-card class="image-card" elevation="2" @click="previewImage">
        <v-img
            :src="imageUrl + '?x-oss-process=image/resize,w_300'"
            :alt="image.name"
            cover
            class="image-preview"
        >
            <template v-slot:placeholder>
                <div class="d-flex align-center justify-center fill-height">
                    <v-progress-circular
                        color="grey-lighten-5"
                        indeterminate
                    ></v-progress-circular>
                </div>
            </template>
        </v-img>
        
        <v-card-text class="pa-2">
            <div class="image-info">
                <span>{{ formatFileSize(image.size) }}</span>
                <span>{{ formatDate(image.created_at) }}</span>
            </div>
        </v-card-text>
        
        <div class="action">
            <v-btn
                size="x-small"
                variant="text"
                icon="mdi-download"
                @click.stop="downloadImage"
                title="下载"
            ></v-btn>
            <v-btn
                size="x-small"
                variant="text"
                icon="mdi-eye"
                @click.stop="previewImage"
                title="预览"
            ></v-btn>
            <v-btn
                size="x-small"
                variant="text"
                icon="mdi-tune"
                @click.stop="showOssConfig = true"
                title="图片处理"
            ></v-btn>
            <v-spacer></v-spacer>
        </div>
    </v-card>
    
    <!-- 图片预览对话框 -->
    <v-dialog v-model="showPreview" max-width="90vw" max-height="90vh">
        <v-card>
            <v-card-title class="d-flex justify-space-between align-center">
                <span>{{ getImageName(image.name) }}</span>
                <v-btn
                    icon="mdi-close"
                    variant="text"
                    @click="showPreview = false"
                ></v-btn>
            </v-card-title>
            <v-card-text class="pa-0">
                <v-img
                    :src="imageUrl"
                    :alt="image.name"
                    max-height="70vh"
                    contain
                ></v-img>
            </v-card-text>
            <v-card-actions>
                <v-btn @click="downloadImage" prepend-icon="mdi-download">
                    下载
                </v-btn>
                <v-btn @click="copyImageUrl" prepend-icon="mdi-content-copy">
                    图片链接
                </v-btn>
                <v-btn @click="copyImageMarkDown" prepend-icon="mdi-content-copy">
                    markdown
                </v-btn>
                <v-btn 
                    @click="showOssConfig = true" 
                    prepend-icon="mdi-tune"
                    title="图片处理"
                >
                    图片处理
                </v-btn>
                <v-spacer></v-spacer>
                <v-btn @click="showPreview = false">关闭</v-btn>
            </v-card-actions>
        </v-card>
    </v-dialog>

    <!-- OSS 图片处理配置组件 -->
    <OssProcessDialog
        v-model="showOssConfig"
        :image-url="imageUrl"
        :image-name="getImageName(image.name)"
    />
</template>

<script lang="ts" setup>
import { ref } from 'vue'
import OssProcessDialog from './OssProcessDialog.vue'

const props = defineProps<{
    image: any
}>()
const imageUrl = 'https://monika.jkloli.net/' + props.image.url
const showPreview = ref(false)
const showOssConfig = ref(false)

// 获取图片名称（去掉路径前缀）
const getImageName = (fullName: string) => {
    return fullName.split('/').pop() || fullName
}

// 格式化文件大小
const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
}

// 格式化日期
const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('zh-CN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    })
}

// 获取类型颜色
const getTypeColor = (type: string) => {
    switch (type) {
        case 'Normal':
            return 'primary'
        case 'Archive':
            return 'orange'
        case 'IA':
            return 'green'
        default:
            return 'grey'
    }
}

// 预览图片
const previewImage = () => {
    showPreview.value = true
}

// 下载图片
const downloadImage = () => {
    const link = document.createElement('a')
    link.href = props.image.url
    link.download = getImageName(props.image.name)
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
}

const copyImageUrl = () => {
    navigator.clipboard.writeText(imageUrl)
}

const copyImageMarkDown = () => {
    navigator.clipboard.writeText(`![${getImageName(props.image.name)}](${imageUrl})`)
}
</script>

<style scoped>
.image-card {
    cursor: pointer;
    transition: transform 0.2s ease-in-out;
    /* max-width: 500px; */
}

.image-preview {
    aspect-ratio: 16/9;
    border-radius: 4px 4px 0 0;
}

.image-name {
    font-weight: 500;
    font-size: 0.875rem;
    line-height: 1.2;
    margin-bottom: 4px;
}

.image-info {
    line-height: 1.2;
}

.image-info > * {
    margin-right: 5px;
}

.image-info span {
    margin-bottom: 2px;
}
.action {
    padding: 0;
    height: 30px;
}
</style>