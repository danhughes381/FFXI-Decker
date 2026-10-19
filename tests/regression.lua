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
local expose='\nreturn {state=state,refresh=refresh_profile,save=save_display,load=load_display,request=request_statebar,valid=valid_command,reset=restore_section,mapped=mapped_key,hotkey=statebar_hotkey_slot,execute=execute_slot}'
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
 ready();s.statebarSlots={{row='CTRL',slot=1,kind='state',source='command',command='/lac set PDT'}};assert(api.request(1));assert(requested[#requested]=='/lac set PDT')
 api.save();s.statebarSlots={};api.load();assert(s.statebarSlots[1].command=='/lac set PDT' and s.statebarSlots[1].source=='command')
end)
test('section reset only affects selected preferences',function() s.theme=4;s.mappingMode='numbers';api.reset('StateBar');assert(s.theme==4 and s.mappingMode=='numbers' and not s.statebarEnabled);api.reset('Controls');assert(s.theme==4 and s.mappingMode=='split' and not s.keybinds) end)
test('all three layouts and N row switch',function() s.navKeysEnabled=false;s.mappingMode='split';local r,k=api.mapped(59);assert(r=='CTRL' and k==1);r,k=api.mapped(2);assert(r=='ALT' and k==1);s.navRow='ALT';s.mappingMode='numbers';r,k=api.mapped(2);assert(r=='ALT' and k==1);s.mappingMode='functions';r,k=api.mapped(68);assert(r=='ALT' and k==10);s.rowSwitchKey='N';api.save();s.rowSwitchKey='END';api.load();assert(s.rowSwitchKey=='N') end)
test('StateBar collisions and permission gates',function() ready();s.keybinds=true;s.acknowledgeKeys=true;s.statebarEnabled=true;s.statebarHotkeysEnabled=true;s.statebarHotkeys={59};s.mappingMode='split';assert(not api.hotkey(59));s.statebarHotkeys={87};assert(api.hotkey(87)==1);s.navKeysEnabled=true;s.rowSwitchKey='F11';assert(not api.hotkey(87));s.navKeysEnabled=false;s.acknowledgeKeys=false;assert(not api.hotkey(87)) end)
test('single hotkey execution and key release after disable',function() ready();s.keybinds=true;s.acknowledgeKeys=true;s.statebarEnabled=true;s.statebarHotkeysEnabled=true;s.statebarHotkeys={87};s.held={};s.suppressed={};local n=#requested;local e={key=87,down=true};events.decker_statebar_key_press(e);events.decker_statebar_key_press(e);assert(#requested==n+1);s.keybinds=false;s.statebarHotkeysEnabled=false;e={key=87,down=false};events.decker_exclusive_key_press(e);assert(e.blocked and not s.suppressed[87]) end)
test('Settings sections render with balanced style stacks',function()
 ready();s.showTests=true;s.visible=true;s.statebarEnabled=true;s.statebarSelected=1;s.statebarSlots={{row='CTRL',slot=1,kind='state'}};s.lastProfileCheck=os.clock();s.autoRefresh=false;s.pendingRefreshFrames=0
 for _,tab in ipairs({'Controls','Appearance','StateBar','General','Profiles','Updates'}) do s.settingsTab=tab;events.decker_draw();assert(styles==0 and vars==0,tab) end
end)
os.execute('rm -r '..tmp)
print(passed..' regression groups passed (mocked host; not in-game validation)')
