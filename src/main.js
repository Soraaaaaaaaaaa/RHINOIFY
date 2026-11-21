const { app, BrowserWindow, ipcMain, shell, dialog } = require("electron");
const { execFile } = require("child_process");
const path = require("path");
const fs = require("fs");
const https = require("https");
const AdmZip = require("adm-zip");

const THEME_REPO = "spicetify/spicetify-themes";
let catalogCache = { at: 0, themes: [] };

function runSpicetify(args = []) {
  return new Promise((resolve) => {
    execFile("spicetify", args, { windowsHide: true, timeout: 45000 }, (error, stdout, stderr) => {
      resolve({ ok: !error, output: (stdout || stderr || (error ? error.message : "Command completed")).trim() });
    });
  });
}

async function getSpicetifyPath(args, fallbackName) {
  const result = await runSpicetify(["path", ...args]);
  if (result.ok && result.output) {
    const candidate = result.output.split(/\r?\n/).map(x => x.trim()).filter(Boolean).at(-1);
    if (candidate && path.isAbsolute(candidate)) return candidate.replace(/^"|"$/g, "");
  }
  return path.join(process.env.APPDATA || app.getPath("appData"), "spicetify", fallbackName);
}
async function getThemesPath() { return path.join(process.env.APPDATA || app.getPath("appData"), "spicetify", "Themes"); }
async function getExtensionsPath() { return getSpicetifyPath(["-e", "root"], "Extensions"); }
async function getCustomAppsPath() { return getSpicetifyPath(["-a", "root"], "CustomApps"); }

async function getConfigList(key) {
  const configPath = await runSpicetify(["-c"]);
  if (!configPath.ok) return [];
  const filePath = configPath.output.split(/\r?\n/).map(x => x.trim()).filter(Boolean).at(-1).replace(/^"|"$/g, "");
  if (!filePath || !fs.existsSync(filePath)) return [];
  const content = fs.readFileSync(filePath, "utf8");
  const match = content.match(new RegExp(`^\\s*${key}\\s*=\\s*(.*)$`, "mi"));
  return match && match[1].trim() ? match[1].trim().split("|").map(x => x.trim()).filter(Boolean) : [];
}
function safeItemName(name) { return typeof name === "string" && /^[a-zA-Z0-9 _.-]{1,100}$/.test(name) && !name.includes(".."); }
async function listComponents(type) {
  const isExtension = type === "extensions";
  const root = isExtension ? await getExtensionsPath() : await getCustomAppsPath();
  const enabled = await getConfigList(isExtension ? "extensions" : "custom_apps");
  fs.mkdirSync(root, { recursive: true });
  const items = fs.readdirSync(root, { withFileTypes: true }).filter(entry => isExtension ? entry.isFile() && entry.name.toLowerCase().endsWith(".js") : entry.isDirectory() && fs.existsSync(path.join(root, entry.name, "index.js")) && fs.existsSync(path.join(root, entry.name, "manifest.json")));
  return items.map(entry => ({ name: isExtension ? entry.name : entry.name, enabled: enabled.includes(entry.name) })).sort((a,b) => a.name.localeCompare(b.name));
}
async function toggleComponent(type, name, enabled) {
  const isExtension = type === "extensions";
  if (!safeItemName(name) || (isExtension && !name.toLowerCase().endsWith(".js"))) throw new Error("Invalid component name.");
  const root = isExtension ? await getExtensionsPath() : await getCustomAppsPath();
  const target = path.join(root, name);
  if (!target.startsWith(root + path.sep) || !fs.existsSync(target)) throw new Error("Component file or folder was not found.");
  const result = await runSpicetify(["config", isExtension ? "extensions" : "custom_apps", enabled ? name : `${name}-`]);
  if (!result.ok) return result;
  return runSpicetify(["apply"]);
}
async function installLocalComponent(type) {
  const isExtension = type === "extensions";
  const selection = await dialog.showOpenDialog({
    title: isExtension ? "Select a Spicetify extension" : "Select a Spicetify custom app folder",
    properties: isExtension ? ["openFile"] : ["openDirectory"],
    ...(isExtension ? { filters: [{ name: "JavaScript extension", extensions: ["js"] }] } : {})
  });
  if (selection.canceled || !selection.filePaths[0]) return { ok: false, output: "Installation cancelled." };
  const selected = selection.filePaths[0];
  const root = isExtension ? await getExtensionsPath() : await getCustomAppsPath();
  fs.mkdirSync(root, { recursive: true });
  if (isExtension) {
    const name = path.basename(selected);
    if (!safeItemName(name) || !name.toLowerCase().endsWith(".js")) throw new Error("Choose a valid .js extension file.");
    fs.copyFileSync(selected, path.join(root, name));
    return { ok: true, output: `Installed ${name}. Enable it from the Extensions list.` };
  }
  const name = path.basename(selected);
  if (!safeItemName(name) || !fs.existsSync(path.join(selected, "index.js")) || !fs.existsSync(path.join(selected, "manifest.json"))) throw new Error("The selected folder must contain index.js and manifest.json.");
  const destination = path.join(root, name);
  if (fs.existsSync(destination)) throw new Error("A custom app with that folder name is already installed.");
  fs.cpSync(selected, destination, { recursive: true, errorOnExist: true });
  return { ok: true, output: `Installed custom app ${name}. Enable it from the Custom Apps list.` };
}

