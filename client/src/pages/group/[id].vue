<template>
  <v-container class="py-8" fluid>
    <v-btn variant="text" prepend-icon="mdi-arrow-left" to="/group" class="mb-4">返回群组列表</v-btn>

    <v-card v-if="loading" class="d-flex align-center justify-center py-12">
      <v-progress-circular indeterminate color="primary" />
    </v-card>

    <template v-else-if="group">
      <v-row>
        <v-col cols="12" md="5">
          <v-card variant="elevated" elevation="1">
            <v-card-item>
              <v-card-title>群组信息</v-card-title>
              <template #append>
                <v-btn
                  icon="mdi-swap-horizontal"
                  variant="text"
                  color="primary"
                  size="small"
                  @click="switchTo"
                />
              </template>
            </v-card-item>
            <v-divider />
            <v-card-text>
              <v-text-field
                v-model="editName"
                label="名称"
                variant="outlined"
                density="comfortable"
                class="mb-4"
                :disabled="!canEdit"
              />
              <v-textarea
                v-model="editDesc"
                label="描述"
                variant="outlined"
                density="comfortable"
                rows="3"
                :disabled="!canEdit"
              />
              <div v-if="canEdit" class="d-flex justify-end mt-2">
                <v-btn color="primary" variant="flat" :loading="saving" @click="saveInfo">保存</v-btn>
              </div>
            </v-card-text>
          </v-card>

          <v-card v-if="isAdmin" variant="elevated" elevation="1" class="mt-4">
            <v-card-item>
              <v-card-title>邀请</v-card-title>
            </v-card-item>
            <v-divider />
            <v-card-text>
              <v-text-field
                v-model="inviteUserId"
                label="用户ID（直接邀请）"
                variant="outlined"
                density="comfortable"
                class="mb-2"
                hide-details
              />
              <v-select
                v-model="inviteRole"
                :items="assignableRoles"
                label="角色"
                variant="outlined"
                density="comfortable"
                class="mb-2"
                hide-details
              />
              <div class="d-flex ga-2 mt-2">
                <v-btn color="primary" variant="flat" size="small" :loading="inviting" @click="inviteUser">邀请用户</v-btn>
                <v-btn color="secondary" variant="tonal" size="small" :loading="generatingLink" @click="generateLink">生成邀请链接</v-btn>
              </div>
              <v-alert v-if="inviteLink" type="success" variant="tonal" class="mt-3" density="compact" closable>
                <div class="text-caption">邀请码（发送给对方）:</div>
                <code class="text-body-2 user-select-all">{{ inviteLink }}</code>
              </v-alert>
            </v-card-text>
          </v-card>

          <v-card v-if="isOwner" variant="elevated" elevation="1" class="mt-4">
            <v-card-item>
              <v-card-title class="text-error">危险区域</v-card-title>
            </v-card-item>
            <v-divider />
            <v-card-text>
              <v-btn color="error" variant="flat" :loading="deleting" @click="deleteDialog = true">删除群组</v-btn>
            </v-card-text>
          </v-card>
        </v-col>

        <v-col cols="12" md="7">
          <v-card variant="elevated" elevation="1">
            <v-card-item>
              <v-card-title>成员 ({{ members.length }})</v-card-title>
            </v-card-item>
            <v-divider />
            <v-list lines="two" class="py-0" bg-color="transparent">
              <template v-for="(m, i) in members" :key="m.user_id">
                <v-divider v-if="i > 0" />
                <v-list-item>
                  <template #prepend>
                    <v-avatar :color="roleColor(m.role)" variant="tonal" size="36">
                      <v-icon size="18">mdi-account</v-icon>
                    </v-avatar>
                  </template>
                  <v-list-item-title>{{ m.user_name || m.user_id }}</v-list-item-title>
                  <v-list-item-subtitle>
                    <v-chip :color="roleColor(m.role)" size="x-small" variant="tonal" label>
                      {{ roleLabel(m.role) }}
                    </v-chip>
                    {{ m.user_email || '' }}
                  </v-list-item-subtitle>
                  <template #append>
                    <div v-if="isAdmin && m.role !== 'owner'" class="d-flex align-center">
                      <v-menu>
                        <template #activator="{ props }">
                          <v-btn v-bind="props" icon="mdi-account-cog" variant="text" size="small" />
                        </template>
                        <v-list density="compact" min-width="140">
                          <v-list-item
                            v-for="r in assignableRoles"
                            :key="r.value"
                            :title="r.title"
                            :active="m.role === r.value"
                            @click="changeRole(m.user_id, r.value)"
                          />
                        </v-list>
                      </v-menu>
                      <v-btn
                        icon="mdi-account-remove"
                        variant="text"
                        size="small"
                        color="error"
                        @click="removeMember(m.user_id)"
                      />
                    </div>
                  </template>
                </v-list-item>
              </template>
            </v-list>
          </v-card>
        </v-col>
      </v-row>
    </template>

    <v-dialog v-model="deleteDialog" max-width="400" scrim-opacity="0.32">
      <v-card>
        <v-card-item>
          <v-card-title class="text-error">确认删除群组？</v-card-title>
          <v-card-subtitle class="text-wrap">此操作不可恢复，群组内所有成员关系将被解除。</v-card-subtitle>
        </v-card-item>
        <v-divider />
        <v-card-actions class="px-4 py-3">
          <v-spacer />
          <v-btn variant="text" @click="deleteDialog = false">取消</v-btn>
          <v-btn color="error" variant="flat" :loading="deleting" @click="deleteGroup">删除</v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snack.show" :color="snack.color" :timeout="3000">
      {{ snack.text }}
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { server } from '../../server';
import { useMainStore } from '../../store/mainStore';

