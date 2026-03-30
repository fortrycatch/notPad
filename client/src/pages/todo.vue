<template>
  <div class="todo-container">
    <div class="todo-header">
      <div class="page-head">
        <div class="page-icon">
          <v-icon icon="mdi-checkbox-marked-circle-outline" size="22" />
        </div>
        <div class="page-title">待办</div>
      </div>
    </div>

    <div v-if="listsLoading" class="d-flex justify-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </div>

    <div v-else class="todo-layout">
      <aside class="todo-sidebar" :class="{ open: sidebarOpen }">
        <div class="sidebar-head">
          <span class="sidebar-label">列表</span>
          <v-btn icon="mdi-plus" variant="text" size="x-small" @click="openCreateList" />
        </div>
        <v-divider />
        <div v-if="lists.length === 0" class="sidebar-empty text-medium-emphasis">
          暂无列表
        </div>
        <div v-else class="sidebar-scroll">
          <template v-for="(l, i) in lists" :key="l.id">
            <v-divider v-if="i > 0" />
            <div
              class="sidebar-item"
              :class="{ active: activeListId === l.id }"
              @click="selectList(l.id)"
            >
              <v-icon size="10" :color="l.color">mdi-circle</v-icon>
              <span class="sidebar-item-name">{{ l.name }}</span>
            </div>
          </template>
        </div>
      </aside>

      <div v-if="sidebarOpen" class="sidebar-backdrop" @click="sidebarOpen = false" />

      <main class="todo-main">
        <div v-if="!activeList" class="empty-state">
          <v-icon size="48" color="primary" class="mb-3">mdi-checkbox-marked-circle-outline</v-icon>
          <p class="text-medium-emphasis">
            {{ lists.length === 0 ? '创建一个列表开始管理待办' : '选择一个列表' }}
          </p>
          <v-btn
            v-if="lists.length === 0"
            variant="tonal"
            color="primary"
            class="mt-3"
            prepend-icon="mdi-plus"
            @click="openCreateList"
          >
            新建列表
          </v-btn>
        </div>

        <template v-else>
          <div class="list-head">
            <v-btn
              class="sidebar-toggle"
              icon="mdi-menu"
              variant="text"
              size="small"
              @click="sidebarOpen = !sidebarOpen"
            />
            <v-icon :color="activeList.color" size="18">mdi-circle</v-icon>
            <span class="list-name">{{ activeList.name }}</span>
            <v-chip size="x-small" variant="tonal" class="ml-1">{{ doneCount }}/{{ items.length }}</v-chip>
            <v-spacer />
            <v-menu>
              <template #activator="{ props }">
                <v-btn v-bind="props" icon="mdi-dots-vertical" variant="text" size="small" />
              </template>
              <v-list density="compact" min-width="160">
                <v-list-item prepend-icon="mdi-pencil" @click="openEditList">
                  <v-list-item-title>编辑列表</v-list-item-title>
                </v-list-item>
                <v-list-item prepend-icon="mdi-delete" color="error" @click="confirmDeleteList = true">
                  <v-list-item-title>删除列表</v-list-item-title>
                </v-list-item>
              </v-list>
            </v-menu>
          </div>

          <v-divider />

          <div class="add-item-row">
            <v-text-field
              v-model="newItemTitle"
              placeholder="添加待办..."
              variant="plain"
              density="comfortable"
              hide-details
              class="flex-grow-1"
              @keydown.enter="quickAddItem"
            />
            <v-btn icon="mdi-arrow-expand" variant="text" size="small" title="详细创建" @click="openCreateItem" />
            <v-btn icon="mdi-plus" variant="text" size="small" :disabled="!newItemTitle.trim()" @click="quickAddItem" />
          </div>

          <v-divider />

          <div v-if="itemsLoading" class="d-flex justify-center py-8">
            <v-progress-circular indeterminate color="primary" size="28" />
          </div>
          <v-list v-else-if="items.length > 0" class="todo-items-list" bg-color="transparent">
            <template v-for="(item, i) in items" :key="item.id">
              <v-divider v-if="i > 0" />
              <v-list-item class="todo-item" @click="openEditItem(item)">
                <template #prepend>
                  <v-checkbox-btn
                    :model-value="!!item.done"
                    :color="item.color || activeList.color"
                    @click.stop
                    @update:model-value="toggleDone(item)"
                  />
                </template>
                <div class="todo-item-body">
                  <div
                    class="todo-item-title"
                    :class="{ 'text-decoration-line-through text-medium-emphasis': item.done }"
                  >
                    {{ item.title }}
                  </div>
                  <div v-if="item.description" class="todo-item-desc text-medium-emphasis">
                    {{ item.description }}
                  </div>
                  <div v-if="item.refs.length > 0" class="todo-item-refs">
                    <button
                      v-for="r in item.refs"
                      :key="refKey(r)"
                      type="button"
                      class="todo-ref"
                      :class="`is-${r.type}`"
                      @click.stop="goRef(r)"
                    >
                      <img
                        v-if="refThumbSrc(r)"
                        :src="refThumbSrc(r)!"
                        :alt="r.title"
                        class="todo-ref-thumb"
                      >
                      <v-icon v-else size="14" :icon="refIcon(r)" color="primary" />
                      <span class="todo-ref-label">{{ r.title }}</span>
                    </button>
                  </div>
                </div>
                <template #append>
                  <v-btn icon="mdi-dots-vertical" variant="text" size="x-small" @click.stop="openItemMenu(item, $event)" />
                </template>
              </v-list-item>
            </template>
          </v-list>
          <div v-else class="empty-items text-medium-emphasis">
            列表为空，添加第一个待办吧
          </div>
        </template>
      </main>
    </div>

    <!-- Create / Edit list dialog -->
    <v-dialog v-model="showListDialog" max-width="420">
      <v-card>
        <v-card-title class="dialog-title">{{ listDialogEdit ? '编辑列表' : '新建列表' }}</v-card-title>
        <v-card-text class="d-flex flex-column ga-3">
          <v-text-field
            v-model="listForm.name"
            label="名称"
            variant="outlined"
            density="comfortable"
            hide-details
            autofocus
            @keydown.enter="submitListDialog"
          />
          <div>
            <div class="text-caption text-medium-emphasis mb-1">颜色</div>
            <div class="color-row">
              <div
                v-for="c in COLORS"
                :key="c"
                class="color-dot"
                :class="{ active: listForm.color === c }"
                :style="{ background: c }"
                @click="listForm.color = c"
              />
            </div>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="showListDialog = false">取消</v-btn>
          <v-btn color="primary" :loading="listSaving" @click="submitListDialog">
            {{ listDialogEdit ? '保存' : '创建' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Delete list confirm -->
    <v-dialog v-model="confirmDeleteList" max-width="360">
      <v-card>
        <v-card-title class="text-error">删除列表？</v-card-title>
        <v-card-text>将同时删除列表内所有待办，此操作不可恢复。</v-card-text>
        <v-card-actions>
          <v-spacer />
          <v-btn variant="text" @click="confirmDeleteList = false">取消</v-btn>
          <v-btn color="error" variant="flat" :loading="listSaving" @click="submitDeleteList">删除</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Create / Edit item dialog -->
    <v-dialog v-model="showItemDialog" max-width="560">
      <v-card>
        <v-card-title class="d-flex justify-space-between align-center">
          <span class="dialog-title">{{ itemDialogEdit ? '编辑待办' : '创建待办' }}</span>
          <v-btn icon="mdi-close" variant="text" @click="showItemDialog = false" />
        </v-card-title>
        <v-card-text class="item-dialog-body">
          <v-text-field
            v-model="itemForm.title"
            label="标题"
            variant="outlined"
            density="comfortable"
            hide-details
            autofocus
          />
          <v-textarea
            v-model="itemForm.description"
            label="描述（可选）"
            variant="outlined"
            density="comfortable"
            rows="3"
            hide-details
            no-resize
          />
          <div>
            <div class="text-caption text-medium-emphasis mb-1">颜色（留空继承列表色）</div>
            <div class="color-row">
              <div
                class="color-dot"
                :class="{ active: !itemForm.color }"
                style="background: transparent; border: 2px dashed rgba(128,128,128,0.4)"
                @click="itemForm.color = null"
              />
              <div
                v-for="c in COLORS"
                :key="c"
                class="color-dot"
                :class="{ active: itemForm.color === c }"
                :style="{ background: c }"
                @click="itemForm.color = c"
              />
            </div>
          </div>

          <div>
            <div class="text-subtitle-2 mb-2">关联资源</div>
            <div v-if="itemForm.refs.length > 0" class="ref-editor-list mb-2">
              <div
                v-for="r in itemForm.refs"
                :key="refKey(r)"
                class="ref-editor-item"
              >
                <div class="ref-editor-main">
                  <img
                    v-if="refThumbSrc(r)"
                    :src="refThumbSrc(r)!"
                    :alt="r.title"
                    class="ref-editor-thumb"
                  >
                  <div v-else class="ref-editor-note-icon">
                    <v-icon size="16" color="primary" :icon="refIcon(r)" />
                  </div>
                  <div class="ref-editor-text">
                    <div class="ref-editor-title">{{ r.title }}</div>
                    <div class="ref-editor-sub">{{ refKindLabel(r) }}</div>
                  </div>
                </div>
                <v-btn icon="mdi-close" variant="text" size="x-small" @click="removeRefFromForm(r)" />
              </div>
            </div>
            <v-btn variant="tonal" size="small" prepend-icon="mdi-link-plus" @click="openResourcePicker">
              添加关联
            </v-btn>
          </div>
        </v-card-text>
        <v-card-actions>
          <v-btn v-if="itemDialogEdit" color="error" variant="text" @click="deleteCurrentItem">删除</v-btn>
          <v-spacer />
          <v-btn variant="text" @click="showItemDialog = false">取消</v-btn>
          <v-btn color="primary" :loading="itemSaving" :disabled="!itemForm.title.trim()" @click="submitItemDialog">
            {{ itemDialogEdit ? '保存' : '创建' }}
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Item context menu -->
    <v-menu v-model="showItemMenu" :target="itemMenuTarget" location="bottom end">
      <v-list density="compact" min-width="140">
        <v-list-item prepend-icon="mdi-pencil" @click="itemMenuTarget && openEditItem(itemMenuData!)">
          <v-list-item-title>编辑</v-list-item-title>
        </v-list-item>
        <v-list-item prepend-icon="mdi-link-plus" @click="openAddRefForItem(itemMenuData!)">
          <v-list-item-title>关联资源</v-list-item-title>
        </v-list-item>
        <v-list-item prepend-icon="mdi-delete" color="error" @click="deleteItem(itemMenuData!.id)">
          <v-list-item-title>删除</v-list-item-title>
        </v-list-item>
      </v-list>
    </v-menu>

    <!-- Resource picker -->
    <ResourcePickerDialog
      v-model="showResourcePicker"
      :default-tab="resourcePickerTab"
      @select="onResourcePicked"
    />

    <ImagePreviewDialog
      v-model="showImagePreview"
      :image-url="previewImageUrl"
      :image-name="previewImageName"
      :image-id="previewImageId"
      :image-size="previewImageSize"
      :image-date="previewImageDate"
    />

    <FileDownloadDialog
      v-model="showFileDialog"
      :file-name="fileDialogName"
      :file-url="fileDialogUrl"
      :file-size="fileDialogSize"
      :mime-type="fileDialogMimeType"
    />

    <v-snackbar v-model="snack.show" :color="snack.color" :timeout="2500">{{ snack.text }}</v-snackbar>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { server } from '../server';
import { useMainStore } from '../store/mainStore';
import ResourcePickerDialog from '../components/compose/ResourcePickerDialog.vue';
import ImagePreviewDialog from '../components/compose/ImagePreviewDialog.vue';
import FileDownloadDialog from '../components/compose/FileDownloadDialog.vue';
import { getFileIcon } from '../utils/format';

const router = useRouter();
const mainStore = useMainStore();

const TODO_ACTIVE_LIST_PREFIX = 'todoActiveListId:';
const IMAGE_HOST = 'https://monika.jkloli.net/';

function todoActiveListStorageKey(): string {
  return TODO_ACTIVE_LIST_PREFIX + (mainStore.activeGroupId ?? '__personal');
}

function readPersistedTodoListId(): string | null {
  return localStorage.getItem(todoActiveListStorageKey());
}

function persistActiveTodoListId(id: string | null) {
  const key = todoActiveListStorageKey();
  if (id) localStorage.setItem(key, id);
  else localStorage.removeItem(key);
}

const COLORS = [
  '#f44336', '#e91e63', '#9c27b0', '#673ab7',
  '#3f51b5', '#2196f3', '#03a9f4', '#009688',
  '#4caf50', '#8bc34a', '#ff9800', '#ff5722',
  '#795548', '#607d8b', '#9e9e9e',
];

type TodoFileRef = { type: 'file'; refId: string; title: string; mimeType: string };
type TodoBookmarkRef = {
  type: 'bookmark';
  refId: string;
  title: string;
  bookmarkType: 'url' | 'image' | 'note' | 'file';
  url?: string;
  targetRefId?: string;
};
type TodoRef =
  | { type: 'note'; refId: string; title: string }
  | { type: 'image'; refId: string; title: string; url: string }
  | TodoFileRef
  | TodoBookmarkRef;
type TodoItem = {
  id: string; list_id: string; title: string; description: string;
  done: number; color: string | null; sort_order: number; refs: TodoRef[];
};
type TodoList = { id: string; name: string; color: string; sort_order: number };

const lists = ref<TodoList[]>([]);
const listsLoading = ref(true);
const activeListId = ref<string | null>(null);
const items = ref<TodoItem[]>([]);
const itemsLoading = ref(false);
const newItemTitle = ref('');
const snack = reactive({ show: false, text: '', color: 'success' });
const sidebarOpen = ref(false);
const showImagePreview = ref(false);
const previewImageUrl = ref('');
const previewImageName = ref('');
const previewImageId = ref(0);
const previewImageSize = ref(0);
const previewImageDate = ref('');
const showFileDialog = ref(false);
const fileDialogName = ref('');
const fileDialogUrl = ref('');
const fileDialogSize = ref(0);
const fileDialogMimeType = ref('');

const activeList = computed(() => lists.value.find(l => l.id === activeListId.value) ?? null);
const doneCount = computed(() => items.value.filter(i => i.done).length);

function msg(text: string, color = 'success') {
  snack.text = text; snack.color = color; snack.show = true;
}

function selectList(id: string) {
  activeListId.value = id;
  sidebarOpen.value = false;
}

function refKey(ref: TodoRef) {
  return `${ref.type}:${ref.refId}`;
}

function sameRef(a: TodoRef, b: TodoRef) {
  return a.type === b.type && a.refId === b.refId;
}

function appendRef(refs: TodoRef[], ref: TodoRef) {
  if (refs.some(item => sameRef(item, ref))) return refs;
  return [...refs, ref];
}

function getTodoImageUrl(url: string) {
  return `${IMAGE_HOST}${url}`;
}

function getTodoImageThumb(url: string) {
  return `${getTodoImageUrl(url)}?x-oss-process=image/resize,w_80`;
}

function resolveBookmarkImageUrl(url: string) {
  const trimmed = url.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
  return IMAGE_HOST + trimmed.replace(/^\//, '');
}

function getBookmarkImageThumb(url: string) {
  const full = resolveBookmarkImageUrl(url);
  if (!full.includes('monika.jkloli.net')) return full;
  const sep = full.includes('?') ? '&' : '?';
  return `${full}${sep}x-oss-process=image/resize,w_80`;
}

function refThumbSrc(ref: TodoRef): string | null {
  if (ref.type === 'image') return getTodoImageThumb(ref.url);
  if (ref.type === 'bookmark' && ref.bookmarkType === 'image' && ref.url) return getBookmarkImageThumb(ref.url);
  return null;
}

function refIcon(ref: TodoRef) {
  if (ref.type === 'note') return 'mdi-note-text-outline';
  if (ref.type === 'image') return 'mdi-image-outline';
  if (ref.type === 'file') return getFileIcon(ref.mimeType);
  if (ref.bookmarkType === 'note') return 'mdi-note-text-outline';
  if (ref.bookmarkType === 'image') return 'mdi-image-outline';
  if (ref.bookmarkType === 'file') return 'mdi-file-outline';
  return 'mdi-bookmark-outline';
}

function refKindLabel(ref: TodoRef) {
  if (ref.type === 'note') return '笔记';
  if (ref.type === 'image') return '图片';
  if (ref.type === 'file') return '文件';
  if (ref.bookmarkType === 'note') return '书签 · 笔记';
  if (ref.bookmarkType === 'image') return '书签 · 图片';
  if (ref.bookmarkType === 'file') return '书签 · 文件';
  return '书签';
}

function openImagePreview(url: string, name: string, id = 0, size = 0, date = '') {
  previewImageUrl.value = url;
  previewImageName.value = name;
  previewImageId.value = id;
  previewImageSize.value = size;
  previewImageDate.value = date;
  showImagePreview.value = true;
}

function openFileDialog(name: string, url: string, mimeType = '', size = 0) {
  fileDialogName.value = name;
  fileDialogUrl.value = url;
  fileDialogMimeType.value = mimeType;
  fileDialogSize.value = size;
  showFileDialog.value = true;
}

function buildTodoRef(payload: { type: string; item: any }): TodoRef | null {
  if (payload.type === 'note') {
    return {
      type: 'note',
      refId: String(payload.item.id),
      title: String(payload.item.title || '未命名笔记'),
    };
  }
  if (payload.type === 'image') {
    return {
      type: 'image',
      refId: String(payload.item.id),
      title: String(payload.item.name || '未命名图片'),
      url: String(payload.item.url || ''),
    };
  }
  if (payload.type === 'file') {
    return {
      type: 'file',
      refId: String(payload.item.id),
      title: String(payload.item.name || '未命名文件'),
      mimeType: String(payload.item.mime_type || 'application/octet-stream'),
    };
  }
  if (payload.type === 'bookmark') {
    const bookmarkType =
      payload.item.type === 'image' || payload.item.type === 'note' || payload.item.type === 'file'
        ? payload.item.type
        : 'url';
    return {
      type: 'bookmark',
      refId: String(payload.item.id),
      title: String(payload.item.title || '未命名书签'),
      bookmarkType,
      url: payload.item.url ? String(payload.item.url) : undefined,
      targetRefId: payload.item.ref_id ? String(payload.item.ref_id) : undefined,
    };
  }
  return null;
}

// ─── Data loading ───

async function loadLists() {
  listsLoading.value = true;
  try {
    lists.value = await server.todo.listLists.query() as TodoList[];
    if (lists.value.length === 0) {
      activeListId.value = null;
    } else {
      const saved = readPersistedTodoListId();
      activeListId.value =
        saved && lists.value.some(l => l.id === saved) ? saved : lists.value[0].id;
    }
  } catch (e: any) { msg(e.message, 'error'); }
  listsLoading.value = false;
}

async function loadItems() {
  if (!activeListId.value) { items.value = []; return; }
  itemsLoading.value = true;
  try {
    const data = await server.todo.getList.query(activeListId.value) as any;
    items.value = data.items as TodoItem[];
  } catch (e: any) { msg(e.message, 'error'); }
  itemsLoading.value = false;
}

watch(activeListId, id => {
  persistActiveTodoListId(id);
  loadItems();
});

watch(() => mainStore.refreshTrigger, () => {
  loadLists();
});

onMounted(() => loadLists());

// ─── List CRUD ───

const showListDialog = ref(false);
const listDialogEdit = ref(false);
const listForm = reactive({ name: '', color: '#2196f3' });
const listSaving = ref(false);

function openCreateList() {
  listDialogEdit.value = false;
  listForm.name = '';
  listForm.color = '#2196f3';
  showListDialog.value = true;
}

function openEditList() {
  if (!activeList.value) return;
  listDialogEdit.value = true;
  listForm.name = activeList.value.name;
  listForm.color = activeList.value.color;
  showListDialog.value = true;
}

async function submitListDialog() {
  if (!listForm.name.trim()) return;
  listSaving.value = true;
  try {
    if (listDialogEdit.value && activeListId.value) {
      await server.todo.updateList.mutate({ id: activeListId.value, name: listForm.name.trim(), color: listForm.color });
      const l = lists.value.find(x => x.id === activeListId.value);
      if (l) { l.name = listForm.name.trim(); l.color = listForm.color; }
    } else {
      const created = await server.todo.createList.mutate({ name: listForm.name.trim(), color: listForm.color }) as TodoList;
      lists.value.push(created);
      activeListId.value = created.id;
    }
    showListDialog.value = false;
  } catch (e: any) { msg(e.message, 'error'); }
  listSaving.value = false;
}

const confirmDeleteList = ref(false);
async function submitDeleteList() {
  if (!activeListId.value) return;
  listSaving.value = true;
  try {
    await server.todo.deleteList.mutate(activeListId.value);
    lists.value = lists.value.filter(l => l.id !== activeListId.value);
    activeListId.value = lists.value[0]?.id ?? null;
    confirmDeleteList.value = false;
  } catch (e: any) { msg(e.message, 'error'); }
  listSaving.value = false;
}

// ─── Item CRUD ───

const showItemDialog = ref(false);
const itemDialogEdit = ref(false);
const itemForm = reactive({
  id: '',
  title: '',
  description: '',
  color: null as string | null,
  refs: [] as TodoRef[],
});
const itemSaving = ref(false);

async function quickAddItem() {
  const title = newItemTitle.value.trim();
  if (!title || !activeListId.value) return;
  try {
    const created = await server.todo.createItem.mutate({ listId: activeListId.value, title }) as any;
    items.value.push({ ...created, refs: [] });
    newItemTitle.value = '';
  } catch (e: any) { msg(e.message, 'error'); }
}

function openCreateItem() {
  itemDialogEdit.value = false;
  itemForm.id = '';
  itemForm.title = newItemTitle.value;
  itemForm.description = '';
  itemForm.color = null;
  itemForm.refs = [];
  showItemDialog.value = true;
}

function openEditItem(item: TodoItem) {
  itemDialogEdit.value = true;
  itemForm.id = item.id;
  itemForm.title = item.title;
  itemForm.description = item.description;
  itemForm.color = item.color;
  itemForm.refs = [...item.refs];
  showItemDialog.value = true;
}

async function submitItemDialog() {
  if (!itemForm.title.trim()) return;
  itemSaving.value = true;
  try {
    if (itemDialogEdit.value) {
      await server.todo.updateItem.mutate({
        id: itemForm.id,
        title: itemForm.title.trim(),
        description: itemForm.description,
        color: itemForm.color,
        refs: itemForm.refs,
      });
      const it = items.value.find(i => i.id === itemForm.id);
      if (it) {
        it.title = itemForm.title.trim();
        it.description = itemForm.description;
        it.color = itemForm.color;
        it.refs = [...itemForm.refs];
      }
    } else {
      if (!activeListId.value) return;
      const created = await server.todo.createItem.mutate({
        listId: activeListId.value,
        title: itemForm.title.trim(),
        description: itemForm.description,
        color: itemForm.color,
        refs: itemForm.refs,
      }) as any;
      items.value.push(created as TodoItem);
      newItemTitle.value = '';
    }
    showItemDialog.value = false;
  } catch (e: any) { msg(e.message, 'error'); }
  itemSaving.value = false;
}

async function toggleDone(item: TodoItem) {
  const next = item.done ? 0 : 1;
  try {
    await server.todo.updateItem.mutate({ id: item.id, done: next });
    item.done = next;
  } catch (e: any) { msg(e.message, 'error'); }
}

async function deleteItem(id: string) {
  try {
    await server.todo.deleteItem.mutate(id);
    items.value = items.value.filter(i => i.id !== id);
    showItemMenu.value = false;
  } catch (e: any) { msg(e.message, 'error'); }
}

async function deleteCurrentItem() {
  if (!itemForm.id) return;
  await deleteItem(itemForm.id);
  showItemDialog.value = false;
}

// ─── Item context menu ───

const showItemMenu = ref(false);
const itemMenuTarget = ref<Element | undefined>(undefined);
const itemMenuData = ref<TodoItem | null>(null);

function openItemMenu(item: TodoItem, event: MouseEvent) {
  itemMenuData.value = item;
  itemMenuTarget.value = event.currentTarget as Element;
  showItemMenu.value = true;
}

// ─── Resource picker ───

const showResourcePicker = ref(false);
const resourcePickerTab = ref<'image' | 'note' | 'file' | 'bookmark'>('note');
const resourcePickerForItem = ref<TodoItem | null>(null);

function openResourcePicker() {
  resourcePickerForItem.value = null;
  showResourcePicker.value = true;
}

function openAddRefForItem(item: TodoItem) {
  resourcePickerForItem.value = item;
  showResourcePicker.value = true;
  showItemMenu.value = false;
}

async function onResourcePicked(payload: { type: string; item: any }) {
  const ref = buildTodoRef(payload);
  if (!ref) {
    msg('暂不支持此类型关联', 'warning');
    return;
  }

  if (resourcePickerForItem.value) {
    try {
      const nextRefs = appendRef(resourcePickerForItem.value.refs, ref);
      if (nextRefs === resourcePickerForItem.value.refs) {
        msg('该资源已关联', 'warning');
        return;
      }
      await server.todo.updateItem.mutate({
        id: resourcePickerForItem.value.id,
        refs: nextRefs,
      });
      resourcePickerForItem.value.refs = nextRefs;
      msg('已关联');
    } catch (e: any) { msg(e.message, 'error'); }
  } else {
    const nextRefs = appendRef(itemForm.refs, ref);
    if (nextRefs === itemForm.refs) {
      msg('该资源已关联', 'warning');
      return;
    }
    itemForm.refs = nextRefs;
  }
}

function removeRefFromForm(ref: TodoRef) {
  itemForm.refs = itemForm.refs.filter(item => !sameRef(item, ref));
}

async function goRef(r: TodoRef) {
  if (r.type === 'note') {
    router.push(`/note/${r.refId}`);
    return;
  }
  if (r.type === 'image') {
    openImagePreview(getTodoImageUrl(r.url), r.title, Number(r.refId));
    return;
  }
  if (r.type === 'file') {
    openFileDialog(r.title, '', r.mimeType);
    try {
      const result = await server.file_drive.getDownloadUrl.query({ file_id: Number(r.refId) });
      fileDialogUrl.value = result.url;
    } catch { /* keep disabled */ }
    return;
  }
  if (r.bookmarkType === 'note' && r.targetRefId) {
    router.push(`/note/${r.targetRefId}`);
    return;
  }
  if (r.bookmarkType === 'image' && r.url) {
    openImagePreview(resolveBookmarkImageUrl(r.url), r.title, r.targetRefId ? Number(r.targetRefId) : 0);
    return;
  }
  if (r.bookmarkType === 'file' && r.url) {
    openFileDialog(r.title, r.url);
    return;
  }
  router.push(`/bookmark/${r.refId}`);
}
</script>

<style scoped>
.todo-container {
  min-height: 100%;
  display: flex;
  flex-direction: column;
}

.todo-header {
  margin-bottom: 16px;
}

.page-head {
  display: flex;
  align-items: center;
  gap: 14px;
}

.page-icon {
  width: 44px;
  height: 44px;
  border-radius: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgb(var(--v-theme-surface-variant));
  color: rgb(var(--v-theme-primary));
  flex-shrink: 0;
}

.page-title {
  font-size: 28px;
  font-weight: 700;
  line-height: 1.2;
}

/* ─── Layout ─── */

.todo-layout {
  display: flex;
  gap: 16px;
  flex: 1;
  min-height: 0;
}

/* ─── Sidebar ─── */

.todo-sidebar {
  width: 200px;
  flex-shrink: 0;
  background: rgb(var(--v-theme-surface));
  border-radius: 16px;
  align-self: flex-start;
  overflow: hidden;
}

.sidebar-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 14px;
}

.sidebar-label {
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.sidebar-scroll {
  overflow-y: auto;
}

.sidebar-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 14px;
  cursor: pointer;
  transition: background 0.15s;
  font-size: 14px;
}

.sidebar-item:hover {
  background: rgba(var(--v-theme-on-surface), 0.04);
}

.sidebar-item.active {
  background: rgba(var(--v-theme-primary), 0.08);
  font-weight: 600;
}

.sidebar-item-name {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.sidebar-empty {
  padding: 24px 14px;
  font-size: 13px;
  text-align: center;
}

.sidebar-backdrop {
  display: none;
}

.sidebar-toggle {
  display: none;
}

/* ─── Main content ─── */

.todo-main {
  flex: 1;
  min-width: 0;
  background: rgb(var(--v-theme-surface));
  border-radius: 16px;
  overflow: hidden;
}

.list-head {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
}

.list-name {
  font-size: 16px;
  font-weight: 600;
}

.add-item-row {
  display: flex;
  align-items: center;
  padding: 4px 16px;
  gap: 4px;
}

.todo-items-list {
  padding: 0;
}

.todo-item {
  min-height: 52px;
  cursor: pointer;
}

.todo-item-body {
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 0;
}

.todo-item-title {
  line-height: 1.4;
  word-break: break-word;
}

.todo-item-desc {
  font-size: 13px;
  line-height: 1.4;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  word-break: break-word;
}

.todo-item-refs {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding-top: 4px;
}

.todo-ref {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  max-width: 220px;
  padding: 4px 10px 4px 4px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 999px;
  background: rgba(var(--v-theme-on-surface), 0.03);
  color: inherit;
  cursor: pointer;
}

.todo-ref-thumb {
  width: 24px;
  height: 24px;
  border-radius: 999px;
  object-fit: cover;
  flex-shrink: 0;
}

.todo-ref-label {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 12px;
}

.todo-ref.is-image {
  padding-left: 4px;
}

.ref-editor-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.ref-editor-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 8px 10px;
  border: 1px solid rgba(var(--v-theme-on-surface), 0.08);
  border-radius: 12px;
  background: rgba(var(--v-theme-on-surface), 0.02);
}

.ref-editor-main {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
}

.ref-editor-thumb,
.ref-editor-note-icon {
  width: 36px;
  height: 36px;
  border-radius: 10px;
  flex-shrink: 0;
}

.ref-editor-thumb {
  object-fit: cover;
}

.ref-editor-note-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(var(--v-theme-primary), 0.08);
}

.ref-editor-text {
  min-width: 0;
}

.ref-editor-title {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 14px;
  font-weight: 500;
}

.ref-editor-sub {
  font-size: 12px;
  color: rgb(var(--v-theme-on-surface-variant));
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 320px;
  padding: 32px 24px;
}

.empty-items {
  text-align: center;
  padding: 32px 16px;
}

/* ─── Dialogs ─── */

.color-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.color-dot {
  width: 28px;
  height: 28px;
  border-radius: 50%;
  cursor: pointer;
  transition: transform 0.15s, box-shadow 0.15s;
  border: 2px solid transparent;
}

.color-dot:hover {
  transform: scale(1.15);
}

.color-dot.active {
  box-shadow: 0 0 0 3px rgba(var(--v-theme-primary), 0.4);
  transform: scale(1.15);
}

.item-dialog-body {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.dialog-title {
  font-size: 18px;
  font-weight: 700;
}

/* ─── Mobile ─── */

@media (max-width: 760px) {
  .page-title {
    font-size: 24px;
  }

  .todo-container {
    padding-bottom: calc(env(safe-area-inset-bottom, 0px) + 16px);
  }

  .todo-sidebar {
    position: fixed;
    left: 0;
    top: 0;
    bottom: 0;
    z-index: 200;
    width: 260px;
    border-radius: 0;
    transform: translateX(-100%);
    transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  }

  .todo-sidebar.open {
    transform: translateX(0);
  }

  .sidebar-backdrop {
    display: block;
    position: fixed;
    inset: 0;
    z-index: 199;
    background: rgba(0, 0, 0, 0.4);
  }

  .sidebar-toggle {
    display: inline-flex;
  }
}
</style>
