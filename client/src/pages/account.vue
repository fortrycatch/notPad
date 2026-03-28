<template>
  <v-container class="py-8" fluid>
    <v-row class="mt-0">
      <v-col cols="12" md="4">
        <v-card variant="elevated" elevation="1">
          <v-card-item>
            <v-card-title class="text-title-md">个人资料</v-card-title>
          </v-card-item>
          <v-divider />
          <v-card-text
            v-if="pageLoading"
            class="d-flex flex-column align-center justify-center py-12"
            min-height="280"
          >
            <v-progress-circular indeterminate color="primary" size="40" width="3" />
            <span class="text-body-2 text-medium-emphasis mt-4">加载中…</span>
          </v-card-text>
          <v-card-text v-else>
            <v-form @submit.prevent="updateProfile">
              <v-text-field
                v-model="profile.name"
                label="昵称"
                variant="outlined"
                density="comfortable"
                class="mb-4"
                hide-details="auto"
              />
              <v-text-field
                v-model="profile.email"
                label="邮箱"
                type="email"
                variant="outlined"
                density="comfortable"
                class="mb-4"
                hide-details="auto"
              />
              <v-text-field
                v-model="password"
                label="新密码"
                type="password"
                variant="outlined"
                density="comfortable"
                hint="留空表示不修改密码"
                persistent-hint
              />
              <div class="d-flex justify-end mt-6">
                <v-btn
                  type="submit"
                  color="primary"
                  variant="flat"
                  size="large"
                  :loading="saving"
                >
                  保存
                </v-btn>
              </div>
            </v-form>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="8">
        <v-card variant="elevated" elevation="1">
          <v-card-item>
            <v-card-title class="text-title-md">登录设备</v-card-title>
          </v-card-item>
          <v-divider />
          <v-card-text
            v-if="pageLoading"
            class="d-flex flex-column align-center justify-center py-12"
            min-height="280"
          >
            <v-progress-circular indeterminate color="primary" size="40" width="3" />
            <span class="text-body-2 text-medium-emphasis mt-4">加载中…</span>
          </v-card-text>
          <v-card-text v-else-if="tokens.length === 0">
            <v-empty-state
              icon="mdi-shield-key-outline"
              title="暂无会话"
              text="登录后此处会列出当前账号的活跃凭证"
              min-height="200"
            />
          </v-card-text>
          <v-list v-else class="py-0" bg-color="transparent" lines="three">
            <template v-for="(token, index) in tokens" :key="token.token">
              <v-divider v-if="index > 0" inset />
              <v-list-item class="py-3 px-4">
                <template #prepend>
                  <v-tooltip location="end" max-width="320">
                    <template #activator="{ props: a }">
                      <v-avatar
                        v-bind="a"
                        :color="deviceHint(token.user_agent).avatarColor"
                        size="40"
                      >
                        <v-icon
                          :icon="deviceHint(token.user_agent).icon"
                          :color="deviceHint(token.user_agent).iconOnColor"
                          size="22"
                        />
                      </v-avatar>
                    </template>
                    <span class="text-caption">{{ token.user_agent || "无 User-Agent" }}</span>
                  </v-tooltip>
                </template>

                <v-list-item-title class="text-body-1 font-weight-medium">
                  {{ token.alias || "未命名会话" }}
                </v-list-item-title>
                <v-list-item-subtitle>
                  <div class="d-flex flex-wrap align-center ga-2 mt-1">
                    <v-chip
                      size="small"
                      variant="tonal"
                      :color="deviceHint(token.user_agent).chipColor"
                      label
                    >
                      {{ deviceHint(token.user_agent).label }}
                    </v-chip>
                    <span class="text-caption text-medium-emphasis">
                      创建于 {{ formatDate(token.created_at) }}
                      <template v-if="token.used_at">
                        · 最近 {{ formatDate(token.used_at) }}
                      </template>
                    </span>
                  </div>
                  <p
                    v-if="token.user_agent"
                    class="text-caption text-medium-emphasis text-truncate mt-2 mb-0"
                    style="max-width: 100%"
                  >
                    {{ token.user_agent }}
                  </p>
                  <p v-else class="text-caption text-disabled mt-2 mb-0">
                    无浏览器标识记录
                  </p>
                </v-list-item-subtitle>

                <template #append>
                  <div class="d-flex align-center">
                    <v-btn
                      icon="mdi-pencil-outline"
                      variant="text"
                      color="primary"
                      density="comfortable"
                      @click.stop="openRenameDialog(token)"
                    />
                    <v-btn
                      icon="mdi-delete-outline"
                      variant="text"
                      color="error"
                      density="comfortable"
                      :loading="revoking === token.token"
                      @click.stop="askRevoke(token.token)"
                    />
                  </div>
                </template>
              </v-list-item>
            </template>
          </v-list>
        </v-card>
      </v-col>
    </v-row>

    <!-- Material 对话框：重命名 -->
    <v-dialog v-model="renameDialog" max-width="400" scrim-opacity="0.32">
      <v-card>
        <v-card-item>
          <v-card-title class="text-title-lg">重命名会话</v-card-title>
          <v-card-subtitle class="text-body-2 text-wrap">
            例如「办公室电脑」「测试机」，留空可清除名称。
          </v-card-subtitle>
        </v-card-item>
        <v-card-text>
          <v-text-field
            v-model="renameDraft"
            label="显示名称"
            variant="outlined"
            density="comfortable"
            maxlength="128"
            counter
            autofocus
            hide-details="auto"
            @keyup.enter="confirmRename"
          />
        </v-card-text>
        <v-divider />
        <v-card-actions class="px-4 py-3">
          <v-spacer />
          <v-btn variant="text" @click="renameDialog = false">取消</v-btn>
          <v-btn
            color="primary"
            variant="flat"
            :loading="savingAlias"
            @click="confirmRename"
          >
            确定
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <!-- Material 对话框：移除会话 -->
    <v-dialog v-model="revokeDialog" max-width="400" scrim-opacity="0.32">
      <v-card>
        <v-card-item>
          <v-card-title class="text-title-lg">移除此会话？</v-card-title>
          <v-card-subtitle class="text-body-2 text-wrap">
            该设备上的登录将失效，需要重新登录。
          </v-card-subtitle>
        </v-card-item>
        <v-divider />
        <v-card-actions class="px-4 py-3">
          <v-spacer />
          <v-btn variant="text" @click="revokeDialog = false">取消</v-btn>
          <v-btn
            color="error"
            variant="flat"
            :loading="revoking !== null"
            @click="confirmRevoke"
          >
            移除
          </v-btn>
        </v-card-actions>
      </v-card>
    </v-dialog>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color" :timeout="4000">
      {{ snackbar.text }}
      <template #actions>
        <v-btn variant="text" @click="snackbar.show = false">关闭</v-btn>
      </template>
    </v-snackbar>
  </v-container>
