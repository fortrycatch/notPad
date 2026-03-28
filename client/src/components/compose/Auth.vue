<template>
    <!-- <transition name="slide-fade" mode="out-in"> -->
        <div class="auth-background">
            <div class="auth-container">
                <div class="auth-title">
                    <h1>{{ isLogin ? '登录' : '注册' }}</h1>
                </div>
                <form class="auth-form" @submit.prevent="isLogin ? login() : register()">
                    <!-- 登录表单 -->
                    <template v-if="isLogin">
                        <v-text-field 
                            v-model="username" 
                            label="用户ID/邮箱" 
                            :error-messages="usernameError"
                            hint="可以使用用户ID或邮箱登录"
                            persistent-hint
                        />
                        <v-text-field 
                            v-model="password" 
                            label="密码" 
                            type="password" 
                            :error-messages="passwordError"
                        />
                    </template>
                    <!-- 注册表单 -->
                    <template v-else>
                        <v-text-field 
                            v-model="user_id" 
                            label="用户ID（用于登录，不可重复）" 
                            :error-messages="userIdError"
                            hint="用户ID用于登录，不可重复"
                            persistent-hint
                        />
                        <v-text-field 
                            v-model="name" 
                            label="昵称（可重复）" 
                            :error-messages="nameError"
                            hint="昵称可以重复，用于显示"
                            persistent-hint
                        />
                        <v-text-field 
                            v-model="email" 
                            label="邮箱" 
                            type="email"
                            :error-messages="emailError"
                        />
                        <v-text-field 
                            v-model="password" 
                            label="密码（至少6位）" 
                            type="password" 
                            :error-messages="passwordError"
                        />
                    </template>
                    <v-btn 
                        type="submit"
                        class="auth-button"
                        :loading="loading"
                    > 
                        {{ isLogin ? '登录' : '注册' }}
                    </v-btn>
                    <div class="auth-switch">
                        <v-btn 
                            type="button"
                            variant="text" 
                            @click="switchMode"
                            class="switch-button"
                        >
                            {{ isLogin ? '还没有账号？立即注册' : '已有账号？立即登录' }}
                        </v-btn>
                    </div>
                </form>
            </div>
        </div>
    <!-- </transition> -->
    
    <!-- Snackbar 提示消息 -->
    <v-snackbar
        v-model="snackbar.show"
        :timeout="snackbar.timeout"
        :color="snackbar.color"
        location="top"
    >
        {{ snackbar.text }}
        <template v-slot:actions>
            <v-btn
                variant="text"
                @click="snackbar.show = false"
            >
                关闭
            </v-btn>
        </template>
    </v-snackbar>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { useMainStore } from '../../store/mainStore';
import { server } from '../../server';

const isLogin = ref(true);
const username = ref('');
const password = ref('');
const user_id = ref('');
const name = ref('');
const email = ref('');
const loading = ref(false);

const usernameError = ref('');
const passwordError = ref('');
const userIdError = ref('');
const nameError = ref('');
const emailError = ref('');

// Snackbar 状态
const snackbar = ref({
    show: false,
    text: '',
    color: 'info',
    timeout: 3000
});

// 显示提示消息
const showSnackbar = (text: string, color: 'success' | 'error' | 'warning' | 'info' = 'info', timeout: number = 3000) => {
    snackbar.value = {
        show: true,
        text,
        color,
        timeout
    };
};

const clearErrors = () => {
    usernameError.value = '';
    passwordError.value = '';
    userIdError.value = '';
    nameError.value = '';
    emailError.value = '';
};

const login = async () => {
    clearErrors();
    
    if (!username.value.trim()) {
        usernameError.value = '请输入用户名或邮箱';
        return;
    }
    if (!password.value.trim()) {
        passwordError.value = '请输入密码';
        return;
    }
    
    loading.value = true;
    try {
        const res = await server.auth.login.mutate({
            username: username.value.trim(),
            password: password.value
        });
        if (res.success && res.token) {
            const mainStore = useMainStore();
            mainStore.authenticated = true;
            mainStore.token = res.token;
            localStorage.setItem("token", res.token);
            mainStore.triggerRefresh(); // 触发刷新
            showSnackbar('登录成功', 'success');
            // 登录成功，可以关闭对话框或跳转
        } else {
            const message = 'message' in res ? res.message : '登录失败';
            showSnackbar(message, 'error');
        }
    } catch (error) {
        showSnackbar('登录失败，请稍后重试', 'error');
        console.error('登录错误:', error);
    } finally {
        loading.value = false;
    }
};

const register = async () => {
    clearErrors();
    
    let hasError = false;
    
    if (!user_id.value.trim()) {
        userIdError.value = '请输入用户ID';
        hasError = true;
    }
    
    if (!name.value.trim()) {
        nameError.value = '请输入昵称';
        hasError = true;
    }
    
    if (!email.value.trim()) {
        emailError.value = '请输入邮箱';
        hasError = true;
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.value.trim())) {
        emailError.value = '邮箱格式不正确';
        hasError = true;
    }
    
    if (!password.value.trim()) {
        passwordError.value = '请输入密码';
        hasError = true;
    } else if (password.value.length < 6) {
        passwordError.value = '密码长度至少6位';
        hasError = true;
    }
    
    if (hasError) {
        return;
    }
    
    loading.value = true;
    try {
        const res = await server.auth.register.mutate({
            user_id: user_id.value.trim(),
            name: name.value.trim(),
            email: email.value.trim(),
            password: password.value
        });
        if (res.success && 'token' in res && res.token) {
            const mainStore = useMainStore();
            mainStore.authenticated = true;
            mainStore.token = res.token;
            localStorage.setItem("token", res.token);
            mainStore.triggerRefresh(); // 触发刷新
            const message = 'message' in res ? res.message : '注册成功';
            showSnackbar(message, 'success');
            // 注册成功后自动登录，清空表单
            switchMode();
        } else {
            const message = 'message' in res ? res.message : '注册失败';
            showSnackbar(message, 'error');
        }
    } catch (error) {
        showSnackbar('注册失败，请稍后重试', 'error');
        console.error('注册错误:', error);
    } finally {
        loading.value = false;
    }
};

const switchMode = () => {
    clearErrors();
    // 清空表单
    username.value = '';
    password.value = '';
    user_id.value = '';
    name.value = '';
    email.value = '';
    // 切换模式
    isLogin.value = !isLogin.value;
};
</script>

<style scoped>
.auth-background {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.731);
    /* z-index: 1000; */
    display: flex;
    /* flex-direction: column; */
    align-items: center;
    justify-content: center;
}

.auth-container {
    width: 400px;
    min-height: 300px;
    background-color: rgb(var(--v-theme-surface));
    color: rgb(var(--v-theme-on-surface));
    border-radius: 10px;
    padding: 20px;
    display: flex;
    flex-direction: column;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.24);
}

.auth-title {
    text-align: center;
    margin-bottom: 20px;
}

.auth-title h1 {
    margin: 0;
    font-size: 24px;
    font-weight: 500;
    color: rgb(var(--v-theme-on-surface));
}

.auth-form {
    display: flex;
    flex-direction: column;
    gap: 16px;
    flex: 1;
}

.auth-button {
    width: 100%;
    margin-top: 8px;
}

.auth-switch {
    text-align: center;
    margin-top: 8px;
}

.switch-button {
    text-transform: none;
    font-size: 14px;
}
</style>