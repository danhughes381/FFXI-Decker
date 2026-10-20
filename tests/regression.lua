-- LuaJIT tests use explicit host mocks: no game process or native calls.
local root=arg[1] or '.'
local events={}; local requested={}; local character='Salts'; local styles=0; local vars=0
addon={}
package.preload.common=function() return {} end
package.preload.chat=function() return {header=function() return '' end} end
local ui={}
for _,name in ipairs({'Text','TextWrapped','Separator','SameLine','SetNextWindowSize','End','EndCombo','NewLine'}) do ui[name]=function() end end
for _,name in ipairs({'Button','Checkbox','Selectable','InputText'}) do ui[name]=function() return false end end
ui.Begin=function() return true end; ui.BeginCombo=function() return true end; ui.CollapsingHeader=function() return true end
ui.PushStyleColor=function(c) assert(type(c)=='number','invalid colour constant'); styles=styles+1 end
ui.PopStyleColor=function(n) styles=styles-(n or 1); assert(styles>=0) end
ui.PushStyleVar=function(c) assert(type(c)=='number'); vars=vars+1 end
ui.PopStyleVar=function() vars=vars-1; assert(vars>=0) end
ui.GetContentRegionAvail=function() return {1100,400} end
package.preload.imgui=function() return ui end
local ffi={cdef=function() end,cast=function(_,value) if type(value)=='table' then return value end; return function() requested[#requested+1]='macro' end end}
package.loaded.ffi=ffi
ImGuiCol_Button=1; ImGuiCol_ButtonHovered=2; ImGuiCol_ButtonActive=3; ImGuiCol_Text=4; ImGuiStyleVar_Alpha=1; ImGuiCond_FirstUseEver=1
ashita={events={register=function(_,name,cb) assert(not events[name]);events[name]=cb end},memory={read_uint32=function() return 65536 end}}
local player={GetName=function() return character end,GetServerId=function() return 1 end}
AshitaCore={GetMemoryManager=function() return {GetPlayer=function() return player end} end,GetChatManager=function() return {QueueCommand=function(_,mode,c) assert(mode==-1);requested[#requested+1]=c end} end}
local f=assert(io.open(root..'/addons/decker/decker.lua'));local source=f:read('*a');f:close()
local expose='\nreturn {state=state,glass=glass,drawrow=draw_row,pair=pair,nav=nav_command,refresh=refresh_profile,save=save_display,load=load_display,request=request_statebar,valid=valid_command,reset=restore_section,mapped=mapped_key,hotkey=statebar_hotkey_slot,execute=execute_slot,updater=updater,manifest=update_manifest,newer=update_newer,promote=update_promote,rollback=update_rollback,start=update_start,poll=update_poll,updateScript=update_script,setKernel=function(k) update_kernel=k end}'
-- Profile IO goes into an isolated directory, preserving real user settings.
local tmp=os.tmpname();os.remove(tmp);assert(os.execute('mkdir -p '..tmp)==0)
local path=tmp..'/decker.lua';f=assert(io.open(path,'w'));f:write(source,expose);f:close()
local api=assert(loadfile(path))();local s=api.state
local passed=0
local function test(name,fn) fn();passed=passed+1;print('PASS '..name) end
local function ready() s.phase=4;s.allowAllClicks=true;s.profileReady=true;s.names={};for i=1,20 do s.names[i]='Macro'..i end;s.addresses.controller=65536;s.addresses.run=65536 end
api.refresh()
test('first install: safe defaults and Quick Setup',function() assert(s.profileId=='1_Salts' and not s.keybinds and not s.autoHide and s.settingsTab=='Controls') end)
test('profile switching isolates all settings',function()
 s.theme=4;s.scale=1.4;s.statebarSelected=3;s.statebarHotkeys={87};s.statebarHotkeysEnabled=true;s.savedNavEnabled=true;s.navQueue={200};s.names={'stale'};api.save();character='Pepper';api.refresh()
 assert(s.theme==1 and s.scale==1 and s.statebarSelected==0 and not s.statebarHotkeysEnabled and not s.savedNavEnabled and #s.navQueue==0 and #s.names==0 and not s.allowAllClicks)
 s.theme=2;api.save();character='Salts';api.refresh();assert(s.theme==4 and s.scale==1.4 and s.statebarSelected==3 and s.statebarHotkeys[1]==87)
end)
test('profile reload and zero slots persist',function() s.statebarSlots={};api.save();s.statebarSlots={{row='CTRL',slot=1}};api.load();assert(#s.statebarSlots==0) end)
test('State and Utility requests',function()
 ready();s.statebarSlots={{row='CTRL',slot=1,kind='state'},{row='ALT',slot=2,kind='utility'}}
 assert(api.request(1) and s.statebarSelected==1);assert(api.request(2) and s.statebarSelected==1);api.execute('CTRL',2);assert(s.statebarSelected==1)
 s.allowAllClicks=false;s.statebarSelected=0;assert(not api.request(1) and s.statebarSelected==0)
end)
test('command allowlist rejects Lua chaining and chat',function()
 for _,c in ipairs({'/equipset 1','/lac set PDT','/item "Food" <me>','/mount "Chocobo"'}) do assert(api.valid(c),c) end
 for _,c in ipairs({'/lua exec print(1)','/lac set PDT; /quit','/equipset 0','/equipset 101','/tell Someone hi','/item "Food" <me>\n/quit'}) do assert(not api.valid(c),c) end
 ready();s.statebarSlots={{row='CTRL',slot=1,kind='state',source='command',command='/lac set PDT',label='PDT'}};assert(api.request(1));assert(requested[#requested]=='/lac set PDT')
 api.save();s.statebarSlots={};api.load();assert(s.statebarSlots[1].command=='/lac set PDT' and s.statebarSlots[1].source=='command' and s.statebarSlots[1].label=='PDT')
end)
test('section reset only affects selected preferences',function() s.theme=4;s.mappingMode='numbers';api.reset('StateBar');assert(s.theme==4 and s.mappingMode=='numbers' and not s.statebarEnabled);api.reset('Controls');assert(s.theme==4 and s.mappingMode=='split' and not s.keybinds) end)
test('all three layouts and N row switch',function() s.navKeysEnabled=false;s.mappingMode='split';local r,k=api.mapped(59);assert(r=='CTRL' and k==1);r,k=api.mapped(2);assert(r=='ALT' and k==1);s.navRow='ALT';s.mappingMode='numbers';r,k=api.mapped(2);assert(r=='ALT' and k==1);s.mappingMode='functions';r,k=api.mapped(68);assert(r=='ALT' and k==10);s.rowSwitchKey='N';api.save();s.rowSwitchKey='END';api.load();assert(s.rowSwitchKey=='N') end)
test('StateBar collisions and permission gates',function() ready();s.keybinds=true;s.acknowledgeKeys=true;s.statebarEnabled=true;s.statebarHotkeysEnabled=true;s.statebarHotkeys={59};s.mappingMode='split';assert(not api.hotkey(59));s.statebarHotkeys={87};assert(api.hotkey(87)==1);s.navKeysEnabled=true;s.rowSwitchKey='F11';assert(not api.hotkey(87));s.navKeysEnabled=false;s.acknowledgeKeys=false;assert(not api.hotkey(87)) end)
test('single hotkey execution and key release after disable',function() ready();s.keybinds=true;s.acknowledgeKeys=true;s.statebarEnabled=true;s.statebarHotkeysEnabled=true;s.statebarHotkeys={87};s.held={};s.suppressed={};local n=#requested;local e={key=87,down=true};events.decker_statebar_key_press(e);events.decker_statebar_key_press(e);assert(#requested==n+1);s.keybinds=false;s.statebarHotkeysEnabled=false;e={key=87,down=false};events.decker_exclusive_key_press(e);assert(e.blocked and not s.suppressed[87]) end)
test('Settings sections render with balanced style stacks',function()
 ready();s.showTests=true;s.visible=true;s.statebarEnabled=true;s.statebarSelected=1;s.statebarSlots={{row='CTRL',slot=1,kind='state'}};s.lastProfileCheck=os.clock();s.autoRefresh=false;s.pendingRefreshFrames=0
 for _,tab in ipairs({'Controls','Appearance','StateBar','General','Profiles','Updates'}) do s.settingsTab=tab;events.decker_draw();assert(styles==0 and vars==0,tab) end
end)
test('updater manifest validation and channel version ordering',function()
 local hash=string.rep('a',64);local commit=string.rep('b',40)
 local valid='protocol=1\nversion=1.49.7-dev\ncommit='..commit..'\nsha256='..hash..'\n'
 assert(api.manifest(valid).version=='1.49.7-dev')
 assert(not api.manifest(valid..'version=9.0.0\n'))
 assert(not api.manifest(valid:gsub('protocol=1','protocol=2')))
 assert(not api.manifest(valid:gsub(commit,'../../../other')))
 assert(api.newer('1.49.7-dev','1.49.6-dev') and not api.newer('1.49.5-dev','1.49.6-dev'))
 assert(api.newer('1.49.6','1.49.6-dev') and not api.newer('1.49.6-dev','1.49.6'))
end)
test('updater promotion backs up and rollback restores exact source',function()
 local f=assert(io.open(path,'rb'));local old=f:read('*a');f:close()
 local candidate=tmp..'/candidate.lua'; f=assert(io.open(candidate,'wb'));f:write((source:gsub("addon.version = '[^']+'","addon.version = '1.50.1-dev'")));f:close()
 local ok,version=api.promote(candidate);assert(ok and version=='1.50.1-dev',tostring(ok)..' '..tostring(version))
 f=assert(io.open(tmp..'/decker.lua.bak','rb'));assert(f:read('*a')==old);f:close()
 api.rollback();assert(api.updater.installed);assert(requested[#requested]=='/addon reload decker')
 f=assert(io.open(path,'rb'));assert(f:read('*a')==old);f:close()
end)
test('updater rejects invalid Lua without replacing live source',function()
 local candidate=tmp..'/invalid.lua';local f=assert(io.open(candidate,'wb'));f:write("addon.version = '1.49.8-dev'\n"..string.rep('-- padding\n',100)..'function broken(');f:close()
 local before=assert(io.open(path,'rb'));local old=before:read('*a');before:close()
 local ok,reason=api.promote(candidate);assert(not ok and reason:find('syntax rejected'))
 f=assert(io.open(path,'rb'));assert(f:read('*a')==old);f:close()
end)
test('updater process polling handles pending, timeout and failed download',function()
 local originalNew=ffi.new;ffi.new=function() return {[0]=259} end
 local exitCode=259;local closed=0;local terminated=0
 api.setKernel({GetExitCodeProcess=function(_,p) p[0]=exitCode;return 1 end,CloseHandle=function() closed=closed+1 end,TerminateProcess=function() terminated=terminated+1 end})
 api.updater.job={handle=1,mode='Check',started=os.time(),pollAt=0};api.poll();assert(api.updater.job and closed==0)
 api.updater.job.started=os.time()-46;api.updater.job.pollAt=0;api.poll();assert(not api.updater.job and terminated==1 and api.updater.status:find('timed out'))
 exitCode=1;api.updater.job={handle=1,mode='Download',started=os.time(),pollAt=0};api.poll();assert(not api.updater.job and api.updater.status:find('failed'))
 ffi.new=originalNew;api.setKernel(nil)
end)
test('updater handles unsupported host explicitly',function()
 api.updater.installed=false;api.start('Check');assert(not api.updater.job and api.updater.status:find('requires Windows'))
end)

test('glass preferences round trip and reset independently',function()
 s.outerOpacity=0;s.panelOpacity=.3;s.buttonOpacity=.7;s.statebarOpacity=0;s.macroFont='Times New Roman Bold';s.macroFontSize=23;api.save()
 s.outerOpacity=1;s.panelOpacity=1;s.buttonOpacity=1;s.macroFont='Default';s.macroFontSize=10;api.load()
 assert(s.outerOpacity==0 and s.panelOpacity==.3 and s.buttonOpacity==.7 and s.statebarOpacity==0 and s.macroFontSize==23 and s.macroFont=='Times New Roman Bold')
 character='GlassNew';api.refresh();assert(s.outerOpacity==.05 and s.panelOpacity==.15 and s.buttonOpacity==.85 and s.macroFont=='Arial Bold' and s.macroFontSize==18)
 character='Salts';api.refresh();assert(s.outerOpacity==0 and s.macroFontSize==23)
 api.reset('Appearance');assert(s.outerOpacity==.05 and s.panelOpacity==.15 and s.buttonOpacity==.85 and s.macroFontSize==18 and s.statebarOpacity==0)
end)
test('navigation selection cannot record execution; Enter does',function()
 ready();s.mappingMode='split';s.directKeys={};s.navRow='CTRL';s.navSlot=1;s.lastExecuted=nil;s.flashUntil=0
 api.nav(205);assert(s.navSlot==2 and s.lastExecuted==nil)
 api.nav(28);assert(s.lastExecuted.slot==2 and s.lastExecuted.row=='CTRL')
 api.nav(205);assert(s.navSlot==3 and s.lastExecuted.slot==2)
end)
local originalButton=ui.Button;local paints={};local cursorX,cursorY=0,0;local fontDepth=0;local fills={};local outlines=0;local texts=0
local function record(kind,...) paints[#paints+1]={kind,...} end
local dl={AddText=function(_,font,size,pos,col,text) texts=texts+1;record('text',pos[1],pos[2],size,col,text) end,
 AddRect=function(_,a,b,col) outlines=outlines+1;record('outline',a[1],a[2],b[1]-a[1],b[2]-a[2],col) end,
 AddRectFilled=function() end}
ui.GetWindowDrawList=function() return dl end;ui.GetCursorScreenPos=function() return {cursorX,cursorY} end
ui.GetFont=function() return 'default' end;ui.GetTextLineHeight=function() return 20 end
ui.PushFont=function() fontDepth=fontDepth+1 end;ui.PopFont=function() fontDepth=fontDepth-1 end
ui.CalcTextSize=function(t) return #t*10,20 end;ui.GetColorU32=function(c) return c end
ImGuiCol_WindowBg=5;ImGuiCol_Border=6;ImGuiStyleVar_WindowBorderSize=2;ImGuiStyleVar_FrameBorderSize=3
local rawPush=ui.PushStyleColor;ui.PushStyleColor=function(id,c) rawPush(id,c);if id==ImGuiCol_Button then fills[#fills+1]=c end end
ui.Button=function(label,size)
 if label:find('##decker_') then local c=fills[#fills];record('fill',cursorX,cursorY,size[1],size[2],c);cursorX=cursorX+size[1]+4 end
 return false
end
local previewPaints
 test('custom draw: 20 buttons, key corners and independent execution/selection',function()
 ready();s.macroFontSize=18;s.scale=1;s.buttonOpacity=.85;s.theme=1;s.mappingMode='split';s.directKeys={};for i=1,10 do s.directKeys[i]=58+i;s.directKeys[10+i]=i==10 and 11 or i+1 end
 s.names={'Provoke','Flash','Sentinel','Rampart','Cure IV','Cover','Bash','Invincible','Chivalry','Shield','PDT','MDT','Idle','Auto','Food','Protect','Shell','Reprisal','Cure III','Cancel'}
 s.lastExecuted={row='CTRL',slot=2,name='Flash',set=s.trackedSet};s.navRow='CTRL';s.navSlot=2;s.flashUntil=0;s.trackedSource='verified';api.glass.custom=true
 cursorX=20;cursorY=50;api.drawrow('CTRL',0);cursorX=20;cursorY=98;api.drawrow('ALT',10)
 assert(texts==60 and outlines==1 and #fills==20 and fills[2][1]>.2 and fills[1][1]<.1 and fontDepth==0 and styles==0 and vars==0)
 assert(api.glass.custom,api.glass.diagnostic)
 local key=paints[4];assert(key[1]=='text' and key[6]=='F1' and key[2]>90 and key[3]>75)
 previewPaints=paints
end)
test('mouse and direct keyboard dispatch update execution only once',function()
 ready();s.navKeysEnabled=false;s.keybinds=true;s.acknowledgeKeys=true;s.mappingMode='split';s.held={};s.suppressed={};s.statebarSelected=1
 local old=ui.Button;local n=#requested
 ui.Button=function(label,size) old(label,size);return label=='##decker_ALT3' end
 api.drawrow('ALT',10);ui.Button=old
 assert(#requested==n+1 and s.lastExecuted.row=='ALT' and s.lastExecuted.slot==3 and s.statebarSelected==1)
 local e={key=59,down=true};events.decker_exclusive_key_press(e);events.decker_exclusive_key_press({key=59,down=true})
 assert(#requested==n+2 and s.lastExecuted.row=='CTRL' and s.lastExecuted.slot==1)
 events.decker_exclusive_key_press({key=59,down=false});assert(not s.suppressed[59])
end)
test('long labels stay within button width and preserve full source',function()
 paints={};s.names[1]=string.rep('Long',30);cursorX=0;cursorY=0;api.drawrow('CTRL',0)
 for _,p in ipairs(paints) do if p[1]=='text' then assert(p[2]>=0 and #p[6]*p[4]*.5<=106) end end
 assert(#s.names[1]==120 and fontDepth==0)
end)
test('vector ABI variants and unsupported drawing fall back',function()
 local x,y=api.pair(12,24);assert(x==12 and y==24);x,y=api.pair({x=4,y=8});assert(x==4 and y==8)
 local add=dl.AddText;dl.AddText=function() error('unsupported overload') end;api.drawrow('ALT',10);assert(not api.glass.custom and fontDepth==0 and styles==0 and vars==0);dl.AddText=add
 api.drawrow('CTRL',0);assert(fontDepth==0 and styles==0 and vars==0);api.glass.custom=true
end)
test('collapsed windows and auto-hide recoverable tab balance style stacks',function()
 ready();s.visible=true;s.showTests=false;s.autoRefresh=false;s.lastProfileCheck=os.clock();s.navKeysEnabled=false;s.statebarEnabled=true;s.statebarSlots={{row='CTRL',slot=1}};s.autoHide=false
 local begin=ui.Begin;ui.Begin=function() return false end;events.decker_draw();assert(styles==0 and vars==0);ui.Begin=begin
 local labels={};ui.Begin=function(label) labels[#labels+1]=label;return true end
 s.autoHide=true;s.autoHideDelay=2;s.hudHasInteracted=true;s.hudForceReveal=false;s.hudLastActivity=os.clock()-10;s.hudReadySince=os.clock()-20;s.hudWasActive=false
 events.decker_draw();local collapsed=false;for _,l in ipairs(labels) do if l:find('Collapsed') or l:find('DeckerTab') then collapsed=true end end
 assert(styles==0 and vars==0);assert(collapsed,table.concat(labels,' | '))
 ui.Begin=begin;s.autoHide=false
end)
if os.getenv('DECKER_PREVIEW') then
 local f=assert(io.open(os.getenv('DECKER_PREVIEW'),'w'))
 local function esc(t) return tostring(t):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;') end
 f:write('<svg xmlns="http://www.w3.org/2000/svg" width="1140" height="240"><rect width="1140" height="240" fill="#40544f"/><text x="20" y="24" fill="white" font-family="sans-serif" font-size="14">DECKER | Book 1 (#1) — OFFLINE SIMULATION, NOT A GAME SCREENSHOT</text>')
 for _,p in ipairs(previewPaints) do
  local c=p[1]=='text' and p[5] or p[6];local colour
  -- integer conversion is explicit for Lua 5.4 as well as LuaJIT.
  colour=('rgb(%s,%s,%s)'):format(math.floor(c[1]*255),math.floor(c[2]*255),math.floor(c[3]*255))
  if p[1]=='text' then f:write(('<text x="%s" y="%s" font-family="Arial, sans-serif" font-weight="bold" font-size="%s" fill="%s">%s</text>'):format(p[2],p[3]+p[4]*.8,p[4],colour,esc(p[6])))
  else f:write(('<rect x="%s" y="%s" width="%s" height="%s" rx="2" %s="%s" fill-opacity="%s" %s/>'):format(p[2],p[3],p[4],p[5],p[1]=='outline' and 'stroke' or 'fill',colour,c[4],p[1]=='outline' and 'fill="none"' or '')) end
 end
 f:write('<text x="20" y="180" fill="white" font-family="sans-serif" font-size="12">By Mutant X | Flash: execution colour + gold selection outline</text><text x="20" y="211" fill="white" font-family="sans-serif" font-size="12">Draw commands from Lua renderer; simulated geometry, font metrics and background. Live screenshot pending.</text></svg>');f:close()
end
ui.Button=originalButton

os.execute('rm -r '..tmp)
print(passed..' regression groups passed (mocked host; not in-game validation)')
