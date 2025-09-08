<template>
	<div>
		<h1>Hello, World! about</h1>
		<router-link to="/">Home</router-link>
		<v-btn @click="goHome">Go Home</v-btn>
		<v-btn @click="$uigo('/')">Go Home</v-btn>
		<div>
			<v-text-field v-model="input" label="Input" />
			<v-btn @click="hello">Hello</v-btn>
			<v-btn v-if="ff">ciallo</v-btn>
			<p>{{ uploadUrl }}</p>
			<v-file-input v-model="file" label="File input" />
			<v-btn @click="getUploadUrl">Get Upload Url</v-btn>
			<v-btn @click="uploadFile">Upload File</v-btn>
			<v-btn @click="test">Test</v-btn>
		</div>
	</div>
</template>

<script setup lang="ts">
import { ref } from "vue";
import { uigo } from "../easyKit";
import { server } from "../server";
const input = ref("");
const ff = ref(false)
const uploadUrl = ref("");
const file = ref<File | null>(null);
async function getUploadUrl() {
	if(!file.value){
		alert("请选择文件");
		return;
	}
	const res = await server.image_bed.getUploadUrl.query({
		filename: input.value,
		type: file.value?.type
	});
	uploadUrl.value = res.url;
}
async function uploadFile() {
	if(!file.value){
		alert("请选择文件");
		return;
	}
	const res = await fetch(uploadUrl.value, {
		method: 'PUT',
		body: file.value,
		headers: {
			'content-type': file.value?.type
		}
	});
	console.log(await res.text());
	alert(res.status);
}
async function test() {
	const res = await server.image_bed.test.query();
	console.log(res);
}
async function hello() {
	try {
		const get = await server.hello2.query(input.value);
		input.value = get;
	} catch (error) {
		alert(error);
	}
}
function goHome() {
	uigo("/");
}
//错误处理
</script>
