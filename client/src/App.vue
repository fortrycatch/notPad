<script setup lang="ts">
// import { ref } from "vue";
// import { server } from "./server";
import Normal from "./components/frame/Normal.vue";
import routes from "~pages";
import { onMounted } from "vue";
import { uigo } from "./easyKit";
import { useMainStore } from "./store/mainStore";
// const test = ref("null");
// const input = ref("");
// async function hello() {
// 	const res = await server.hello.query(input.value);
// 	test.value = res;
// }
console.log(routes);
import { server } from "./server";
onMounted(async () => {
	if(await server.verifyToken.query(localStorage.getItem("token") || "") == false){
		uigo("/login");
	}else{
		useMainStore().authenticated = true;
		useMainStore().token = localStorage.getItem("token") || "";
	}
});
</script>

<template>
  
    <Normal title="Normal App" >
		<template #bar>
			<v-btn icon="mdi-account-card"></v-btn>
		</template>
		<template #drawer>
			<v-list-item link title="首页" prepend-icon="mdi-home" to="/"></v-list-item>
			<v-list-item link title="笔记" prepend-icon="mdi-note-text" to="/notes"></v-list-item>
			<v-list-item link title="关于" prepend-icon="mdi-information" to="/about"></v-list-item>
			<v-list-item link title="设置" prepend-icon="mdi-cog" to="/setting"></v-list-item>
		</template>
	</Normal>

</template>

<style scoped></style>
