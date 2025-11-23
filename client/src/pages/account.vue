<template>
  <div class="pa-4">
    <div class="d-flex align-center mb-4">
      <v-btn icon="mdi-arrow-left" variant="text" @click="$uigo('/')" class="mr-2"></v-btn>
      <h1>账户管理</h1>
    </div>

    <v-row>
      <v-col cols="12" md="6">
        <v-card>
          <v-card-title>个人信息</v-card-title>
          <v-card-text>
            <v-form @submit.prevent="updateProfile">
              <v-text-field
                v-model="profile.name"
                label="昵称"
                variant="outlined"
                density="comfortable"
                class="mb-2"
              ></v-text-field>
              
              <v-text-field
                v-model="profile.email"
                label="邮箱"
                variant="outlined"
                density="comfortable"
                class="mb-2"
              ></v-text-field>
              
              <v-text-field
                v-model="password"
                label="新密码 (留空则不修改)"
                type="password"
                variant="outlined"
                density="comfortable"
                class="mb-2"
                hint="如果不需要修改密码，请保持为空"
                persistent-hint
              ></v-text-field>
              
              <div class="d-flex justify-end mt-4">
                <v-btn
                  type="submit"
                  color="primary"
                  :loading="saving"
                >保存修改</v-btn>
              </div>
            </v-form>
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="6">
        <v-card>
          <v-card-title>登录凭证 (Sessions)</v-card-title>
          <v-card-text>
            <v-alert
              v-if="tokens.length === 0"
              type="info"
              variant="tonal"
              class="mb-4"
            >
              暂无Token信息
            </v-alert>
            
            <v-list v-else lines="two">
              <v-list-item
                v-for="token in tokens"
                :key="token.token"
                class="mb-2 border rounded"
              >
                <v-list-item-title class="font-weight-bold">
                  Token Hash: {{ token.token }}
                </v-list-item-title>
                
                <v-list-item-subtitle>
                  创建时间: {{ formatDate(token.created_at) }}
                </v-list-item-subtitle>
                
                <template v-slot:append>
                  <v-btn
                    icon="mdi-delete"
                    color="error"
                    variant="text"
                    size="small"
                    :loading="revoking === token.token"
                    @click="revokeToken(token.token)"
                  ></v-btn>
                </template>
              </v-list-item>
            </v-list>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-snackbar v-model="snackbar.show" :color="snackbar.color">
      {{ snackbar.text }}
      <template v-slot:actions>
        <v-btn variant="text" @click="snackbar.show = false">关闭</v-btn>
      </template>
    </v-snackbar>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, reactive } from "vue";
import { server } from "../server";

const profile = reactive({
  name: "",
  email: "",
  id: ""
});
const password = ref("");
const tokens = ref<any[]>([]);
const saving = ref(false);
const revoking = ref<string | null>(null);

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
  if (!dateStr) return '-';
  return new Date(dateStr).toLocaleString();
}

async function loadData() {
  try {
    const user = await server.auth.getProfile.query();
    profile.name = user.name;
    profile.email = user.email;
    profile.id = user.id;

    const tokenList = await server.auth.getTokens.query();
    tokens.value = tokenList;
  } catch (error: any) {
    console.error(error);
    showMsg(error.message || "加载数据失败", "error");
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
    showMsg("个人信息更新成功");
    password.value = ""; // clear password field
  } catch (error: any) {
    console.error(error);
    showMsg(error.message || "更新失败", "error");
  } finally {
    saving.value = false;
  }
}

async function revokeToken(tokenHash: string) {
  if (!confirm("确定要删除这个登录凭证吗？这将导致该设备下线。")) return;
  
  revoking.value = tokenHash;
  try {
    await server.auth.revokeToken.mutate({ tokenHash });
    showMsg("凭证已删除");
    // Refresh list
    const tokenList = await server.auth.getTokens.query();
    tokens.value = tokenList;
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