const route = useRoute();
const router = useRouter();
const mainStore = useMainStore();
const groupId = route.params.id as string;

type MemberItem = {
  user_id: string; role: string; user_name?: string; user_email?: string;
};

const group = ref<{ id: string; name: string; description: string; role: string } | null>(null);
const members = ref<MemberItem[]>([]);
const loading = ref(true);
const saving = ref(false);
const inviting = ref(false);
const generatingLink = ref(false);
const deleting = ref(false);
const deleteDialog = ref(false);
const editName = ref('');
const editDesc = ref('');
const inviteUserId = ref('');
const inviteRole = ref('editor');
const inviteLink = ref('');
const snack = reactive({ show: false, text: '', color: 'success' });

const assignableRoles = [
  { title: '管理员', value: 'admin' },
  { title: '编辑者', value: 'editor' },
  { title: '只读', value: 'viewer' },
];

const isOwner = computed(() => group.value?.role === 'owner');
const isAdmin = computed(() => ['owner', 'admin'].includes(group.value?.role ?? ''));
const canEdit = computed(() => isAdmin.value);

function roleColor(role: string) {
  return { owner: 'error', admin: 'warning', editor: 'primary', viewer: 'info' }[role] ?? 'default';
}
function roleLabel(role: string) {
  return { owner: '所有者', admin: '管理员', editor: '编辑者', viewer: '只读' }[role] ?? role;
}

function msg(text: string, color = 'success') {
  snack.text = text; snack.color = color; snack.show = true;
}

function switchTo() {
  mainStore.switchGroup(groupId);
  msg('已切换到该群组空间');
}

async function load() {
  loading.value = true;
  try {
    const [g, m] = await Promise.all([
      server.group.getById.query(groupId),
      server.group.listMembers.query(groupId),
    ]);
    group.value = g as any;
    members.value = m as MemberItem[];
    editName.value = g.name ?? '';
    editDesc.value = g.description ?? '';
  } catch (e: any) {
    msg(e.message || '加载失败', 'error');
  } finally {
    loading.value = false;
  }
}

async function saveInfo() {
  saving.value = true;
  try {
    await server.group.update.mutate({ groupId, name: editName.value, description: editDesc.value });
    msg('已保存');
    group.value = { ...group.value!, name: editName.value, description: editDesc.value };
    const groups = await server.group.list.query();
    mainStore.setGroups(groups.map(g => ({ id: g.id, name: g.name, role: g.role })));
  } catch (e: any) {
    msg(e.message || '保存失败', 'error');
  } finally {
    saving.value = false;
  }
}

async function inviteUser() {
  if (!inviteUserId.value.trim()) return;
  inviting.value = true;
  try {
    await server.group.inviteUser.mutate({
      groupId, userId: inviteUserId.value.trim(), role: inviteRole.value as any,
    });
    msg('邀请已发送');
    inviteUserId.value = '';
  } catch (e: any) {
    msg(e.message || '邀请失败', 'error');
  } finally {
    inviting.value = false;
  }
}

async function generateLink() {
  generatingLink.value = true;
  try {
    const inv = await server.group.createInviteLink.mutate({
      groupId, role: inviteRole.value as any, expiresInHours: 72,
    });
    inviteLink.value = inv.invite_code ?? '';
  } catch (e: any) {
    msg(e.message || '生成失败', 'error');
  } finally {
    generatingLink.value = false;
  }
}

async function changeRole(userId: string, role: string) {
  try {
    await server.group.updateMemberRole.mutate({ groupId, userId, role: role as any });
    msg('角色已更新');
    await load();
  } catch (e: any) {
    msg(e.message || '操作失败', 'error');
  }
}

async function removeMember(userId: string) {
  try {
    await server.group.removeMember.mutate({ groupId, userId });
    msg('成员已移除');
    await load();
  } catch (e: any) {
    msg(e.message || '操作失败', 'error');
  }
}

async function deleteGroup() {
  deleting.value = true;
  try {
    await server.group.delete.mutate(groupId);
    if (mainStore.activeGroupId === groupId) mainStore.switchGroup(null);
    msg('群组已删除');
    router.push('/group');
  } catch (e: any) {
    msg(e.message || '删除失败', 'error');
  } finally {
    deleting.value = false;
  }
}

onMounted(load);
</script>
