<template>
  <v-container>
    <v-row>
      <v-col cols="12" class="text-center">
        <v-card class="welcome-card" elevation="0">
          <v-card-text>
            <v-icon size="80" color="primary" class="mb-6">
              mdi-cards-playing-heart-multiple
            </v-icon>
            <h1 class="text-h3 font-weight-bold mb-4">BasicCloud</h1>
            <p class="text-body-1 text-medium-emphasis mb-6">
              云，小工具，轻量云基建
            </p>
            <div class="container-button">
              <v-btn color="primary" size="large" prepend-icon="mdi-note-text" @click="goToNotes">
                开始使用
              </v-btn>
              <v-btn size="large" prepend-icon="mdi-information" @click="goToAbout">
                了解更多
              </v-btn>
            </div>
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
.container-button{
  > * {
    margin-right: 20px;
  }
}
</style>