function findSpotify() {
  const candidates = [
    path.join(process.env.APPDATA || "", "Spotify", "Spotify.exe"),
    path.join(process.env.LOCALAPPDATA || "", "Microsoft", "WindowsApps", "Spotify.exe"),
    path.join(process.env.LOCALAPPDATA || "", "Spotify", "Spotify.exe")
  ];
  return candidates.find(p => p && fs.existsSync(p)) || null;
}

async function requestJson(url) {
  const response = await fetch(url, { headers: { "User-Agent": "RHINOIFY-Desktop", "Accept": "application/vnd.github+json" } });
  if (!response.ok) throw new Error(`GitHub returned ${response.status} for ${url}`);
  return response.json();
}

function safeThemeName(name) {
  return typeof name === "string" && /^[a-zA-Z0-9 _.-]{1,80}$/.test(name) && !name.includes("..");
}

async function getThemeCatalog() {
  if (Date.now() - catalogCache.at < 10 * 60 * 1000 && catalogCache.themes.length) return catalogCache.themes;
  const repo = await requestJson(`https://api.github.com/repos/${THEME_REPO}`);
  const branch = repo.default_branch || "master";
  const tree = await requestJson(`https://api.github.com/repos/${THEME_REPO}/git/trees/${encodeURIComponent(branch)}?recursive=1`);
  if (tree.truncated) throw new Error("The community theme catalog is too large to retrieve in one request.");
  const files = new Set((tree.tree || []).filter(x => x.type === "blob").map(x => x.path));
  const folders = new Set();
  for (const file of files) {
    if (!file.endsWith("/color.ini")) continue;
    const folder = file.slice(0, -"/color.ini".length);
    if (files.has(`${folder}/user.css`)) folders.add(folder);
  }
  const themes = [...folders]
    .filter(folder => !folder.startsWith("_") && !folder.includes("/"))
    .map(folder => ({
      name: folder,
      description: "Community theme from the official Spicetify themes collection.",
      source: `https://github.com/${THEME_REPO}/tree/${branch}/${encodeURIComponent(folder)}`,
      repo: THEME_REPO,
      branch
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
  catalogCache = { at: Date.now(), themes };
  return themes;
}

async function listInstalledThemes() {
  const root = await getThemesPath();
  if (!fs.existsSync(root)) return [];
  return fs.readdirSync(root, { withFileTypes: true })
    .filter(entry => entry.isDirectory())
    .filter(entry => fs.existsSync(path.join(root, entry.name, "color.ini")) && fs.existsSync(path.join(root, entry.name, "user.css")))
    .map(entry => entry.name)
    .sort((a, b) => a.localeCompare(b));
}

async function installTheme(name) {
  if (!safeThemeName(name)) throw new Error("Invalid theme name.");
  const catalog = await getThemeCatalog();
  const theme = catalog.find(item => item.name === name);
  if (!theme) throw new Error("That theme is not in the verified community catalog.");

  const archiveUrl = `https://codeload.github.com/${theme.repo}/zip/refs/heads/${encodeURIComponent(theme.branch)}`;
  const response = await fetch(archiveUrl, { headers: { "User-Agent": "RHINOIFY-Desktop" } });
  if (!response.ok) throw new Error(`Theme download failed (${response.status}).`);
  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length > 100 * 1024 * 1024) throw new Error("Theme archive is larger than the 100 MB safety limit.");

  const zip = new AdmZip(bytes);
  const root = await getThemesPath();
  const staging = path.join(root, `.rhinoify-install-${Date.now()}`);
  fs.mkdirSync(staging, { recursive: true });
  const prefix = `/${theme.name}/`;
  let extracted = 0;

  try {
    for (const entry of zip.getEntries()) {
      if (entry.isDirectory) continue;
      const normalized = entry.entryName.replace(/\\/g, "/");
      const marker = normalized.indexOf(prefix);
      if (marker < 0) continue;
      const relative = normalized.slice(marker + prefix.length);
      if (!relative || relative.startsWith("/") || relative.split("/").some(part => part === "..")) continue;
      const destination = path.join(staging, ...relative.split("/"));
      if (!destination.startsWith(staging + path.sep)) continue;
      fs.mkdirSync(path.dirname(destination), { recursive: true });
      fs.writeFileSync(destination, entry.getData());
      extracted++;
    }

    if (!fs.existsSync(path.join(staging, "color.ini")) || !fs.existsSync(path.join(staging, "user.css"))) {
      throw new Error("This repository entry did not contain the required color.ini and user.css files.");
    }

    const target = path.join(root, name);
    const backup = path.join(root, `.rhinoify-backup-${Date.now()}`);
    if (fs.existsSync(target)) fs.renameSync(target, backup);
    try {
      fs.renameSync(staging, target);
      if (fs.existsSync(backup)) fs.rmSync(backup, { recursive: true, force: true });
    } catch (error) {
      if (fs.existsSync(backup) && !fs.existsSync(target)) fs.renameSync(backup, target);
      throw error;
    }
    return { ok: true, output: `Installed ${name} (${extracted} files).` };
  } catch (error) {
    fs.rmSync(staging, { recursive: true, force: true });
    throw error;
  }
}

async function getSchemes(name) {
  if (!safeThemeName(name)) return [];
  const iniPath = path.join(await getThemesPath(), name, "color.ini");
  if (!fs.existsSync(iniPath)) return [];
  const content = fs.readFileSync(iniPath, "utf8");
  return [...content.matchAll(/^\s*\[([^\]]+)\]\s*$/gm)]
    .map(match => match[1].trim())
    .filter(scheme => scheme && scheme.toLowerCase() !== "base");
}

async function applyTheme(name, scheme) {
  if (!safeThemeName(name)) throw new Error("Invalid theme name.");
  const themePath = path.join(await getThemesPath(), name);
  if (!fs.existsSync(path.join(themePath, "color.ini")) || !fs.existsSync(path.join(themePath, "user.css"))) {
    throw new Error("Theme is not installed or is missing required files.");
  }
  const config = await runSpicetify(["config", "current_theme", name]);
  if (!config.ok) return config;
  const schemeResult = await runSpicetify(["config", "color_scheme", scheme || ""]);
  if (!schemeResult.ok) return schemeResult;
  const css = await runSpicetify(["config", "inject_css", "1", "replace_colors", "1"]);
  if (!css.ok) return css;
  return runSpicetify(["apply"]);
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1160, height: 790, minWidth: 900, minHeight: 650,
    backgroundColor: "#090909", title: "RH!NOIFY",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true, nodeIntegration: false, sandbox: true
    }
  });
  win.loadFile(path.join(__dirname, "index.html"));
}

