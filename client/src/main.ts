import { createApp } from "vue";
import "./style.css";
import App from "./App.vue";

import { createPinia } from "pinia";
const pinia = createPinia();

// Vuetify

import { createVuetify } from "vuetify";
import * as components from "vuetify/components";
import * as directives from "vuetify/directives";
import '@mdi/font/css/materialdesignicons.css'
// import { md3 } from 'vuetify/blueprints'

const defaultDarkMode = localStorage.getItem("darkMode") !== "false";

const DEFAULT_PRIMARY = '#ff9edd';
const cachedPrimary = (() => {
	try {
		const s = JSON.parse(localStorage.getItem("userSettings") || "{}");
		return s.primaryColor || DEFAULT_PRIMARY;
	} catch { return DEFAULT_PRIMARY; }
})();

const vuetify = createVuetify({
	// blueprint: md3,
	components,
	directives,
	icons: {
		defaultSet: 'mdi',
	},
	theme: {
		defaultTheme: defaultDarkMode ? "dark" : "light",
		themes: {
			light: {
				colors: {
					primary: cachedPrimary,
					background: '#fff7fb',
					surface: '#ffffff',
					'surface-bright': '#fff7fb',
					'surface-variant': '#f9e7f2',
					'on-surface-variant': '#6c5f67',
				}
			},
			dark: {
				dark: true,
				colors: {
					primary: cachedPrimary,
					background: '#121018',
					surface: '#1b1724',
					'surface-bright': '#241d31',
					'surface-variant': '#31283f',
					secondary: '#caa6ff',
					'on-surface': '#f3edf7',
					'on-surface-variant': '#d5c2d8',
				}
			}
		}
	}
});

import routes from "~pages";
import { createRouter, createWebHistory } from "vue-router";
import { easyKitPlugin } from "./easyKit";

const router = createRouter({
	history: createWebHistory(),
	routes,
});



const app = createApp(App);

// 安装 easyKit 插件
app.use(easyKitPlugin, router);
app.use(pinia);
app.use(vuetify).use(router).mount("#app");
