<template>
  <v-container class="d-flex align-center justify-center" style="min-height: 60vh">
    <v-card max-width="440" min-width="320" variant="elevated" elevation="2">
      <v-card-text v-if="loading" class="d-flex flex-column align-center py-12">
        <v-progress-circular indeterminate color="primary" size="40" />
        <span class="mt-4 text-body-2 text-medium-emphasis">正在验证邀请…</span>
      </v-card-text>

      <template v-else-if="error">
        <v-card-item>
          <v-card-title class="text-error">邀请无效</v-card-title>
        </v-card-item>
        <v-card-text>{{ error }}</v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-btn variant="flat" color="primary" to="/group">返回群组页</v-btn>
        </v-card-actions>
      </template>

      <template v-else-if="info">
        <v-card-item>
          <v-card-title>加入群组</v-card-title>
        </v-card-item>
        <v-divider />
        <v-card-text class="py-6">
          <div class="d-flex flex-column align-center">
            <v-avatar color="primary" variant="tonal" size="64">
              <v-icon size="32">mdi-account-group</v-icon>
            </v-avatar>
            <div class="text-h6 mt-3">{{ info.groupName }}</div>
            <v-chip size="small" variant="tonal" color="primary" class="mt-2">
              角色: {{ roleLabel(info.role) }}
            </v-chip>
          </div>
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-4 py-3">
          <v-btn variant="text" to="/group">取消</v-btn>
          <v-spacer />
          <v-btn color="primary" variant="flat" :loading="joining" @click="join">加入群组</v-btn>
        </v-card-actions>
      </template>

      <template v-else-if="joined">
        <v-card-item>
          <v-card-title class="text-success">已加入</v-card-title>
        </v-card-item>
        <v-card-text>你已成功加入群组。</v-card-text>
        <v-card-actions class="px-4 pb-4">
          <v-btn variant="flat" color="primary" to="/group">前往群组列表</v-btn>
        </v-card-actions>
      </template>
    </v-card>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { server } from '../../../server';
import { useMainStore } from '../../../store/mainStore';

const route = useRoute();
const mainStore = useMainStore();
const code = route.params.code as string;

const loading = ref(true);
const error = ref('');
const joining = ref(false);
const joined = ref(false);
const info = ref<{ groupName: string; groupId: string; role: string } | null>(null);

function roleLabel(role: string) {
  return { admin: '管理员', editor: '编辑者', viewer: '只读' }[role] ?? role;
}

async function loadInfo() {
  loading.value = true;
  try {
    info.value = await server.group.getInviteInfo.query(code);
  } catch (e: any) {
    error.value = e.message || '邀请不存在或已失效';
  } finally {
    loading.value = false;
  }
}

async function join() {
  joining.value = true;
  try {
    await server.group.acceptInvite.mutate({ inviteCode: code });
    joined.value = true;
    info.value = null;
    const groups = await server.group.list.query();
    mainStore.setGroups(groups.map(g => ({ id: g.id, name: g.name, role: g.role, avatar: (g as any).meta?.avatar, primaryColor: (g as any).meta?.primaryColor })));
  } catch (e: any) {
    error.value = e.message || '加入失败';
    info.value = null;
  } finally {
    joining.value = false;
  }
}

onMounted(loadInfo);
</script>
