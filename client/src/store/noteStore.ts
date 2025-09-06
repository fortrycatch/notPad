import { defineStore } from "pinia";
interface Note {
    id: string
    title: string
    content: string
    created_at: string
    updated_at: string
    userId: string
  }
export default defineStore("note", {
    state: () => ({
        notes: [] as Note[],
    })
})