</template>

<script setup lang="ts">
import { ref, onMounted, reactive } from "vue";
import { server } from "../server";

type TokenRow = {
  token: string;
  created_at: string | Date;
  used_at: string | Date | null;
  user_agent: string | null;
  alias: string | null;
};

type DeviceHint = {
  icon: string;
  label: string;
  avatarColor: string;
  iconOnColor: string;
  chipColor: string;
};

/** UA → 设备类型（Material 语义色） */
function deviceHint(ua: string | null): DeviceHint {
  if (!ua?.trim()) {
    return {
      icon: "mdi-help-circle-outline",
      label: "未知",
      avatarColor: "surface-variant",
      iconOnColor: "on-surface-variant",
      chipColor: "surface-variant"
    };
  }
  const s = ua.toLowerCase();
  if (/ipad|tablet|playbook|kindle|silk(?!\/)/.test(s) || /android(?!.*mobile)/.test(s)) {
    return {
      icon: "mdi-tablet",
      label: "平板",
      avatarColor: "info",
      iconOnColor: "on-info",
      chipColor: "info"
    };
  }
  if (
    /iphone|ipod|windows phone|iemobile|blackberry|bb10|opera mini|mobile|android.*mobile/.test(s)
  ) {
    return {
      icon: "mdi-cellphone",
      label: "手机",
      avatarColor: "secondary",
      iconOnColor: "on-secondary",
      chipColor: "secondary"
    };
  }
  return {
    icon: "mdi-monitor",
    label: "电脑",
    avatarColor: "primary",
    iconOnColor: "on-primary",
    chipColor: "primary"
  };
}

