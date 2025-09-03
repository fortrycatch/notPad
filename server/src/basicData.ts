import { DataManager } from "./utils/data";
export const basicDataManager = new DataManager("basicData.json", {
    token: "null",
});
export const basicData = basicDataManager.getData();