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
local expose='\nreturn {state=state,glass=glass,connect=connect_macros,book=select_native_book,parseBooks=parse_book_titles,importBooks=import_book_titles,bookLabel=book_label,drawrow=draw_row,pair=pair,nav=nav_command,refresh=refresh_profile,save=save_display,load=load_display,request=request_statebar,valid=valid_command,reset=restore_section,mapped=mapped_key,hotkey=statebar_hotkey_slot,execute=execute_slot,updater=updater,manifest=update_manifest,newer=update_newer,promote=update_promote,rollback=update_rollback,start=update_start,poll=update_poll,updateScript=update_script,setKernel=function(k) update_kernel=k end}'
-- Profile IO goes into an isolated directory, preserving real user settings.
local tmp=os.tmpname();os.remove(tmp);assert(os.execute('mkdir -p '..tmp)==0)
local path=tmp..'/decker.lua';f=assert(io.open(path,'w'));f:write(source,expose);f:close()
local api=assert(loadfile(path))();local s=api.state
local passed=0
local function test(name,fn) fn();passed=passed+1;print('PASS '..name) end
local function ready() s.phase=4;s.allowAllClicks=true;s.profileReady=true;s.names={};for i=1,20 do s.names[i]='Macro'..i end;s.addresses.controller=65536;s.addresses.run=65536 end
api.refresh()
test('first install: safe defaults and Quick Setup',function() assert(s.profileId=='1_Salts' and not s.keybinds and not s.autoHide and s.settingsTab=='Controls' and s.mappingMode=='numbers') end)
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
test('section reset only affects selected preferences',function() s.theme=4;s.mappingMode='numbers';api.reset('StateBar');assert(s.theme==4 and s.mappingMode=='numbers' and not s.statebarEnabled);api.reset('Controls');assert(s.theme==4 and s.mappingMode=='numbers' and not s.keybinds) end)
test('all three layouts and N row switch',function() s.navKeysEnabled=false;s.mappingMode='split';local r,k=api.mapped(59);assert(r=='CTRL' and k==1);r,k=api.mapped(2);assert(r=='ALT' and k==1);s.navRow='ALT';s.mappingMode='numbers';r,k=api.mapped(2);assert(r=='ALT' and k==1);s.mappingMode='functions';r,k=api.mapped(68);assert(r=='ALT' and k==10);s.rowSwitchKey='N';api.save();s.rowSwitchKey='END';api.load();assert(s.rowSwitchKey=='N') end)
test('StateBar collisions and permission gates',function() ready();s.keybinds=true;s.acknowledgeKeys=true;s.statebarEnabled=true;s.statebarHotkeysEnabled=true;s.statebarHotkeys={59};s.mappingMode='split';assert(not api.hotkey(59));s.statebarHotkeys={87};assert(api.hotkey(87)==1);s.navKeysEnabled=true;s.rowSwitchKey='F11';assert(not api.hotkey(87));s.navKeysEnabled=false;s.acknowledgeKeys=false;s.keybinds=false;assert(api.hotkey(87)==1);s.allowAllClicks=false;assert(not api.hotkey(87)) end)
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
 s.autoHide=true;s.autoHideMode='collapse';s.autoHideDelay=2;s.hudHasInteracted=true;s.hudForceReveal=false;s.hudLastActivity=os.clock()-10;s.hudReadySince=os.clock()-20;s.hudWasActive=false
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

