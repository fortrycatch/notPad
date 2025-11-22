<template>
    <v-dialog :model-value="modelValue" @update:model-value="$emit('update:modelValue', $event)" max-width="1200px" scrollable>
        <v-card>
            <v-card-title class="d-flex justify-space-between align-center">
                <span>图片处理参数配置</span>
                <v-btn
                    icon="mdi-close"
                    variant="text"
                    @click="$emit('update:modelValue', false)"
                ></v-btn>
            </v-card-title>
            <v-card-text class="pa-4">
                <v-row>
                    <!-- 左侧：参数配置 -->
                    <v-col cols="12" md="6">
                        <v-expansion-panels v-model="panel" multiple>
                            <!-- 图片缩放 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>图片缩放 (resize)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-select
                                        v-model="ossParams.resize.m"
                                        :items="['lfit', 'mfit', 'fill', 'pad', 'fixed', 'auto']"
                                        label="缩放模式"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-select>
                                    <v-text-field
                                        v-model.number="ossParams.resize.w"
                                        label="宽度 (w)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-text-field>
                                    <v-text-field
                                        v-model.number="ossParams.resize.h"
                                        label="高度 (h)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-text-field>
                                    <v-text-field
                                        v-model.number="ossParams.resize.l"
                                        label="长边 (l)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-text-field>
                                    <v-text-field
                                        v-model.number="ossParams.resize.s"
                                        label="短边 (s)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-text-field>
                                    <v-text-field
                                        v-model="ossParams.resize.limit"
                                        label="是否限制 (limit)"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 图片旋转 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>图片旋转 (rotate)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-text-field
                                        v-model.number="ossParams.rotate.value"
                                        label="旋转角度 (0-360)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 质量变换 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>质量变换 (quality)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-slider
                                        v-model="ossParams.quality.q"
                                        :min="1"
                                        :max="100"
                                        label="质量 (1-100)"
                                        step="1"
                                        hide-details
                                        class="mb-2"
                                    ></v-slider>
                                    <v-text-field
                                        v-model.number="ossParams.quality.q"
                                        type="number"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 格式转换 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>格式转换 (format)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-select
                                        v-model="ossParams.format.value"
                                        :items="['', 'jpg', 'png', 'webp', 'bmp', 'gif', 'tiff']"
                                        label="目标格式"
                                        density="compact"
                                        hide-details
                                    ></v-select>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 图片裁剪 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>自定义裁剪 (crop)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-text-field
                                        v-model.number="ossParams.crop.w"
                                        label="裁剪宽度 (w)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-text-field>
                                    <v-text-field
                                        v-model.number="ossParams.crop.h"
                                        label="裁剪高度 (h)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-text-field>
                                    <v-text-field
                                        v-model.number="ossParams.crop.x"
                                        label="X 坐标 (x)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-text-field>
                                    <v-text-field
                                        v-model.number="ossParams.crop.y"
                                        label="Y 坐标 (y)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 圆角矩形 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>圆角矩形 (rounded-corners)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-text-field
                                        v-model.number="ossParams.roundedCorners.r"
                                        label="圆角半径 (r)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 模糊效果 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>模糊效果 (blur)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-text-field
                                        v-model.number="ossParams.blur.r"
                                        label="模糊半径 (r, 1-50)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                        class="mb-2"
                                    ></v-text-field>
                                    <v-text-field
                                        v-model.number="ossParams.blur.s"
                                        label="标准差 (s, 1-50)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 亮度 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>亮度 (bright)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-slider
                                        v-model="ossParams.bright.value"
                                        :min="-100"
                                        :max="100"
                                        label="亮度 (-100 到 100)"
                                        step="1"
                                        hide-details
                                        class="mb-2"
                                    ></v-slider>
                                    <v-text-field
                                        v-model.number="ossParams.bright.value"
                                        type="number"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 对比度 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>对比度 (contrast)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-slider
                                        v-model="ossParams.contrast.value"
                                        :min="-100"
                                        :max="100"
                                        label="对比度 (-100 到 100)"
                                        step="1"
                                        hide-details
                                        class="mb-2"
                                    ></v-slider>
                                    <v-text-field
                                        v-model.number="ossParams.contrast.value"
                                        type="number"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 锐化 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>锐化 (sharpen)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-text-field
                                        v-model.number="ossParams.sharpen.value"
                                        label="锐化值 (50-399)"
                                        type="number"
                                        density="compact"
                                        hide-details
                                    ></v-text-field>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 图片翻转 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>图片翻转 (flip)</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-select
                                        v-model="ossParams.flip.value"
                                        :items="['', 'v', 'h']"
                                        label="翻转方向 (v=垂直, h=水平)"
                                        density="compact"
                                        hide-details
                                    ></v-select>
                                </v-expansion-panel-text>
                            </v-expansion-panel>

                            <!-- 自定义参数 -->
                            <v-expansion-panel>
                                <v-expansion-panel-title>自定义参数</v-expansion-panel-title>
                                <v-expansion-panel-text>
                                    <v-textarea
                                        v-model="ossParams.custom.value"
                                        label="自定义 x-oss-process 参数"
                                        placeholder="例如: image/resize,w_200/rotate,90/quality,q_80"
                                        rows="3"
                                        hide-details
                                    ></v-textarea>
                                </v-expansion-panel-text>
                            </v-expansion-panel>
                        </v-expansion-panels>

                        <v-btn
                            color="error"
                            variant="outlined"
                            block
                            class="mt-4"
                            @click="resetOssParams"
                        >
                            重置所有参数
                        </v-btn>
                    </v-col>

                    <!-- 右侧：预览 -->
                    <v-col cols="12" md="6">
                        <div class="preview-container">
                            <div class="text-h6 mb-2">预览效果</div>
                            <v-img
                                :src="processedImageUrl"
                                :alt="imageName"
                                max-height="400px"
                                contain
                                class="mb-4 preview-image"
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
                            
                            <v-divider class="my-4"></v-divider>
                            
                            <div class="text-subtitle-2 mb-2">生成的 URL</div>
                            <v-textarea
                                :model-value="processedImageUrl"
                                readonly
                                rows="3"
                                hide-details
                                class="mb-2"
                            ></v-textarea>
                            
                            <div class="text-subtitle-2 mb-2">x-oss-process 参数</div>
                            <v-textarea
                                :model-value="ossProcessParam"
                                readonly
                                rows="2"
                                hide-details
                                class="mb-4"
                            ></v-textarea>

                            <v-btn
                                color="primary"
                                prepend-icon="mdi-content-copy"
                                block
                                class="mb-2"
                                @click="copyProcessedUrl"
                            >
                                复制处理后的链接
                            </v-btn>
                            <v-btn
                                color="primary"
                                prepend-icon="mdi-content-copy"
                                block
                                class="mb-2"
                                @click="copyProcessedMarkdown"
                            >
                                复制 Markdown
                            </v-btn>
                            <v-btn
                                color="success"
                                prepend-icon="mdi-download"
                                block
                                @click="downloadProcessedImage"
                            >
                                下载处理后的图片
                            </v-btn>
                        </div>
                    </v-col>
                </v-row>
            </v-card-text>
            <v-card-actions>
                <v-spacer></v-spacer>
                <v-btn @click="$emit('update:modelValue', false)">关闭</v-btn>
            </v-card-actions>
        </v-card>
    </v-dialog>