const profile = reactive({
  name: "",
  email: "",
  id: ""
});
const password = ref("");
const tokens = ref<TokenRow[]>([]);
/** 首屏数据未返回前为 true，避免先闪现「暂无」等空状态 */
const pageLoading = ref(true);
const saving = ref(false);
const savingAlias = ref(false);
const revoking = ref<string | null>(null);

const renameDialog = ref(false);
const renameTarget = ref<string | null>(null);
const renameDraft = ref("");

const revokeDialog = ref(false);
const revokeTarget = ref<string | null>(null);

const snackbar = reactive({
  show: false,
  text: "",
  color: "success"
});

function showMsg(text: string, color: string = "success") {
  snackbar.text = text;
  snackbar.color = color;
  snackbar.show = true;
}

function formatDate(dateStr: string | Date) {
  if (!dateStr) return "-";
  return new Date(dateStr).toLocaleString();
}

function openRenameDialog(token: TokenRow) {
  renameTarget.value = token.token;
  renameDraft.value = token.alias ?? "";
  renameDialog.value = true;
}

function askRevoke(tokenHash: string) {
  revokeTarget.value = tokenHash;
  revokeDialog.value = true;
}

async function refreshTokens() {
  const tokenList = await server.auth.getTokens.query();
  tokens.value = tokenList as TokenRow[];
}

async function loadData() {
  pageLoading.value = true;
  try {
    const user = await server.auth.getProfile.query();
    profile.name = user.name;
    profile.email = user.email;
    profile.id = user.id;
    await refreshTokens();
  } catch (error: any) {
    console.error(error);
    showMsg(error.message || "加载数据失败", "error");
  } finally {
    pageLoading.value = false;
  }
}

async function updateProfile() {
  saving.value = true;
  try {
    await server.auth.updateProfile.mutate({
      name: profile.name,
      email: profile.email,
      password: password.value || undefined
    });
    showMsg("已保存");
    password.value = "";
  } catch (error: any) {
    console.error(error);
    showMsg(error.message || "更新失败", "error");
  } finally {
    saving.value = false;
  }
}

async function confirmRename() {
  const hash = renameTarget.value;
  if (!hash) return;
  savingAlias.value = true;
  try {
    await server.auth.setTokenAlias.mutate({
      tokenHash: hash,
      alias: renameDraft.value.trim() || undefined
    });
    showMsg("已更新名称");
    renameDialog.value = false;
    renameTarget.value = null;
    await refreshTokens();
  } catch (error: any) {
    console.error(error);
    showMsg(error.message || "保存失败", "error");
  } finally {
    savingAlias.value = false;
  }
}

async function confirmRevoke() {
  const tokenHash = revokeTarget.value;
  if (!tokenHash) return;
  revoking.value = tokenHash;
  try {
    await server.auth.revokeToken.mutate({ tokenHash });
    showMsg("会话已移除");
    revokeDialog.value = false;
    revokeTarget.value = null;
    await refreshTokens();
  } catch (error: any) {
    console.error(error);
    showMsg(error.message || "删除失败", "error");
  } finally {
    revoking.value = null;
  }
}

onMounted(() => {
  loadData();
});
</script>
