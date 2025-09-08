<template>
    <div>
        <div class="row">
            <v-btn-toggle v-model="toggle" border divided class="btn-toggle">
                <v-btn icon="mdi-clock-time-eight-outline"></v-btn>
                <v-btn icon="mdi-clock-time-eight"></v-btn>
                <v-btn icon="mdi-format-font-size-decrease"></v-btn>
            </v-btn-toggle>
            <div class="row">
                <div>
                    <v-text-field v-model="search" label="搜索" append-inner-icon="mdi-magnify" density="compact"
                        variant="outlined" :loading="loading" hide-details single-line />
                </div>
                <v-btn @click="showUploadDialog = true" color="primary">上传图片(可直接粘贴)</v-btn>
            </div>
        </div>
        <div class="images">
            <ImageCard v-for="image in list" :key="image.url" :image="image" />
        </div>
        <div class="pagination">
            <v-btn @click="loadMore">加载更多</v-btn>
        </div>
    </div>
    <v-dialog v-model="showUploadDialog" max-width="600">
        <v-card>
            <v-card-title>上传图片</v-card-title>
            <v-card-text>
                <v-file-input v-model="file" label="选择/拖动图片于此" />
            </v-card-text>
            <v-card-actions>
                <v-btn @click="showUploadDialog = false">取消</v-btn>
                <v-btn @click="uploadImage">上传</v-btn>
            </v-card-actions>
        </v-card>
    </v-dialog>
    <v-alert v-if="showAlert" type="warning" class="toast" title="提示" :text="alertMessage"></v-alert>
</template>
<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue';
import { server } from '../server';
import ImageCard from '../components/compose/ImageCard.vue';
const showUploadDialog = ref(false);
const file = ref<File | null>(null);
const page = ref(1)
const showAlert = ref(false)
const alertMessage = ref('')
const toggle = ref(0)
const search = ref('')
const loading = ref(false)
const showAlert3s = function (message: string) {
    showAlert.value = true
    alertMessage.value = message
    setTimeout(() => {
        showAlert.value = false
    }, 3000)
}
const uploadImage = async () => {
    if (!file.value) {
        showAlert3s('请选择文件')
        return
    }
    const uploadUrl = await server.image_bed.getUploadUrl.query({
        filename: file.value.name,
        type: file.value.type
    })
    const res = await fetch(uploadUrl.url, {
        method: 'PUT',
        body: file.value,
    })
    if (res.ok) {
        const info = await server.image_bed.addImage.mutate({
            name: file.value.name,
            filename: uploadUrl.filename,
            remark: ''
        })
        getList()
        showUploadDialog.value = false
    }
}
const list = ref<any[]>([])
function pasteHandler(e: ClipboardEvent) {
    e.preventDefault();
    if (e.clipboardData?.items[0]) {
        const pasteFile = e.clipboardData?.items[0].getAsFile() || e.clipboardData?.items[1].getAsFile()
        if (pasteFile) {
            file.value = pasteFile
            showUploadDialog.value = true
        } else {
            // console.log(e.clipboardData?.items[1])
            showAlert3s('应该粘贴一个文件，找不到文件')
        }
    } else {
        showAlert3s('应该粘贴一个文件')
    }
}
async function getList() {
    list.value = await server.image_bed.list.query({
        user_id: 'admin',
        offset: 0,
        sort: toggle.value == 0 ? 'time_desc' : toggle.value == 1 ? 'time' : 'name',
        search: search.value
    })
}
async function loadMore() {
    const more = await server.image_bed.list.query({
        user_id: 'admin',
        offset: page.value
    })
    if (more.length == 0) {
        showAlert3s('没有更多了')
        return
    }
    list.value.push(...more)
    page.value++
}
watch(toggle, (newVal) => {
    getList()
})
let time: number | null = null
watch(search, async (newVal) => {
    if (!time || time + 1000 < Date.now()) {
        time = Date.now()
        setTimeout(async () => {
            console.log('search')
            loading.value = true
            await getList()
            loading.value = false
        }, 1000)
    }
})
onMounted(async () => {
    document.addEventListener('paste', pasteHandler)
    getList()
})
onUnmounted(() => {
    document.removeEventListener('paste', pasteHandler)
})
</script>
<style scoped>
.row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 16px;
}

.toast {
    position: fixed;
    bottom: 10px;
    right: 10px;
}

.images {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 16px;
    padding: 16px 0;
}

.btn-toggle {
    scrollbar-width: none;
    -ms-overflow-style: none;
}
</style>