ipcMain.handle("system:status", async () => {
  const spotify = findSpotify();
  const spicetify = await runSpicetify(["-v"]);
  return {
    spotifyInstalled: Boolean(spotify), spotifyPath: spotify,
    spicetifyInstalled: spicetify.ok, spicetifyVersion: spicetify.ok ? spicetify.output : null
  };
});
ipcMain.handle("spicetify:backup-apply", async () => {
  const backup = await runSpicetify(["backup"]);
  if (!backup.ok) return backup;
  return runSpicetify(["apply"]);
});
ipcMain.handle("spicetify:restore", () => runSpicetify(["restore"]));
ipcMain.handle("spicetify:update", () => runSpicetify(["update"]));
ipcMain.handle("themes:list", () => listInstalledThemes());
ipcMain.handle("components:list", (_event, type) => listComponents(type));
ipcMain.handle("components:install", (_event, type) => installLocalComponent(type));
ipcMain.handle("components:toggle", (_event, type, name, enabled) => toggleComponent(type, name, enabled));
ipcMain.handle("themes:catalog", async () => getThemeCatalog());
ipcMain.handle("themes:install", async (_event, name) => installTheme(name));
ipcMain.handle("themes:schemes", async (_event, name) => getSchemes(name));
ipcMain.handle("themes:apply", async (_event, name, scheme) => applyTheme(name, scheme));
ipcMain.handle("open:external", async (_event, url) => {
  if (typeof url !== "string" || !url.startsWith("https://github.com/")) throw new Error("Only GitHub HTTPS links are allowed.");
  await shell.openExternal(url);
  return { ok: true };
});
ipcMain.handle("open:themes", async () => {
  const themesPath = await getThemesPath();
  fs.mkdirSync(themesPath, { recursive: true });
  await shell.openPath(themesPath);
  return { ok: true, output: themesPath };
});

app.whenReady().then(createWindow);
app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });
