const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("rhino", {
  status: () => ipcRenderer.invoke("system:status"),
  backupApply: () => ipcRenderer.invoke("spicetify:backup-apply"),
  restore: () => ipcRenderer.invoke("spicetify:restore"),
  update: () => ipcRenderer.invoke("spicetify:update"),
  openThemes: () => ipcRenderer.invoke("open:themes"),
  openExternal: url => ipcRenderer.invoke("open:external", url),
  listThemes: () => ipcRenderer.invoke("themes:list"),
  themeCatalog: () => ipcRenderer.invoke("themes:catalog"),
  installTheme: name => ipcRenderer.invoke("themes:install", name),
  themeSchemes: name => ipcRenderer.invoke("themes:schemes", name),
  applyTheme: (name, scheme) => ipcRenderer.invoke("themes:apply", name, scheme),
  listComponents: type => ipcRenderer.invoke("components:list", type),
  installComponent: type => ipcRenderer.invoke("components:install", type),
  toggleComponent: (type, name, enabled) => ipcRenderer.invoke("components:toggle", type, name, enabled)
});