test('hover tooltip receives the macro name as literal text',function()
 ready();s.names[1]='Help';s.names[2]='100%s';s.names[3]=''
 local tips={};local oldHovered=ui.IsItemHovered;local oldTooltip=ui.SetTooltip
 ui.IsItemHovered=function() return true end
 ui.SetTooltip=function(...) assert(select('#',...)==1);tips[#tips+1]=(...) end
 api.drawrow('CTRL',0)
 assert(tips[1]=='Help' and tips[2]=='100%s' and #tips==9)
 ui.IsItemHovered=oldHovered;ui.SetTooltip=oldTooltip
end)

test('configured width and compact labels reach both rendering paths',function()
 ready();s.mappingMode='split';s.scale=1;s.hudWidth=116;s.compactKeys=false
 local old=ui.Button;local width,label;ui.Button=function(l,size) width=width or size[1];label=label or l;return false end
 api.glass.custom=false;api.drawrow('CTRL',0);assert(width==116 and label:find('CTRL 1 | F1',1,true))
 api.glass.custom=true;paints={};api.drawrow('CTRL',0);local found=false
 for _,p in ipairs(paints) do if p[1]=='text' and p[6]=='CTRL 1 | F1' then found=true end end;assert(found)
 s.compactKeys=true;paints={};api.drawrow('CTRL',0);found=false
 for _,p in ipairs(paints) do if p[1]=='text' and p[6]=='F1' then found=true end end;assert(found)
 ui.Button=old;s.hudWidth=92
end)
test('locked windows anchor positions and size preferences trigger resizing',function()
 ready();s.visible=true;s.autoHide=false;s.statebarEnabled=true;s.statebarSlots={{row='CTRL',slot=1}};s.showTests=false;s.positionLocked=false;s.statebarLocked=false
 local begin=ui.Begin;local resize=ui.SetNextWindowSize;local pos={100,200};local nextPos;local seen={};local sizeCount=0
 ui.GetWindowPos=function() return {x=pos[1],y=pos[2]} end
 ui.SetNextWindowPos=function(p) nextPos={p[1],p[2]} end
 ui.SetNextWindowSize=function(_,cond) if cond==1 then sizeCount=sizeCount+1 end end
 ui.Begin=function(name,_,flags) if nextPos then seen[name]={nextPos,flags};nextPos=nil end;return true end
 events.decker_draw();s.positionLocked=true;s.statebarLocked=true;pos={900,900};events.decker_draw()
 assert(seen['###DeckerStateBar'][1][1]==100 and seen['###DeckerStateBar'][2]==5)
 local found=false;for name,v in pairs(seen) do if name:find('DeckerMain') then assert(v[1][2]==200 and v[2]==5);found=true end end;assert(found)
 s.hudWidth=116;local n=sizeCount;events.decker_draw();assert(sizeCount>n)
 seen={};s.positionLocked=false;s.statebarLocked=false;events.decker_draw();assert(next(seen)==nil)
 ui.Begin=begin;ui.SetNextWindowSize=resize;ui.GetWindowPos=nil;ui.SetNextWindowPos=nil;s.hudWidth=92
end)
test('thin Settings scrollbar balances style scope',function()
 ready();s.showTests=true;s.settingsTab='Appearance';s.lastProfileCheck=os.clock();ImGuiStyleVar_ScrollbarSize=91
 local push=ui.PushStyleVar;local begin=ui.Begin;local count=0
 ui.PushStyleVar=function(id,value) if id==91 then assert(value==7);count=count+1 end;push(id,value) end
 events.decker_draw();ui.Begin=function() return false end;events.decker_draw();assert(count==2 and vars==0)
 ui.Begin=begin;ui.PushStyleVar=push;ImGuiStyleVar_ScrollbarSize=nil
end)
test('StateBar physical hotkey edges execute once and suppress native input',function()
 ready();s.keybinds=true;s.acknowledgeKeys=true;s.statebarEnabled=true;s.statebarHotkeysEnabled=true;s.navKeysEnabled=false;s.mappingMode='split';s.held={};s.suppressed={}
 s.statebarSlots={{row='CTRL',slot=1,kind='state',source='command',command='/equipset 1'}};s.statebarHotkeys={79}
 local n=#requested;local raw={};for i=0,255 do raw[i]=0 end;raw[79]=128
 events.decker_exclusive_key_state({data_raw=raw,size=256});assert(#requested==n+1 and raw[79]==0 and s.statebarSelected==1)
 raw[79]=128;events.decker_exclusive_key_state({data_raw=raw,size=256});events.decker_statebar_key_press({key=79,down=true});assert(#requested==n+1)
 raw[79]=0;events.decker_exclusive_key_state({data_raw=raw,size=256});assert(not s.held[79] and not s.suppressed[79])
 local e={key=79,down=true};events.decker_statebar_key_press(e);assert(e.blocked and #requested==n+2)
 raw[79]=128;events.decker_exclusive_key_state({data_raw=raw,size=256});assert(#requested==n+2 and raw[79]==0)
 events.decker_exclusive_key_press({key=79,down=false});s.held[29]=true;raw[79]=128
 events.decker_exclusive_key_state({data_raw=raw,size=256});assert(raw[79]==128 and #requested==n+2);s.held={};s.suppressed={}
 s.directKeys[1]=210;api.save();s.directKeys[1]=59;s.statebarHotkeys={};api.load();assert(s.directKeys[1]==210 and s.statebarHotkeys[1]==79)
end)

test('glass overlays pass explicit open state and no-title flags with hidden IDs',function()
 ready();s.visible=true;s.showTests=false;s.autoHide=false;s.statebarEnabled=true;s.statebarSlots={{row='CTRL',slot=1}};s.positionLocked=false;s.statebarLocked=false
 local begin=ui.Begin;local seen={}
 ui.Begin=function(name,opened,flags)
  if name:find('###Decker') then
   assert(name:sub(1,3)=='###' and type(opened)=='table' and opened[1]==true and flags%2==1)
   seen[name]=true
  end
  return true
 end
 events.decker_draw();assert(seen['###DeckerMain'] and seen['###DeckerStateBar'])
 s.autoHide=true;s.autoHideMode='collapse';s.autoHideDelay=2;s.hudLastActivity=os.clock()-20;s.hudReadySince=os.clock()-20;s.hudForceReveal=false;s.navKeysEnabled=false
 events.decker_draw();assert(seen['###DeckerCollapsed']);ui.Begin=begin;s.autoHide=false
end)

test('full auto-hide draws no recovery window and Settings opens while HUD is hidden',function()
 ready();s.visible=true;s.showTests=false;s.statebarEnabled=false;s.navKeysEnabled=false;s.autoHide=true;s.autoHideMode='hide';s.autoHideDelay=2
 s.hudLastActivity=os.clock()-20;s.hudReadySince=os.clock()-20;s.hudForceReveal=false;s.lastProfileCheck=os.clock()
 local begin=ui.Begin;local seen={};ui.Begin=function(name) seen[#seen+1]=name;return true end
 events.decker_draw();assert(#seen==0 and s.autoHideMode=='hide')
 local function command(c) local e={command={args=function() return {'/decker',c} end}};events.decker_cmd(e);assert(e.blocked) end
 command('hide');command('settings');assert(not s.visible and s.showTests);events.decker_draw();assert(#seen==1 and seen[1]:find('Settings'))
 command('settings');assert(s.showTests);command('closesettings');assert(not s.showTests)
 command('show');assert(s.visible);seen={};events.decker_draw();assert(#seen==1 and seen[1]=='###DeckerMain')
 command('hide');assert(not s.visible and not s.showTests);ui.Begin=begin;s.autoHide=false;s.visible=true
end)
test('optional recovery has one Decker button opening Settings',function()
 ready();s.visible=true;s.showTests=false;s.statebarEnabled=false;s.navKeysEnabled=false;s.autoHide=true;s.autoHideMode='collapse';s.autoHideDelay=2
 s.hudLastActivity=os.clock()-20;s.hudReadySince=os.clock()-20;s.hudForceReveal=false
 local button=ui.Button;local begin=ui.Begin;local recovery=false;local count=0
 ui.Begin=function(name) recovery=name=='###DeckerCollapsed';return true end
 ui.Button=function(label) if recovery then count=count+1;assert(label=='Decker##recovery');return true end;return false end
 events.decker_draw();assert(count==1 and s.showTests)
 ui.Button=button;ui.Begin=begin;s.showTests=false;s.autoHide=false
end)
test('scrollbar visibility persists and applies to HUD StateBar and Settings',function()
 ready();s.showScrollbars=false;s.visible=true;s.showTests=true;s.statebarEnabled=true;s.statebarSlots={{row='CTRL',slot=1}};s.autoHide=false
 local begin=ui.Begin;local count=0
 ui.Begin=function(name,opened,flags) assert(type(opened)=='table');assert(math.floor(flags/8)%2==1);count=count+1;return true end
 events.decker_draw();assert(count==3);api.save();s.showScrollbars=true;api.load();assert(not s.showScrollbars)
 ui.Begin=begin;s.showScrollbars=true;s.showTests=false
end)
test('StateBar F11 captures both input streams with main shortcuts disabled',function()
 ready();s.keybinds=false;s.acknowledgeKeys=false;s.statebarEnabled=true;s.statebarHotkeysEnabled=true;s.navKeysEnabled=false;s.held={};s.suppressed={}
 s.statebarSlots={{row='ALT',slot=2,kind='utility'}};s.statebarHotkeys={87};local n=#requested
 local e={key=87,down=true};events.decker_statebar_key_press(e);assert(e.blocked and #requested==n+1 and s.lastExecuted.row=='ALT')
 local raw={};for i=0,255 do raw[i]=0 end;raw[87]=128;events.decker_exclusive_key_state({data_raw=raw,size=256});assert(raw[87]==0 and #requested==n+1)
 events.decker_exclusive_key_press({key=87,down=false});s.statebarHotkeysEnabled=false;raw[87]=128
 events.decker_exclusive_key_state({data_raw=raw,size=256});assert(raw[87]==128 and #requested==n+1)
end)
test('StateBar scales text within small boxes and provides full hover explanation',function()
 ready();s.visible=false;s.showTests=false;s.statebarEnabled=true;s.statebarSlots={{row='CTRL',slot=1,kind='utility',label='Long StateBar Label Here'}};s.statebarHotkeys={209};api.glass.custom=true
 local hover=ui.IsItemHovered;local tooltip=ui.SetTooltip;local tip
 ui.IsItemHovered=function() return true end;ui.SetTooltip=function(text) tip=text end
 for _,scale in ipairs({.7,1,1.5}) do
  s.statebarScale=scale;paints={};cursorX=0;cursorY=0;events.decker_draw();local found=false
  for _,p in ipairs(paints) do if p[1]=='text' then
   assert(p[2]>=0 and p[2]+#p[6]*p[4]*.5<=math.floor(100*scale)+1)
   assert(p[3]>=0 and p[3]+p[4]<=math.floor(40*scale)+1)
   if p[6]=='Page Down' then found=true end
  end end
  assert(found and tip:find('Long StateBar Label Here',1,true) and tip:find('Utility: one-off',1,true))
 end
 ui.IsItemHovered=hover;ui.SetTooltip=tooltip;s.visible=true;s.statebarScale=1
end)
test('shared number and F-key layouts preserve row-switch routing',function()
 ready();s.navKeysEnabled=false;s.navRow='CTRL';s.mappingMode='numbers'
 local row,slot=api.mapped(2);assert(row=='CTRL' and slot==1);api.nav(57);row,slot=api.mapped(2);assert(row=='ALT' and slot==1)
 s.mappingMode='functions';row,slot=api.mapped(68);assert(row=='ALT' and slot==10);api.nav(57);row,slot=api.mapped(68);assert(row=='CTRL' and slot==10)
end)

test('Settings native X closes on both expanded and collapsed Begin paths',function()
 ready();s.visible=true;s.statebarEnabled=false;s.autoHide=false
 local begin=ui.Begin
 for _,expanded in ipairs({true,false}) do
  s.showTests=true
  ui.Begin=function(name,opened) if name:find('Settings') then opened[1]=false;return expanded end;return true end
  events.decker_draw();assert(not s.showTests and styles==0 and vars==0)
 end
 ui.Begin=begin
end)
test('single assigned-key switch gates layout editing and sets both legacy permissions',function()
 ready();s.visible=true;s.showTests=true;s.settingsTab='Controls';s.statebarEnabled=false;s.keybinds=false;s.acknowledgeKeys=false;s.keyAssignmentPage=false;s.navKeysEnabled=false
 local button=ui.Button;local check=ui.Checkbox;local layouts=0;local permissionCount=0
 ui.Button=function(label) if label:find('Both rows:',1,true) then layouts=layouts+1 end;return false end
 ui.Checkbox=function(label) if label=='Use my assigned keys' then permissionCount=permissionCount+1 end;return false end
 events.decker_draw();assert(layouts==0 and permissionCount==1)
 ui.Checkbox=function(label,v) if label=='Use my assigned keys' then v[1]=true;return true end;return false end
 events.decker_draw();assert(s.keybinds and s.acknowledgeKeys and s.savedKeybinds and s.savedAck and layouts>0)
 s.allowAllClicks=false;layouts=0;permissionCount=0;ui.Checkbox=function(label) if label=='Use my assigned keys' then permissionCount=permissionCount+1 end;return false end
 events.decker_draw();assert(layouts==0 and permissionCount==0)
 ui.Button=button;ui.Checkbox=check
end)
test('custom slot edit overrides shared layout and persists explicit custom status',function()
 ready();s.visible=true;s.showTests=true;s.settingsTab='Controls';s.keybinds=true;s.acknowledgeKeys=true;s.keyAssignmentPage=false;s.mappingMode='numbers';s.directKeys={};for i=1,10 do s.directKeys[i]=58+i;s.directKeys[10+i]=i==10 and 11 or i+1 end;s.statebarHotkeys={};s.navKeysEnabled=false
 local button=ui.Button;local selectable=ui.Selectable;local texts={};local text=ui.Text
 ui.Text=function(t) texts[#texts+1]=t end
 ui.Button=function(label) return label=='Customise keys for both rows' end
 ui.Selectable=function(label) return label=='Q##directchoice1_16' end
 events.decker_draw();assert(s.keyAssignmentPage and s.mappingMode=='custom' and s.directKeys[1]==16)
 local row,slot=api.mapped(16);assert(row=='CTRL' and slot==1);s.navRow='ALT';row,slot=api.mapped(16);assert(row=='CTRL' and slot==1)
 ui.Button=function() return false end;ui.Selectable=function() return false end;events.decker_draw()
 local found=false;for _,t in ipairs(texts) do if t=='Key layout: Custom keys in use' then found=true end end;assert(found)
 api.save();s.mappingMode='numbers';s.directKeys[1]=59;api.load();assert(s.mappingMode=='custom' and s.directKeys[1]==16)
 -- Choosing a preset deliberately resumes shared keys; reset restores the split preset.
 s.keyAssignmentPage=false;ui.Button=function(label) return label=='Both rows: 1-0' end;events.decker_draw();assert(s.mappingMode=='numbers')
 s.keyAssignmentPage=true;ui.Button=function(label) return label=='Reset to F1-F10 / 1-0 layout' end;events.decker_draw();assert(s.mappingMode=='split' and s.directKeys[1]==59)
 ui.Button=button;ui.Selectable=selectable;ui.Text=text;s.keyAssignmentPage=false
end)
test('legacy split assignments migrate to custom while unedited split remains a preset',function()
 ready();s.mappingMode='split';s.directKeys[1]=16;api.save();s.mappingMode='numbers';api.load();assert(s.mappingMode=='custom' and s.directKeys[1]==16)
 s.mappingMode='split';for i=1,10 do s.directKeys[i]=58+i;s.directKeys[10+i]=i==10 and 11 or i+1 end;api.save();s.mappingMode='numbers';api.load();assert(s.mappingMode=='split')
end)

test('StateBar Settings button follows main Settings visibility and opens its tab',function()
 ready();s.visible=false;s.showTests=false;s.statebarEnabled=true;s.statebarSlots={{row='CTRL',slot=1}};s.autoHide=false
 local button=ui.Button;local resize=ui.SetNextWindowSize;local count=0;local heights={}
 ui.SetNextWindowSize=function(size) heights[#heights+1]=size[2] end
 ui.Button=function(label) assert(not label:find('Configure##statebarconfig',1,true));if label=='Settings##statebarconfig' then count=count+1;return true end;return false end
 events.decker_draw();assert(count==0);local compactHeight=heights[1]
 heights={};s.showTests=true;s.settingsTab='Controls';events.decker_draw();assert(count==1 and s.settingsTab=='StateBar' and heights[1]>compactHeight)
 s.showTests=false;events.decker_draw();assert(count==1)
 ui.Button=button;ui.SetNextWindowSize=resize;s.visible=true
end)
test('HUD identity and key status share one spaced line in every layout',function()
 ready();s.visible=true;s.showTests=false;s.statebarEnabled=false;s.autoHide=false;s.scale=1;s.navKeysEnabled=true;s.navToggleActive=true;s.navRow='ALT';s.rowSwitchKey='END'
 local text=ui.Text;local same=ui.SameLine;local calls={}
 ui.Text=function(t) calls[#calls+1]={'text',t} end
 ui.SameLine=function(x,gap) calls[#calls+1]={'same',x,gap} end
 for _,mode in ipairs({'numbers','functions','split','custom'}) do
  s.mappingMode=mode;calls={};events.decker_draw();local found=false
  for i,c in ipairs(calls) do if c[1]=='text' and c[2]:find('DECKER | Book',1,true)==1 then
   assert(calls[i+1][1]=='same' and calls[i+1][2]>0 and calls[i+1][3]==0)
   assert(calls[i+2][1]=='text' and calls[i+2][2]=='LOCKED');assert(calls[i+3][1]=='same' and calls[i+3][2]>calls[i+1][2]);
   assert(calls[i+4][1]=='text' and calls[i+4][2]=='Active row: Lower');found=true
  end end;assert(found)
 end
 ui.Text=text;ui.SameLine=same;s.navKeysEnabled=false;s.navToggleActive=false
end)

test('status is red when locked or held and key column stays fixed across status and book changes',function()
 ready();s.visible=true;s.showTests=false;s.statebarEnabled=false;s.autoHide=false;s.mappingMode='numbers';s.scale=1;s.navKeysEnabled=true
 local text=ui.Text;local same=ui.SameLine;local push=ui.PushStyleColor;local lastX;local colour;local columns={};local statuses={}
 ui.PushStyleColor=function(id,c) if id==ImGuiCol_Text then colour=c end;push(id,c) end
 ui.SameLine=function(x) lastX=x end
 ui.Text=function(t)
  if t=='LOCKED' or t=='HELD' or t=='UNLOCKED' then statuses[#statuses+1]={t,colour[1],colour[2],colour[3]} end
  if t:find('Active row:',1,true)==1 then columns[#columns+1]=lastX end
 end
 s.stickyNavigation=true;s.navToggleActive=false;s.navModifierHeld=false;s.manualBook=1;events.decker_draw()
 s.navToggleActive=true;events.decker_draw()
 s.stickyNavigation=false;s.navToggleActive=false;s.navModifierHeld=true;s.manualBook=20;events.decker_draw()
 s.navModifierHeld=false;s.stickyNavigation=true;events.decker_draw()
 assert(statuses[1][1]=='UNLOCKED' and statuses[1][2]==1 and statuses[1][3]==1 and statuses[1][4]==1)
 assert(statuses[2][1]=='LOCKED' and statuses[2][2]==1 and statuses[2][3]==.25)
 assert(statuses[3][1]=='HELD' and statuses[3][2]==1 and statuses[3][3]==.25)
 assert(statuses[4][1]=='UNLOCKED' and statuses[4][3]==1)
 assert(#columns==4 and columns[1]>0);for _,x in ipairs(columns) do assert(x==columns[1]) end
 assert(styles==0);ui.Text=text;ui.SameLine=same;ui.PushStyleColor=push;s.navKeysEnabled=false;s.stickyNavigation=true;s.manualBook=1
end)
test('plain-language mod behaviour choices retain hold and toggle semantics',function()
 ready();s.visible=true;s.showTests=true;s.settingsTab='Controls';s.keybinds=true;s.acknowledgeKeys=true;s.keyAssignmentPage=false;s.statebarEnabled=false
 local select=ui.Selectable;local combo=ui.BeginCombo;local preview
 ui.BeginCombo=function(label,value) if label=='Macro mod behaviour' then preview=value end;return true end
 s.stickyNavigation=true;ui.Selectable=function(label) return label=='Hold key pressed down' end;events.decker_draw();assert(not s.stickyNavigation and preview=='Press key once (Toggle)')
 ui.Selectable=function(label) return label=='Press key once (Toggle)' end;events.decker_draw();assert(s.stickyNavigation and preview=='Hold key pressed down')
 ui.Selectable=select;ui.BeginCombo=combo
end)

test('Hold HUD follows physical mod press and release without timer or recovery window',function()
 ready();s.visible=true;s.showTests=false;s.statebarEnabled=false;s.navKeysEnabled=true;s.navModifier='RSHIFT';s.stickyNavigation=false;s.navToggleActive=false;s.held={};s.navPhysicalDown=false;s.navModifierHeld=false;s.navPhysicalKeys={};s.navCaptured={};s.hudReadySince=os.clock()
 local begin=ui.Begin;local windows={};ui.Begin=function(name) windows[#windows+1]=name;return true end
 local function physical(down)
  local raw={};for i=0,255 do raw[i]=0 end;raw[54]=down and 128 or 0
  events.decker_custom_set_state({data_raw=raw,size=256})
 end
 for _,auto in ipairs({false,true}) do for _,mode in ipairs({'hide','collapse'}) do
  s.autoHide=auto;s.autoHideMode=mode;s.autoHideDelay=30;s.hudForceReveal=true
  physical(false);windows={};events.decker_draw();assert(#windows==0)
  physical(true);windows={};events.decker_draw();assert(#windows==1 and windows[1]=='###DeckerMain')
  physical(false);windows={};events.decker_draw();assert(#windows==0)
 end end
 s.showTests=true;windows={};events.decker_draw();assert(#windows==1 and windows[1]:find('Settings'))
 ui.Begin=begin;s.showTests=false;s.autoHide=false;s.navKeysEnabled=false;s.stickyNavigation=true
end)
test('Toggle HUD remains after release and uses configured inactivity timing when unlocked',function()
 ready();s.visible=true;s.showTests=false;s.statebarEnabled=false;s.navKeysEnabled=true;s.stickyNavigation=true;s.navToggleActive=true;s.navModifierHeld=false;s.autoHide=true;s.autoHideMode='hide';s.autoHideDelay=5;s.hudReadySince=os.clock()-30;s.hudLastActivity=os.clock()-30;s.hudForceReveal=false;s.hudWasActive=true
 local begin=ui.Begin;local windows={};ui.Begin=function(name) windows[#windows+1]=name;return true end
 events.decker_draw();assert(#windows==1 and windows[1]=='###DeckerMain')
 s.navToggleActive=false;s.hudLastActivity=os.clock()-4;windows={};events.decker_draw();assert(#windows==1)
 s.hudLastActivity=os.clock()-6;windows={};events.decker_draw();assert(#windows==0)
 s.autoHide=false;windows={};events.decker_draw();assert(#windows==1)
 ui.Begin=begin;s.navKeysEnabled=false;s.autoHide=false
end)
test('Display defaults expanded and warns to finish setup before hiding completely',function()
 ready();s.visible=true;s.showTests=true;s.settingsTab='Appearance';s.statebarEnabled=false;s.navKeysEnabled=false;s.autoHide=false
 local header=ui.CollapsingHeader;local wrapped=ui.TextWrapped;local open=false;local warning=false;local semantics=false
 ui.CollapsingHeader=function(label,flags) if label=='Display' then assert(flags==32);open=true end;return true end
 ui.TextWrapped=function(t) if t:find('First-time setup: select Hide completely only after Decker is working',1,true) then warning=true end;if t:find('These inactivity settings apply to Toggle mode',1,true) then semantics=true end end
 events.decker_draw();assert(open and warning and semantics)
 ui.CollapsingHeader=header;ui.TextWrapped=wrapped;s.showTests=false
end)

test('successful connection enables assigned keys by default but preserves saved opt-out',function()
 local find=ashita.memory.find;local cast=ffi.cast;local str=ffi.string
 ashita.memory.find=function() return 65536 end
 ffi.cast=function(kind,value) if kind=='Decker_FsMacroContainer_getName_f' then return function() return 'Macro' end end;return cast(kind,value) end
 ffi.string=function(value) return value end
 s.savedKeybinds=true;s.savedAck=true;api.connect();assert(s.keybinds and s.acknowledgeKeys and #s.names==20)
 s.savedKeybinds=false;api.connect();assert(not s.keybinds and not s.acknowledgeKeys)
 s.savedKeybinds=true;ashita.memory.find=function() return 0 end;api.connect();assert(not s.keybinds and not s.acknowledgeKeys)
 ashita.memory.find=find;ffi.cast=cast;ffi.string=str
end)
test('macro toggle echo colours only locked and respects echo-off',function()
 local oldPrint=print;local chat=package.loaded.chat;local oldColour=chat.color1;local messages={}
 print=function(t) messages[#messages+1]=t end
 chat.color1=function(n,t) assert(n==76 and t=='locked');return '<red>'..t..'</red>' end
 s.navKeysEnabled=true;s.navModifier='RSHIFT';s.stickyNavigation=true;s.navToggleActive=false;s.navPhysicalDown=false;s.navCaptured={};s.navPhysicalKeys={};s.held={};s.echoLock=true
 local function key(down) local raw={};for i=0,255 do raw[i]=0 end;raw[54]=down and 128 or 0;events.decker_custom_set_state({data_raw=raw,size=256}) end
 key(true);key(false);key(true);key(false)
 assert(messages[1]=='Macros <red>locked</red>' and messages[2]=='Macros unlocked')
 s.echoLock=false;key(true);key(false);assert(#messages==2)
 print=oldPrint;chat.color1=oldColour;s.navKeysEnabled=false;s.navToggleActive=false;s.echoLock=true
end)
test('title-file reader preserves blank slots and rejects malformed or unsupported bytes',function()
 local bytes=string.rep('\0',24)
 for i=1,20 do local title=i==1 and 'PALADIN' or i==3 and '' or ('Book'..i);bytes=bytes..title..string.rep('\0',16-#title) end
 local names=assert(api.parseBooks(bytes));assert(names[1]=='PALADIN' and names[3]=='' and names[4]=='Book4' and #names==20)
 assert(not api.parseBooks(bytes:sub(1,343)));assert(not api.parseBooks(bytes..'x'))
 assert(not api.parseBooks(bytes:sub(1,24)..string.rep('x',16)..bytes:sub(41)))
 assert(not api.parseBooks(bytes:sub(1,24)..'\255'..bytes:sub(26)))
end)
test('read-only twenty-book title import persists isolated aliases',function()
 local function fixture(prefix) local b=string.rep('\0',24);for i=1,20 do local t=prefix..i;b=b..t..string.rep('\0',16-#t) end;return b end
 local one,two=fixture('Main'),fixture('Extra');local dir=tmp..'/titles';assert(os.execute('mkdir -p '..dir)==0)
 for name,bytes in pairs({['mcr.ttl']=one,['mcr_2.ttl']=two}) do local out=assert(io.open(dir..'/'..name,'wb'));out:write(bytes);out:close() end
 ready();s.bookPath=dir;assert(api.importBooks());assert(s.bookNames[1]=='Main1' and s.bookNames[20]=='Main20' and s.bookNames[21]==nil)
 local input=assert(io.open(dir..'/mcr.ttl','rb'));assert(input:read('*a')==one);input:close()
 s.bookAliases[1]='My PLD';assert(api.bookLabel(1)=='Book 1 - My PLD');api.save();s.bookNames={};s.bookAliases={};s.bookPath='';api.load();assert(s.bookNames[20]=='Main20' and s.bookAliases[1]=='My PLD' and s.bookPath==dir)
 local broken=assert(io.open(dir..'/mcr.ttl','wb'));broken:write('invalid');broken:close();assert(not api.importBooks() and s.bookNames[20]=='Main20')
 local original=character;character='TitleTestOther';api.refresh();assert(next(s.bookNames)==nil and next(s.bookAliases)==nil and s.bookPath=='');character=original;api.refresh();assert(s.bookAliases[1]=='My PLD')
end)
test('native book requests use zero-based indices through book twenty with connection gates',function()
 ready();s.allowSwitch=true;s.macroObject=65536;s.addresses.macro_object=65536;s.addresses.set_book=65536
 local cast=ffi.cast;local indices={};ffi.cast=function(kind,value) if kind=='Decker_FsMacroContainer_setBook_f' then return function(obj,index) assert(obj==65536);indices[#indices+1]=index end end;return cast(kind,value) end
 api.book(1);api.book(11);api.book(20);assert(indices[1]==0 and indices[2]==10 and indices[3]==19 and s.manualBook==20 and s.pendingRefreshFrames==3)
 api.book(0);api.book(21);api.book(1.5);assert(#indices==3);s.phase=0;api.book(2);assert(#indices==3)
 ffi.cast=cast
end)

test('HUD heading uses the selected book alias or imported game title',function()
 ready();s.visible=true;s.showTests=false;s.statebarEnabled=false;s.navKeysEnabled=false;s.autoHide=false;s.autoRefresh=false;s.pendingRefreshFrames=0
 local text=ui.Text;local heading
 ui.Text=function(t) if t:find('DECKER | Book',1,true)==1 then heading=t end end
 s.manualBook=1;s.bookAliases[1]='WHM';s.bookAliases[2]='Bard';events.decker_draw();assert(heading:find('Book 1 - WHM',1,true))
 s.manualBook=2;events.decker_draw();assert(heading:find('Book 2 - Bard',1,true))
 s.bookAliases[2]=nil;s.bookNames[2]='IngameBRD';events.decker_draw();assert(heading:find('Book 2 - IngameBRD',1,true))
 ui.Text=text
end)
test('HUD Macro set and book controls select native books 1-20 with wrapping arrows',function()
 ready();s.visible=true;s.showTests=false;s.statebarEnabled=false;s.navKeysEnabled=false;s.autoHide=false;s.autoRefresh=false;s.pendingRefreshFrames=0;s.allowSwitch=true;s.macroObject=65536;s.addresses.macro_object=65536;s.addresses.set_book=65536
 local button=ui.Button;local select=ui.Selectable;local cast=ffi.cast;local text=ui.Text;local indices={};local options=0;local setLabel=false
 ffi.cast=function(kind,value) if kind=='Decker_FsMacroContainer_setBook_f' then return function(_,index) indices[#indices+1]=index end end;return cast(kind,value) end
 ui.Text=function(t) if t:find('Macro set ',1,true)==1 then setLabel=true end end
 ui.Selectable=function(label)
  local book=tonumber(label:match('##hudbookchoice(%d+)$'))
  if book then assert(book<=20);options=options+1 end
  return book==2
 end
 events.decker_draw();assert(options==20 and setLabel and s.manualBook==2 and indices[#indices]==1)
 ui.Selectable=function() return false end;s.manualBook=20;ui.Button=function(label) return label=='>##booknext' end;events.decker_draw();assert(s.manualBook==1 and indices[#indices]==0)
 s.manualBook=1;ui.Button=function(label) return label=='<##bookprev' end;events.decker_draw();assert(s.manualBook==20 and indices[#indices]==19)
 ui.Button=button;ui.Selectable=select;ffi.cast=cast;ui.Text=text
end)

test('both updater channels offer newer versions and complete mocked install backup and reload',function()
 local originalNew=ffi.new;local button=ui.Button;local running=addon.version
 ffi.new=function() return {[0]=0} end
 api.setKernel({GetExitCodeProcess=function(_,p) p[0]=0;return 1 end,CloseHandle=function() end})
 local function write(name,bytes) local file=assert(io.open(tmp..'/'..name,'wb'));file:write(bytes);file:close() end
 local function job(mode) api.updater.job={handle=1,mode=mode,started=os.time(),pollAt=0};api.poll() end
 for _,channel in ipairs({'stable','development'}) do
  ready();s.visible=true;s.showTests=true;s.settingsTab='Updates';s.statebarEnabled=false;s.navKeysEnabled=false;s.autoHide=false;s.autoRefresh=false;s.pendingRefreshFrames=0;s.lastProfileCheck=os.clock()
  api.updater.channel=channel;api.updater.installed=false;api.updater.manifest=nil;addon.version='1.50.12-dev'
  local manifest='protocol=1\nversion='..running..'\ncommit='..string.rep('b',40)..'\nsha256='..string.rep('a',64)..'\n'
  write('.decker-update-manifest.txt',manifest);job('Check')
  assert(api.updater.status:find('Update available.',1,true) and api.updater.status:find('Installed: v1.50.12-dev',1,true) and api.updater.status:find(channel..' channel: v'..running,1,true))
  local offers=0;ui.Button=function(label) if label=='Install update and reload Decker' then offers=offers+1 end;return false end
  events.decker_draw();assert(offers==1)
  local file=assert(io.open(path,'rb'));local before=file:read('*a');file:close()
  write('.decker-update-source.lua',source);job('Download')
  assert(api.updater.installed and requested[#requested]=='/addon reload decker')
  file=assert(io.open(path,'rb'));assert(file:read('*a')==source);file:close()
  file=assert(io.open(tmp..'/decker.lua.bak','rb'));assert(file:read('*a')==before);file:close()
  addon.version=running;api.updater.installed=false;write('.decker-update-manifest.txt',manifest);job('Check');offers=0;events.decker_draw()
  assert(offers==0 and api.updater.status:find('Up to date.',1,true) and api.updater.status:find(channel..' channel: v'..running,1,true))
 end
 ffi.new=originalNew;ui.Button=button;addon.version=running;api.setKernel(nil);s.showTests=false
end)
test('Stable update page no longer claims the channel is unpublished',function()
 ready();s.visible=true;s.showTests=true;s.settingsTab='Updates';s.statebarEnabled=false;s.navKeysEnabled=false;s.autoHide=false;s.autoRefresh=false;s.pendingRefreshFrames=0
 api.updater.channel='stable';api.updater.installed=false
 local wrapped=ui.TextWrapped;local found=false
 ui.TextWrapped=function(t) assert(not t:find('No stable updater release has been published yet',1,true));if t:find('Stable and Development channels are available',1,true) then found=true end end
 events.decker_draw();assert(found);ui.TextWrapped=wrapped
end)

os.execute('rm -r '..tmp)
print(passed..' regression groups passed (mocked host; not in-game validation)')