</template>

<script lang="ts">
export default {
    name: 'OssProcessDialog'
}
</script>

<script lang="ts" setup>
import { ref, computed } from 'vue'

const props = defineProps<{
    modelValue: boolean
    imageUrl: string
    imageName: string
}>()

defineEmits(['update:modelValue'])

const panel = ref([0])

// OSS 参数配置
const ossParams = ref({
    resize: {
        m: '',
        w: null as number | null,
        h: null as number | null,
        l: null as number | null,
        s: null as number | null,
        limit: ''
    },
    rotate: {
        value: null as number | null
    },
    quality: {
        q: 100
    },
    format: {
        value: ''
    },
    crop: {
        w: null as number | null,
        h: null as number | null,
        x: null as number | null,
        y: null as number | null
    },
    roundedCorners: {
        r: null as number | null
    },
    blur: {
        r: null as number | null,
        s: null as number | null
    },
    bright: {
        value: 0
    },
    contrast: {
        value: 0
    },
    sharpen: {
        value: null as number | null
    },
    flip: {
        value: ''
    },
    custom: {
        value: ''
    }
})

// 构建 x-oss-process 参数
const ossProcessParam = computed(() => {
    const parts: string[] = []
    
    // 如果有自定义参数，直接使用
    if (ossParams.value.custom.value.trim()) {
        return ossParams.value.custom.value.trim()
    }
    
    // 图片缩放
    const resizeParts: string[] = []
    if (ossParams.value.resize.m) resizeParts.push(`m_${ossParams.value.resize.m}`)
    if (ossParams.value.resize.w !== null) resizeParts.push(`w_${ossParams.value.resize.w}`)
    if (ossParams.value.resize.h !== null) resizeParts.push(`h_${ossParams.value.resize.h}`)
    if (ossParams.value.resize.l !== null) resizeParts.push(`l_${ossParams.value.resize.l}`)
    if (ossParams.value.resize.s !== null) resizeParts.push(`s_${ossParams.value.resize.s}`)
    if (ossParams.value.resize.limit) resizeParts.push(`limit_${ossParams.value.resize.limit}`)
    if (resizeParts.length > 0) {
        parts.push(`resize,${resizeParts.join(',')}`)
    }
    
    // 图片旋转
    if (ossParams.value.rotate.value !== null) {
        parts.push(`rotate,${ossParams.value.rotate.value}`)
    }
    
    // 质量变换
    if (ossParams.value.quality.q !== 100) {
        parts.push(`quality,q_${ossParams.value.quality.q}`)
    }
    
    // 格式转换
    if (ossParams.value.format.value) {
        parts.push(`format,${ossParams.value.format.value}`)
    }
    
    // 图片裁剪
    const cropParts: string[] = []
    if (ossParams.value.crop.w !== null) cropParts.push(`w_${ossParams.value.crop.w}`)
    if (ossParams.value.crop.h !== null) cropParts.push(`h_${ossParams.value.crop.h}`)
    if (ossParams.value.crop.x !== null) cropParts.push(`x_${ossParams.value.crop.x}`)
    if (ossParams.value.crop.y !== null) cropParts.push(`y_${ossParams.value.crop.y}`)
    if (cropParts.length > 0) {
        parts.push(`crop,${cropParts.join(',')}`)
    }
    
    // 圆角矩形
    if (ossParams.value.roundedCorners.r !== null) {
        parts.push(`rounded-corners,r_${ossParams.value.roundedCorners.r}`)
    }
    
    // 模糊效果
    const blurParts: string[] = []
    if (ossParams.value.blur.r !== null) blurParts.push(`r_${ossParams.value.blur.r}`)
    if (ossParams.value.blur.s !== null) blurParts.push(`s_${ossParams.value.blur.s}`)
    if (blurParts.length > 0) {
        parts.push(`blur,${blurParts.join(',')}`)
    }
    
    // 亮度
    if (ossParams.value.bright.value !== 0) {
        parts.push(`bright,${ossParams.value.bright.value}`)
    }
    
    // 对比度
    if (ossParams.value.contrast.value !== 0) {
        parts.push(`contrast,${ossParams.value.contrast.value}`)
    }
    
    // 锐化
    if (ossParams.value.sharpen.value !== null) {
        parts.push(`sharpen,${ossParams.value.sharpen.value}`)
    }
    
    // 图片翻转
    if (ossParams.value.flip.value) {
        parts.push(`flip,${ossParams.value.flip.value}`)
    }
    
    return parts.length > 0 ? `image/${parts.join('/')}` : ''
})

