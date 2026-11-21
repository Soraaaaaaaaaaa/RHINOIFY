const $ = id => document.getElementById(id);
let catalog = [], installed = [], activeFilter = "all";
function log(message){$("log").textContent=message;}
function setBadge(id,text,type){const el=$(id);el.textContent=text;el.className="state "+(type||"");}
async function refresh(){
  log("Checking Spotify and Spicetify…");
  try{
    const s=await window.rhino.status();
    $("spotify-state").textContent=s.spotifyInstalled?"Spotify desktop app detected":"Spotify desktop app not found";
    setBadge("spotify-badge",s.spotifyInstalled?"DETECTED":"NOT FOUND",s.spotifyInstalled?"good":"bad");
    $("spicetify-state").textContent=s.spicetifyInstalled?`Version ${s.spicetifyVersion}`:"Spicetify CLI is not available in PATH";
    setBadge("spicetify-badge",s.spicetifyInstalled?"READY":"NOT INSTALLED",s.spicetifyInstalled?"good":"bad");
    $("checked-at").textContent="CHECKED "+new Date().toLocaleTimeString();
    log("System check complete.");
  }catch(e){log("Could not check system: "+e.message);}
}
async function action(label, fn){
  log(label+"…");
  try{const r=await fn();log((r.ok?"Success: ":"Could not complete: ")+r.output);await refresh();}
  catch(e){log("Error: "+e.message);}
}
function showPage(page){
  document.querySelectorAll(".nav").forEach(b=>b.classList.toggle("active",b.dataset.page===page));
  document.querySelectorAll(".page").forEach(p=>p.classList.toggle("hidden",p.id!==page));
  $("page-title").textContent=({home:"Overview",themes:"Themes",extensions:"Extensions",settings:"Settings"})[page];
  if(page==="themes"&&!catalog.length) loadCatalog();
  if(page==="extensions") loadComponents();
}
document.querySelectorAll(".nav").forEach(b=>b.addEventListener("click",()=>showPage(b.dataset.page)));
$("refresh").addEventListener("click",refresh);
$("apply").addEventListener("click",()=>action("Backing up Spotify and applying customizations",window.rhino.backupApply));
$("restore").addEventListener("click",()=>action("Restoring Spotify",window.rhino.restore));
$("update").addEventListener("click",()=>action("Updating Spicetify CLI",window.rhino.update));
$("open-themes").addEventListener("click",async()=>{const r=await window.rhino.openThemes();log("Opened themes folder: "+r.output);});
$("source-link").addEventListener("click",async e=>{e.preventDefault();await window.rhino.openExternal("https://github.com/spicetify/spicetify-themes");});

