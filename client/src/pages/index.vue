<template>
  <v-container>
    <v-row>
      <v-col cols="12" class="text-center">
        <v-card class="welcome-card" elevation="0">
          <v-card-text>
            <v-icon size="80" color="primary" class="mb-6">
              mdi-home
            </v-icon>
            <h1 class="text-h3 font-weight-bold mb-4">欢迎使用笔记应用</h1>
            <p class="text-body-1 text-medium-emphasis mb-6">
              这是一个简单而强大的笔记管理应用，帮助你记录和管理你的想法和重要信息。
            </p>
            <div class="d-flex justify-center gap-4">
              <v-btn
                color="primary"
                size="large"
                prepend-icon="mdi-note-text"
                @click="goToNotes"
              >
                开始使用
              </v-btn>
              <v-btn
                variant="outlined"
                size="large"
                prepend-icon="mdi-information"
                @click="goToAbout"
              >
                了解更多
              </v-btn>
            </div>
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>

    <v-row class="mt-8">
      <v-col cols="12" md="4">
        <v-card class="feature-card" elevation="2">
          <v-card-title class="d-flex align-center">
            <v-icon color="primary" class="mr-3">mdi-pencil</v-icon>
            简单编辑
          </v-card-title>
          <v-card-text>
            直观的编辑界面，让你轻松创建和修改笔记内容。
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card class="feature-card" elevation="2">
          <v-card-title class="d-flex align-center">
            <v-icon color="primary" class="mr-3">mdi-view-list</v-icon>
            清晰列表
          </v-card-title>
          <v-card-text>
            卡片式布局，一目了然地查看所有笔记。
          </v-card-text>
        </v-card>
      </v-col>

      <v-col cols="12" md="4">
        <v-card class="feature-card" elevation="2">
          <v-card-title class="d-flex align-center">
            <v-icon color="primary" class="mr-3">mdi-shield-check</v-icon>
            安全可靠
          </v-card-title>
          <v-card-text>
            数据安全存储，确保你的笔记永远不会丢失。
          </v-card-text>
        </v-card>
      </v-col>
    </v-row>
  </v-container>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'

const router = useRouter()

const goToNotes = () => {
  router.push('/notes')
}

const goToAbout = () => {
  router.push('/about')
}
</script>

<style scoped>
.welcome-card {
  padding: 60px 20px;
}

.feature-card {
  height: 100%;
  text-align: center;
}
</style>