// 处理后的图片 URL
const processedImageUrl = computed(() => {
    const baseUrl = props.imageUrl
    if (!ossProcessParam.value) {
        return baseUrl
    }
    const separator = baseUrl.includes('?') ? '&' : '?'
    return `${baseUrl}${separator}x-oss-process=${ossProcessParam.value}`
})

// 重置所有参数
const resetOssParams = () => {
    ossParams.value = {
        resize: { m: '', w: null, h: null, l: null, s: null, limit: '' },
        rotate: { value: null },
        quality: { q: 100 },
        format: { value: '' },
        crop: { w: null, h: null, x: null, y: null },
        roundedCorners: { r: null },
        blur: { r: null, s: null },
        bright: { value: 0 },
        contrast: { value: 0 },
        sharpen: { value: null },
        flip: { value: '' },
        custom: { value: '' }
    }
}

// 复制处理后的链接
const copyProcessedUrl = async () => {
    try {
        await navigator.clipboard.writeText(processedImageUrl.value)
    } catch (err) {
        console.error('复制失败:', err)
    }
}

// 复制处理后的 Markdown
const copyProcessedMarkdown = async () => {
    try {
        const markdown = `![${props.imageName}](${processedImageUrl.value})`
        await navigator.clipboard.writeText(markdown)
    } catch (err) {
        console.error('复制失败:', err)
    }
}

// 下载处理后的图片
const downloadProcessedImage = () => {
    const link = document.createElement('a')
    link.href = processedImageUrl.value
    link.download = props.imageName
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
}
</script>

<style scoped>
.preview-container {
    position: sticky;
    top: 20px;
}

.preview-image {
    border: 1px solid rgba(0, 0, 0, 0.12);
    border-radius: 4px;
}
</style>