$("reload-themes").addEventListener("click",()=>{catalog=[];loadCatalog(true);});
$("theme-search").addEventListener("input",renderThemes);
document.querySelectorAll(".filter").forEach(b=>b.addEventListener("click",()=>{
  activeFilter=b.dataset.filter;
  document.querySelectorAll(".filter").forEach(x=>x.classList.toggle("active",x===b));
  renderThemes();
}));
async function loadCatalog(force=false){
  $("catalog-status").textContent=force?"Refreshing official community catalog…":"Loading official community catalog…";
  try{
    const [items,local]=await Promise.all([window.rhino.themeCatalog(),window.rhino.listThemes()]);
    catalog=items;installed=local;
    $("theme-count").textContent=installed.length;
    $("catalog-status").textContent=`${catalog.length} community themes · ${installed.length} installed`;
    renderThemes();
    log("Theme catalog loaded.");
  }catch(e){
    $("catalog-status").textContent="Could not load the theme catalog: "+e.message;
    log("Marketplace error: "+e.message);
  }
}
function renderThemes(){
  const query=$("theme-search").value.trim().toLowerCase();
  const grid=$("theme-grid");grid.innerHTML="";
  const filtered=catalog.filter(t=>{
    const isInstalled=installed.includes(t.name);
    return (!query||t.name.toLowerCase().includes(query)||t.description.toLowerCase().includes(query)) &&
      (activeFilter==="all"||(activeFilter==="installed"&&isInstalled)||(activeFilter==="available"&&!isInstalled));
  });
  if(!filtered.length){grid.innerHTML='<div class="no-results">No themes match this search.</div>';return;}
  for(const theme of filtered){
    const isInstalled=installed.includes(theme.name);
    const card=document.createElement("article");card.className="theme-card";
    const art=document.createElement("div");art.className="theme-art";
    art.innerHTML='<span class="art-mark">R!</span><span class="art-caption">COMMUNITY THEME</span>';
    const info=document.createElement("div");info.className="theme-info";
    const title=document.createElement("div");title.className="theme-title";
    const h=document.createElement("h3");h.textContent=theme.name;
    const badge=document.createElement("span");badge.className=isInstalled?"installed-tag":"source-tag";badge.textContent=isInstalled?"INSTALLED":"COMMUNITY";
    title.append(h,badge);
    const desc=document.createElement("p");desc.textContent=theme.description;
    const controls=document.createElement("div");controls.className="theme-controls";
    const button=document.createElement("button");button.className="theme-button";
    button.textContent=isInstalled?"APPLY THEME":"INSTALL THEME";
    button.addEventListener("click",()=>isInstalled?applyInstalled(theme.name):install(theme.name,button));
    const link=document.createElement("button");link.className="repo-button";link.textContent="SOURCE ↗";
    link.addEventListener("click",()=>window.rhino.openExternal(theme.source));
    controls.append(button,link);info.append(title,desc,controls);card.append(art,info);grid.append(card);
  }
}
async function install(name,button){
  button.disabled=true;button.textContent="INSTALLING…";log("Downloading and installing "+name+"…");
  try{
    const result=await window.rhino.installTheme(name);
    if(!result.ok)throw new Error(result.output);
    installed=await window.rhino.listThemes();$("theme-count").textContent=installed.length;
    $("catalog-status").textContent=`${catalog.length} community themes · ${installed.length} installed`;
    renderThemes();log(result.output);
  }catch(e){button.disabled=false;button.textContent="INSTALL THEME";log("Install failed: "+e.message);}
}
async function applyInstalled(name){
  log("Reading color schemes for "+name+"…");
  try{
    const schemes=await window.rhino.themeSchemes(name);
    const scheme=schemes[0]||"";
    const result=await window.rhino.applyTheme(name,scheme);
    log((result.ok?"Applied ":"Could not apply ")+name+(scheme?" · "+scheme:"")+": "+result.output);
  }catch(e){log("Apply failed: "+e.message);}
}
refresh();

async function loadComponents(){
  for(const [type,target] of [["extensions","extension-list"],["custom_apps","custom-app-list"]]){
    const list=$(target); list.innerHTML='<div class="no-results">Loading…</div>';
    try{
      const items=await window.rhino.listComponents(type); list.innerHTML="";
      if(!items.length){list.innerHTML='<div class="no-results">Nothing installed here yet.</div>';continue;}
      for(const item of items){
        const row=document.createElement("div");row.className="component-row";
        const details=document.createElement("div");details.className="component-details";
        const name=document.createElement("strong");name.textContent=item.name;
        const status=document.createElement("span");status.className=item.enabled?"component-status enabled":"component-status";status.textContent=item.enabled?"ENABLED":"DISABLED";
        details.append(name,status);
        const button=document.createElement("button");button.className="secondary small";button.textContent=item.enabled?"DISABLE":"ENABLE";
        button.addEventListener("click",async()=>{
          button.disabled=true;log(`${item.enabled?"Disabling":"Enabling"} ${item.name}…`);
          try{const result=await window.rhino.toggleComponent(type,item.name,!item.enabled);log((result.ok?"Success: ":"Could not complete: ")+result.output);await loadComponents();}
          catch(e){log("Could not update component: "+e.message);button.disabled=false;}
        });
        row.append(details,button);list.append(row);
      }
    }catch(e){list.innerHTML='<div class="no-results">Could not load components.</div>';log(e.message);}
  }
}
$("reload-components").addEventListener("click",loadComponents);
$("install-extension").addEventListener("click",async()=>{try{const r=await window.rhino.installComponent("extensions");log(r.output);await loadComponents();}catch(e){log("Extension install failed: "+e.message);}});
$("install-custom-app").addEventListener("click",async()=>{try{const r=await window.rhino.installComponent("custom_apps");log(r.output);await loadComponents();}catch(e){log("Custom app install failed: "+e.message);}});
