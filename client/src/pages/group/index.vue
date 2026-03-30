<template>
  <v-container class="py-8" fluid>
    <v-row>
      <v-col cols="12" md="6">
        <v-card variant="elevated" elevation="1">
          <v-card-item>
            <template #append>
              <v-btn icon="mdi-plus" variant="text" color="primary" @click="createDialog = true" />
            </template>
            <v-card-title>我的群组</v-card-title>
          </v-card-item>
          <v-divider />
          <v-card-text v-if="loading" class="d-flex align-center justify-center py-12">
            <v-progress-circular indeterminate color="primary" />
          </v-card-text>
          <v-list v-else-if="groups.length > 0" lines="two" class="py-0" bg-color="transparent">
            <template v-for="(g, i) in groups" :key="g.id">
              <v-divider v-if="i > 0" />
              <v-list-item :to="`/group/${g.id}`" link>
                <template #prepend>
                  <v-avatar color="primary" variant="tonal">
                    <v-icon>mdi-account-group</v-icon>
                  </v-avatar>
                </template>
                <v-list-item-title class="font-weight-medium">{{ g.name }}</v-list-item-title>
                <v-list-item-subtitle>
                  <v-chip size="x-small" variant="tonal" :color="roleColor(g.role)" label class="mr-1">
                    {{ roleLabel(g.role) }}
                  </v-chip>
                  {{ g.description?.slice(0, 60) || '暂无描述' }}
                </v-list-item-subtitle>
                <template #append>
                  <v-btn
                    icon="mdi-swap-horizontal"
                    variant="text"
                    size="small"
                    @click.prevent.stop="switchTo(g.id)"
                  />
                </template>
              </v-list-item>
            </template>
          </v-list>
          <v-card-text v-else>
            <v-empty-state
              icon="mdi-account-group-outline"
              title="暂无群组"
              text="创建或加入一个群组开始协作"
              min-height="200"
            />
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card variant="elevated" elevation="1">
          <v-card-item>
            <v-card-title>待处理邀请</v-card-title>
          </v-card-item>
          <v-divider />
          <v-card-text v-if="invitesLoading" class="d-flex align-center justify-center py-8">
            <v-progress-circular indeterminate color="primary" size="28" />
          </v-card-text>
          <v-list v-else-if="invites.length > 0" lines="two" class="py-0" bg-color="transparent">
            <template v-for="(inv, i) in invites" :key="inv.id">
              <v-divider v-if="i > 0" />
              <v-list-item>
                <v-list-item-title>{{ inv.group_name }}</v-list-item-title>
                <v-list-item-subtitle>
                  角色: {{ roleLabel(inv.role) }}
                </v-list-item-subtitle>
                <template #append>
                  <v-btn
                    color="primary"
                    variant="tonal"
                    size="small"
                    :loading="accepting === inv.id"
                    @click="acceptInvite(inv.id)"
                  >接受</v-btn>
                </template>
              </v-list-item>
            </template>
          </v-list>
          <v-card-text v-else>
            <v-empty-state
              icon="mdi-email-outline"
              title="暂无邀请"
              text="有人邀请你加入群组时会显示在这里"
              min-height="160"
            />
          </v-card-text>
        </v-card>

        <v-card variant="elevated" elevation="1" class="mt-4">
          <v-card-item>
            <v-card-title>通过邀请码加入</v-card-title>
          </v-card-item>
          <v-divider />
          <v-card-text>
            <v-text-field
              v-model="inviteCode"
              label="邀请码"
              variant="outlined"
              density="comfortable"
              hide-details="auto"
              placeholder="粘贴邀请码"
            />
            <div class="d-flex justify-end mt-4">
              <v-btn color="primary" variant="flat" :loading="joining" @click="joinByCode">加入</v-btn>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-dialog v-model="createDialog" max-width="480" scrim-opacity="0.32">
      <v-card>
        <v-card-item>
          <v-card-title>创建群组</v-card-title>
        </v-card-item>
        <v-card-text>
          <v-text-field
            v-model="newGroup.name"
            label="群组名称"
            variant="outlined"
            density="comfortable"
            class="mb-4"
            autofocus
          />
          <v-textarea
            v-model="newGroup.description"
            label="描述（可选）"
            variant="outlined"
            density="comfortable"
            rows="3"
          />
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-4 py-3">
          <v-spacer />
          <v-btn variant="text" @click="createDialog = false">取消</v-btn>
          <v-btn color="primary" variant="flat" :loading="creating" @click="createGroup">创建</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" :timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { server } from '../../server';
import { useMainStore } from '../../store/mainStore';

const mainStore = useMainStore();

type GroupItem = { id: string; name: string; description: string; role: string };
type InviteItem = { id: string; group_name: string; role: string };

const groups = ref<GroupItem[]>([]);
const invites = ref<InviteItem[]>([]);
const loading = ref(true);
const invitesLoading = ref(true);
const createDialog = ref(false);
const creating = ref(false);
const newGroup = reactive({ name: '', description: '' });
const inviteCode = ref('');
const joining = ref(false);
const accepting = ref<string | null>(null);
const snack = reactive({ show: false, text: '', color: 'success' });

function msg(text: string, color = 'success') {
  snack.text = text;
  snack.color = color;
  snack.show = true;
}

function roleColor(role: string) {
  return { owner: 'error', admin: 'warning', editor: 'primary', viewer: 'info' }[role] ?? 'default';
}

function roleLabel(role: string) {
  return { owner: '所有者', admin: '管理员', editor: '编辑者', viewer: '只读' }[role] ?? role;
}

function switchTo(id: string) {
  mainStore.switchGroup(id);
  msg('已切换到群组空间');
}

async function load() {
  loading.value = true;
  try {
    const list = await server.group.list.query();
    groups.value = list as GroupItem[];
    mainStore.setGroups(list.map(g => ({ id: g.id, name: g.name, role: g.role })));
  } catch (e: any) {
    msg(e.message || '加载失败', 'error');
  } finally {
    loading.value = false;
  }
}

async function loadInvites() {
  invitesLoading.value = true;
  try {
    invites.value = (await server.group.myInvites.query()) as InviteItem[];
  } catch { /* noop */ } finally {
    invitesLoading.value = false;
  }
}

async function createGroup() {
  if (!newGroup.name.trim()) return;
  creating.value = true;
  try {
    await server.group.create.mutate({ name: newGroup.name, description: newGroup.description });
    msg('群组已创建');
    createDialog.value = false;
    newGroup.name = '';
    newGroup.description = '';
    await load();
  } catch (e: any) {
    msg(e.message || '创建失败', 'error');
  } finally {
    creating.value = false;
  }
}

async function acceptInvite(id: string) {
  accepting.value = id;
  try {
    await server.group.acceptInvite.mutate({ inviteId: id });
    msg('已加入群组');
    await Promise.all([load(), loadInvites()]);
  } catch (e: any) {
    msg(e.message || '加入失败', 'error');
  } finally {
    accepting.value = null;
  }
}

async function joinByCode() {
  if (!inviteCode.value.trim()) return;
  joining.value = true;
  try {
    await server.group.acceptInvite.mutate({ inviteCode: inviteCode.value.trim() });
    msg('已加入群组');
    inviteCode.value = '';
    await load();
  } catch (e: any) {
    msg(e.message || '加入失败', 'error');
  } finally {
    joining.value = false;
  }
}

onMounted(() => {
  load();
  loadInvites();
});
</script>
