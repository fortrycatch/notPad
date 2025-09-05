import { DataManager } from "./utils/data.js";
export const basicDataManager = new DataManager("basicData.json", {
    token: "null",
});
export const basicData = basicDataManager.getData();