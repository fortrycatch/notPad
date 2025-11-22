import { defineStore } from "pinia";
interface Note {
    id: string
    title: string
    content: string
    created_at: string | Date
    updated_at: string | Date
  }
export default defineStore("note", {
    state: () => ({
        notes: [] as Note[],
    })
})