<template>
    <v-app>
        <v-app-bar>
            <v-btn icon="mdi-menu" @click="drawer = !drawer"></v-btn>
            <v-toolbar-title>{{ title }}</v-toolbar-title>
            <slot name="bar" />
        </v-app-bar>
        <v-navigation-drawer v-model="drawer" expand-on-hover :permanent="!isMobile" :rail="!isMobile"
            :temporary="isMobile">
            <slot name="drawer" />
        </v-navigation-drawer>
        <v-main>
            <div class="main">
                <slot />
                <router-view v-slot="{ Component }">
                    <!-- <transition name="slide-fade" mode="out-in"> -->
                        <component :is="Component" />
                    <!-- </transition> -->
                </router-view>
            </div>
        </v-main>
        <Auth v-if="!mainStore.authenticated" />
    </v-app>

</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import Auth from '../compose/Auth.vue';
import { useMainStore } from '../../store/mainStore';
const mainStore = useMainStore();
// const auth = ref(true);
const drawer = ref(false);
defineProps<{
    title: string;
}>();
const isMobile = ref(false);
onMounted(() => {
    isMobile.value = window.innerWidth < 1000;
    addEventListener('resize', () => {
        isMobile.value = window.innerWidth < 1000;
    });
});
</script>

<style scoped>
.main {
    padding: 10px;
}
</style>