-- Decker 1.50.0-dev: native macro HUD for VanaCore/Ashita 4.
-- Native macro calls and opt-in DirectInput keyboard hooks; no original HUD patches.
-- CAUTION: Opt-in native FFI call may crash the FFXI process if signatures/API differ.
addon.name = 'Decker';
addon.author = 'Mutant X';
addon.version = '1.50.0-dev';
addon.desc = 'FFXI-inspired dual-row macro HUD; validated mouse execution and opt-in keyboard controls.';
require('common');
local chat = require('chat');
local imgui = require('imgui');
local ffi = require('ffi');
ffi.cdef[[typedef const char* (__thiscall* Decker_FsMacroContainer_getName_f)(uint32_t, uint32_t); typedef int32_t (__thiscall* Decker_FsMacroContainer_setPage_f)(uint32_t, uint32_t); typedef int32_t (__thiscall* Decker_FsMacroContainer_setBook_f)(uint32_t, uint32_t); typedef void (__thiscall* Decker_FsMacroContainer_runMacro_f)(uint32_t, uint8_t, uint8_t);]];
local state = { visible=true, signatures={}, addresses={}, summary='Not scanned', pointerSummary='Not checked', nameSummary='Not attempted', phase=0, confirm=false, confirmAll=false, scanning=false, names={}, setHint='Current in-game set (not independently detected)', nameCount=0, allowSwitch=false, selectedPage=nil, previousFingerprint=nil, changeSummary='Not checked', switchSummary='Not attempted', autoRefresh=false, refreshAt=0, refreshInterval=3, compact=true, details=false, showTests=false, clickConsent=false, clickSummary='Not attempted', scale=1.0, refreshErrorCount=0, hudWidth=92, hudHeight=43, allowAllClicks=false, nativeHudStudy=false, theme=1, compactKeys=true, keybinds=false, acknowledgeKeys=false, held={}, keySummary='Exclusive bindings OFF by default', preserveNativeArrows=true, pendingRefreshFrames=0, manualBook=1, trackedSet=1, trackedSource='default (unverified)', suppressed={}, nativeArrowRefreshes=0, showAdvanced=false, debugLog=false, flashRow=nil, flashSlot=nil, flashUntil=0, navSlot=nil, navRow=nil, navSource='unverified', navHeld={}, navModifier='RSHIFT', navKeysEnabled=false, navModifierHeld=false, navCaptured={}, navUpHeld=false, navDownHeld=false, stickyNavigation=true, navToggleActive=false, navPressed={}, navPhysicalDown=false, navHeldKeys={}, navPhysicalKeys={}, navQueue={}, navRow='CTRL', navSlot=1, navSource='default', savedNavEnabled=false, savedKeybinds=false, savedAck=false, rowSwitchKey='END', hudOpacity=1.0, echoLock=true, autoHide=false, autoHideDelay=10, autoHideMode='collapse', hudLastActivity=os.clock(), hudWasActive=false, hudReadySince=nil, hudHasInteracted=false, hudForceReveal=false };
-- Configurable direct bindings. Defaults retain the original 1-0 / F1-F10 scheme.
-- All direct shortcuts are opt-in; never rewrite FFXI's native macro keys.
local DIRECT_KEY_OPTIONS={
    {'None',0},{'1',2},{'2',3},{'3',4},{'4',5},{'5',6},{'6',7},{'7',8},{'8',9},{'9',10},{'0',11},
    {'F1',59},{'F2',60},{'F3',61},{'F4',62},{'F5',63},{'F6',64},{'F7',65},{'F8',66},{'F9',67},{'F10',68},
    {'F11',87},{'F12',88},{'Q',16},{'W',17},{'E',18},{'R',19},{'T',20},{'Y',21},{'U',22},{'I',23},{'O',24},{'P',25},
    {'A',30},{'S',31},{'D',32},{'F',33},{'G',34},{'H',35},{'J',36},{'K',37},{'L',38},
    {'Z',44},{'X',45},{'C',46},{'V',47},{'B',48},{'N',49},{'M',50}
};
local DIRECT_NAMES={}; local DIRECT_CODES={};
for _,item in ipairs(DIRECT_KEY_OPTIONS) do DIRECT_NAMES[item[2]]=item[1]; DIRECT_CODES[item[1]]=item[2]; end
local function default_direct_keys()
    local t={}; for i=1,10 do t[i]=58+i; t[10+i]=i==10 and 11 or i+1; end; return t;
end
state.directKeys=default_direct_keys();
state.settingsTab='Controls'; state.statebarEnabled=false; state.statebarVertical=false; state.statebarLocked=false; state.statebarAlways=true; state.statebarScale=1.0; state.statebarOpacity=1; state.statebarTheme=1; state.statebarVisibility='always'; state.statebarSlots={{row='CTRL',slot=1},{row='CTRL',slot=2},{row='CTRL',slot=3},{row='ALT',slot=1}};
state.statebarOpacity=1.0; state.statebarTheme=1; state.statebarVisibility='always'; state.profileDiagnostic='Not checked'; state.statebarSelected=0;
state.statebarHotkeys={}; state.statebarHotkeysEnabled=false; state.statebarActionMode='current';
state.mappingMode='split'; state.positionLocked=false; state.hudPos=nil; state.profileId=nil; state.profileReady=false; state.lastProfileCheck=0;
local function copy_value(v)
    if type(v)~='table' then return v; end
    local t={}; for k,x in pairs(v) do t[k]=copy_value(x); end; return t;
end
-- Glass preferences are display-only and participate in character profile isolation.
state.outerOpacity=.05; state.panelOpacity=.15; state.buttonOpacity=.85;
state.statebarOpacity=.15; state.macroFont='Arial Bold'; state.macroFontSize=18;
local profileDefaults=copy_value(state);
local sectionKeys={
    Controls={'mappingMode','directKeys','navModifier','rowSwitchKey','stickyNavigation','navKeysEnabled','keybinds','acknowledgeKeys','savedNavEnabled','savedKeybinds','savedAck','echoLock'},
    Appearance={'outerOpacity','panelOpacity','buttonOpacity','macroFont','macroFontSize','scale','theme','hudWidth','hudHeight','compactKeys','hudOpacity','autoHide','autoHideDelay','autoHideMode','positionLocked'},
    StateBar={'statebarEnabled','statebarVertical','statebarLocked','statebarAlways','statebarScale','statebarOpacity','statebarTheme','statebarVisibility','statebarSelected','statebarHotkeys','statebarHotkeysEnabled','statebarSlots'},
    General={'manualBook','trackedSet','cooldownEnabled','cooldownBindings'},
};
-- First-install defaults also form the profile-isolation boundary.
profileDefaults.autoHide=false; profileDefaults.autoHideMode='collapse';
profileDefaults.cooldownEnabled=false; profileDefaults.cooldownBindings={};
local function direct_conflict(code,index)
    if code==0 then return false; end
    if state.mappingMode=='split' then for i,k in ipairs(state.directKeys) do if i~=index and k==code then return true; end end end
    -- Avoid keys reserved for navigation while custom navigation is enabled.
    local reserved={ [203]=true,[205]=true,[200]=true,[208]=true,[28]=true,[1]=true,[57]=true };
    if state.navKeysEnabled and (reserved[code] or code==({RSHIFT=54,LSHIFT=42,END=207,HOME=199})[state.navModifier] or code==({END=207,HOME=199,INSERT=210,DELETE=211,N=49,F9=67,F10=68,F11=87,F12=88})[state.rowSwitchKey]) then return true; end
    return false;
end
-- Display-only preferences saved next to this addon. No macro data or game files are written.
local function settings_path()
    local source=(debug.getinfo(1,'S') or {}).source or '';
    if source:sub(1,1)~='@' then return nil; end
    local directory=source:sub(2):match('^(.*[\\/])');
    if not directory then return nil; end
    return directory..(state.profileId and ('decker_profile_'..state.profileId..'.cfg') or 'decker_display.cfg');
end
-- Cooldown bindings are optional per button; never infer actions from user-defined labels.
state.cooldownEnabled=false;
state.cooldownBindings={};
local function cooldown_recast(binding)
    if not binding or not state.cooldownEnabled then return false; end
    local ok,remaining=pcall(function()
        local memory=AshitaCore:GetMemoryManager();
        local recast=memory and memory:GetRecast();
        if not recast then return nil; end
        if binding.kind=='spell' then return recast:GetSpellTimer(binding.id); end
        if binding.kind=='ability' then
            -- Recast slots are not ability IDs; match the game's timer ID first.
            for index=0,31 do
                if recast:GetAbilityTimerId(index)==binding.id then
                    return recast:GetAbilityTimer(index);
                end
            end
        end
        return nil;
    end);
    return ok and type(remaining)=='number' and remaining>0;
end
local function save_display()
    if not state.profileReady then return; end
    local path=settings_path(); if not path then return; end
    local ok,f=pcall(io.open,path,'w'); if not ok or not f then return; end
    f:write('glassversion=1\nouteropacity=',state.outerOpacity,'\npanelopacity=',state.panelOpacity,'\nbuttonopacity=',state.buttonOpacity,'\nmacrofont=',state.macroFont:gsub(' ','_'),'\nmacrofontsize=',state.macroFontSize,'\n');
    f:write('theme=',state.theme,'\nscale=',state.scale,'\nwidth=',state.hudWidth,'\nheight=',state.hudHeight,'\ncompact=',state.compactKeys and '1' or '0','\nbook=',state.manualBook or 1,'\nset=',state.trackedSet or 1,'\nopacity=',state.hudOpacity,'\nautohide=',state.autoHide and '1' or '0','\nautohidedelay=',state.autoHideDelay,'\nautohidemode=',state.autoHideMode,'\necholock=',state.echoLock and '1' or '0','\nrowswitchkey=',state.rowSwitchKey,'\nnavmodifier=',state.navModifier,'\nnavmode=',state.stickyNavigation and 'toggle' or 'hold','\nnavenabled=',state.navKeysEnabled and '1' or '0','\nkeybinds=',state.keybinds and '1' or '0','\nackkeys=',state.acknowledgeKeys and '1' or '0','\n');
    f:write('mappingmode=',state.mappingMode,'\npositionlocked=',state.positionLocked and '1' or '0','\nnavrow=',state.navRow or 'CTRL','\n');
    if state.hudPos then f:write('posx=',math.floor(state.hudPos[1]),'\nposy=',math.floor(state.hudPos[2]),'\n'); end
    f:write('statebarenabled=',state.statebarEnabled and '1' or '0','\nstatebarvertical=',state.statebarVertical and '1' or '0','\nstatebarlocked=',state.statebarLocked and '1' or '0','\nstatebaralways=',state.statebarAlways and '1' or '0','\nstatebarscale=',state.statebarScale,'\nstatebaropacity=',state.statebarOpacity,'\nstatebartheme=',state.statebarTheme,'\nstatebarvisibility=',state.statebarVisibility,'\nstatebarselected=',state.statebarSelected or 0,'\n');
    f:write('statebarcount=',#state.statebarSlots,'\n');
    f:write('statebarhotkeysenabled=',state.statebarHotkeysEnabled and '1' or '0','\n');
    for i,b in ipairs(state.statebarSlots) do f:write('statebar',i,'=',b.row,':',b.slot,'\n'); f:write('statebarhotkey',i,'=',state.statebarHotkeys[i] or 0,'\n'); f:write('statebartype',i,'=',b.kind or 'state','\n'); f:write('statebarcommand',i,'=',(b.command or ''):gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n'); f:write('statebarsource',i,'=',b.source or 'macro','\n'); f:write('statebarlabel',i,'=',(b.label or ''):gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n'); end
    f:write('cooldownenabled=',state.cooldownEnabled and '1' or '0','\n');
    for i=1,20 do local b=state.cooldownBindings[i]; if b then f:write('cooldown',i,'=',b.kind,':',b.id,'\n'); end end
    for i=1,20 do f:write('direct',i,'=',state.directKeys[i] or 0,'\n'); end
    f:close();
end
local function load_display()
    local path=settings_path(); if not path then return; end
    local ok,f=pcall(io.open,path,'r'); if not ok or not f then return; end
    for line in f:lines() do
        local key,value=line:match('^(%w+)=([%w_.:]+)$');
        local n=tonumber(value);
        if key=='statebarcount' and n and n>=0 and n<=12 and n==math.floor(n) then state.statebarSlots={}; end
        local ti=key and tonumber(key:match('^statebartype(%d+)$'));
        local xi=key and tonumber(key:match('^statebarcommand(%d+)$'));
        local mi=key and tonumber(key:match('^statebarsource(%d+)$'));
        local li=key and tonumber(key:match('^statebarlabel(%d+)$'));
        local bi=ti or xi or mi or li;
        if bi and bi>=1 and bi<=12 and state.statebarSlots[bi] then
            local b=state.statebarSlots[bi];
            if ti and (value=='state' or value=='utility') then b.kind=value; end
            if mi and (value=='macro' or value=='command') then b.source=value; end
            if li and #value<=48 and #value%2==0 and not value:find('[^%x]') then b.label=value:gsub('%x%x',function(h) return string.char(tonumber(h,16)); end):gsub('[%c#]',''); end
            if xi and #value<=480 and #value%2==0 and not value:find('[^%x]') then b.command=value:gsub('%x%x',function(h) return string.char(tonumber(h,16)); end); end
        end
        if key=='statebaropacity' and n and n>=0 and n<=1 then state.statebarOpacity=n; end
        if key=='statebartheme' and n and n>=1 and n<=4 then state.statebarTheme=n; end
        if key=='statebarvisibility' and (value=='always' or value=='navigation' or value=='manual') then state.statebarVisibility=value; end
        if key=='statebarselected' and n and n>=0 and n<=12 then state.statebarSelected=n; end
        if key=='statebarhotkeysenabled' then state.statebarHotkeysEnabled=value=='1'; end
        local hi=key and tonumber(key:match('^statebarhotkey(%d+)$'));
        if hi and hi>=1 and hi<=12 and n and DIRECT_NAMES[n] then state.statebarHotkeys[hi]=n; end
        if key=='statebarenabled' then state.statebarEnabled=value=='1'; end
        if key=='statebarvertical' then state.statebarVertical=value=='1'; end
        if key=='statebarlocked' then state.statebarLocked=value=='1'; end
        if key=='statebaralways' then state.statebarAlways=value=='1'; end
        if key=='statebarscale' and n and n>=0.7 and n<=1.5 then state.statebarScale=n; end
        local si=key and tonumber(key:match('^statebar(%d+)$'));
        if si and si>=1 and si<=12 then local row,slot=value:match('^(CTRL):(%d+)$'); if not row then row,slot=value:match('^(ALT):(%d+)$'); end; slot=tonumber(slot); if row and slot and slot>=1 and slot<=10 then state.statebarSlots[si]={row=row,slot=slot}; end end
        if key=='mappingmode' and (value=='split' or value=='numbers' or value=='functions') then state.mappingMode=value; end
        if key=='positionlocked' then state.positionLocked=value=='1'; end
        if key=='navrow' and (value=='CTRL' or value=='ALT') then state.navRow=value; end
        if key=='posx' and n and n>=0 and n<=20000 then state.hudPos=state.hudPos or {0,0}; state.hudPos[1]=n; end
        if key=='posy' and n and n>=0 and n<=20000 then state.hudPos=state.hudPos or {0,0}; state.hudPos[2]=n; end
        if key=='cooldownenabled' then state.cooldownEnabled=value=='1'; end
        local ci=key and tonumber(key:match('^cooldown(%d+)$'));
        if ci and ci>=1 and ci<=20 then local kind,id=value:match('^(spell):(%d+)$'); if not kind then kind,id=value:match('^(ability):(%d+)$'); end; if kind and tonumber(id) then state.cooldownBindings[ci]={kind=kind,id=tonumber(id)}; end end
        local directIndex=key and tonumber(key:match('^direct(%d+)$'));
        if directIndex and directIndex>=1 and directIndex<=20 and n and DIRECT_NAMES[n] then state.directKeys[directIndex]=n; end
        if key=='autohide' and (value=='0' or value=='1') then state.autoHide=value=='1'; end
        if key=='autohidedelay' and (n==2 or n==5 or n==10 or n==15 or n==30) then state.autoHideDelay=n; end
        if key=='autohidemode' and (value=='hide' or value=='collapse') then state.autoHideMode=value; end
        if key=='echolock' and (value=='0' or value=='1') then state.echoLock=value=='1'; end
        if key=='outeropacity' and n and n>=0 and n<=1 then state.outerOpacity=n; end
        if key=='panelopacity' and n and n>=0 and n<=1 then state.panelOpacity=n; end
        if key=='buttonopacity' and n and n>=0 and n<=1 then state.buttonOpacity=n; end
        if key=='macrofontsize' and n and n>=10 and n<=28 then state.macroFontSize=n; end
        if key=='macrofont' then value=value:gsub('_',' '); end
        if key=='macrofont' and (value=='Arial Bold' or value=='Segoe UI Bold' or value=='Times New Roman Bold' or value=='Default') then state.macroFont=value; end
        if key=='opacity' and n and n>=0.2 and n<=1 then state.hudOpacity=n; end
        if key=='rowswitchkey' and (value=='END' or value=='HOME' or value=='INSERT' or value=='DELETE' or value=='N' or value=='F9' or value=='F10' or value=='F11' or value=='F12') then state.rowSwitchKey=value; end
        if key=='stickynav' and (value=='0' or value=='1') then state.stickyNavigation=value=='1'; end
        if key=='navmode' and (value=='toggle' or value=='hold') then state.stickyNavigation=value=='toggle'; end
        if key=='navenabled' and (value=='0' or value=='1') then state.savedNavEnabled=value=='1'; end
        if key=='keybinds' and (value=='0' or value=='1') then state.savedKeybinds=value=='1'; end
        if key=='ackkeys' and (value=='0' or value=='1') then state.savedAck=value=='1'; end
        -- Legacy auto-exit preference intentionally ignored: navigation now has only Toggle and Hold modes.
        if key=='navmodifier' and (value=='END' or value=='HOME' or value=='RSHIFT' or value=='LSHIFT') then state.navModifier=(value=='END' and 'RSHIFT' or value); end
        if key=='theme' and n and n>=1 and n<=4 and n==math.floor(n) then state.theme=n;
        elseif key=='scale' and n and n>=0.7 and n<=1.5 then state.scale=n;
        elseif key=='width' and n and n>=80 and n<=140 then state.hudWidth=n;
        elseif key=='height' and n and n>=30 and n<=90 then state.hudHeight=n;
        elseif key=='compact' and (value=='0' or value=='1') then state.compactKeys=value=='1';
        elseif key=='book' and n and n==math.floor(n) and n>=1 and n<=40 then state.manualBook=n;
        elseif key=='set' and n and n==math.floor(n) and n>=1 and n<=10 then state.trackedSet=n; state.trackedSource='saved (unverified)'; end
    end
    f:close();
end
-- Character names are resolved only after login; never write to the shared legacy file.
local function character_id()
    -- VanaCore builds differ in player interfaces. Party member 0 is a
    -- supported alternative to GetPlayer():GetName(); never invent an identity.
    local mm=AshitaCore and AshitaCore:GetMemoryManager();
    if not mm then state.profileDiagnostic='Memory manager unavailable'; return nil; end
    local candidates={
        function() local p=mm:GetPlayer(); return p and p:GetName(); end,
        function() local party=mm:GetParty(); return party and party:GetMemberName(0); end,
    };
    local name=nil;
    for i,read in ipairs(candidates) do
        local ok,value=pcall(read);
        if ok and type(value)=='string' and value:match('^[%a][%w_]+$') and #value>=2 then
            name=value; state.profileDiagnostic='Character read from source '..i; break;
        end
    end
    if not name then state.profileDiagnostic='No valid character name from Player or Party'; return nil; end
    local server='server';
    local ok,id=pcall(function() local p=mm:GetPlayer(); return p and p.GetServerId and p:GetServerId(); end);
    if ok and type(id)=='number' and id>0 then server=tostring(id); end
    return (server..'_'..name):gsub('[^%w_]','_');
end
local function refresh_profile()
    local id=character_id();
    if id==state.profileId then return; end
    if state.profileReady then save_display(); end
    state.profileId=id; state.profileReady=false;
    for _,keys in pairs(sectionKeys) do for _,key in ipairs(keys) do state[key]=copy_value(profileDefaults[key]); end end
    state.hudPos=nil; state.statebarSelected=0; state.navRow='CTRL'; state.navSlot=1;
    state.names={}; state.phase=0; state.allowAllClicks=false; state.allowSwitch=false;
    state.autoRefresh=false; state.clickConsent=false; state.confirmAll=false;
    state.navToggleActive=false; state.navModifierHeld=false; state.navPhysicalDown=false;
    state.navCaptured={}; state.navPressed={}; state.navPhysicalKeys={}; state.navQueue={}; state.deferredNav={};
    state.navSetVerifyFrames=0; state.pendingRefreshFrames=0; state.lastExecuted=nil;
    state.flashRow=nil; state.flashSlot=nil; state.flashUntil=0;
    state.hudReadySince=nil; state.hudLastActivity=os.clock();
    if id then
        load_display(); state.profileReady=true;
        -- Legacy full-hide preferences are migrated to a recoverable collapsed tab.
        if state.autoHideMode=='hide' then state.autoHideMode='collapse'; save_display(); end
        state.navKeysEnabled=state.savedNavEnabled;
        -- Overrides require fresh consent per session, regardless of saved preferences.
        state.keybinds=false; state.acknowledgeKeys=false; state.savedAck=false; state.savedKeybinds=false;
    end
    state.held={}; state.suppressed={};
end
-- Restore user-approved navigation at startup; native macro execution still requires explicit Connect.
state.navKeysEnabled=state.savedNavEnabled;
state.navRow='CTRL'; state.navSlot=1;
state.hudLastActivity=os.clock();
state.debugLog=false; -- Developer chat output must be explicitly enabled each session.
-- Upstream Ashita v4beta addons/libs/ffxi/macros.lua, consulted 2026-10-14.
local patterns = {
    { 'macro_object', '8B0D????????E8????????8B4424105EC38B15????????68', 2 },
    { 'controller', 'A3????????EB??891D????????6A50E8', 1 },
    { 'get_name', '8B44240485C07C??83F8147D??8D1440C1E2052BD08D4C9104E8????????85C0', 0 },
    { 'get_line', '8B44240485C07C??83F8147D??8B542408528D1440C1E2052BD08D4C9104E8????????C2080033C0C20800', 0 },
    { 'run', '8A44240453563C018BF175??8A5C24108B4E040FBEC350E8', 0 },
    { 'set_book', '8B442404568BF18B8EC01D00003BC875??8BC15EC20400', 0 },
    { 'set_page', '568BF1578B7C240C8B86C01D00008D04', 0 },
};
local function say(s, force)
    if force or state.debugLog then print(chat.header(addon.name) .. tostring(s)); end
end
local function validaddr(v)
    return type(v)=='number' and v >= 0x10000 and v <= 0xFFFFFFFF and v == math.floor(v);
end
local function hex(v) if not validaddr(v) then return 'INVALID'; end return string.format('0x%08X', v); end
local function scan()
    if state.scanning then return; end
    state.scanning=true; state.phase=0; state.confirm=false; state.addresses={}; state.signatures={};
    state.pointerSummary='Not checked'; state.nameSummary='Not attempted'; state.selectedPage=nil; state.allowSwitch=false; state.previousFingerprint=nil; state.changeSummary='Not checked'; state.switchSummary='Not attempted'; state.names={}; state.nameCount=0; state.confirmAll=false; state.autoRefresh=false; state.clickConsent=false; state.allowAllClicks=false; state.navSlot=nil; state.navRow=nil;
    local mem = ashita and ashita.memory;
    if not mem or type(mem.find) ~= 'function' then
        state.summary='memory.find unavailable'; state.scanning=false; return;
    end
    local count=0;
    for _,p in ipairs(patterns) do
        local ok,addr=pcall(function() return mem.find(0,0,p[2],p[3],0); end);
        if ok and validaddr(addr) then state.addresses[p[1]]=addr; count=count+1; end
        local result=(ok and validaddr(addr)) and ('FOUND '..hex(addr)) or (ok and 'NOT FOUND' or 'SEARCH ERROR');
        state.signatures[#state.signatures+1]={p[1],result};
    end
    state.summary=('%d/%d signatures located'):format(count,#patterns);
    state.phase=(state.addresses.macro_object and state.addresses.get_name) and 1 or 0;
    state.scanning=false; say(state.summary);
end
local function pointer_check()
    state.phase=1; state.confirm=false; state.confirmAll=false; state.names={}; state.nameCount=0; state.nameSummary='Not attempted';
    if not state.addresses.macro_object or not state.addresses.get_name then
        state.pointerSummary='FAILED: scan first, required signatures absent'; state.allowAllClicks=false; return;
    end
    local mem=ashita and ashita.memory;
    if not mem or type(mem.read_uint32)~='function' then
        state.pointerSummary='FAILED: read_uint32 unavailable'; return;
    end
    -- Match upstream get_fsmacro(): two reads through the global pointer.
    -- pcall only protects Lua failures; invalid native accesses can still crash.
    local ok, outer=pcall(function() return mem.read_uint32(state.addresses.macro_object); end);
    if not ok or not validaddr(outer) or outer % 4 ~= 0 then
        state.pointerSummary='FAILED: macro global pointer ' .. hex(outer); return;
    end
    local ok2,obj=pcall(function() return mem.read_uint32(outer); end);
    if not ok2 or not validaddr(obj) or obj % 4 ~= 0 then
        state.pointerSummary='FAILED: macro object ' .. hex(obj); return;
    end
    state.macroObject=obj;
    state.phase=2;
    state.pointerSummary='PASS: 2 pointer reads; object='..hex(obj)..' (not structurally verified)';
    say(state.pointerSummary);
end
local function read_one_name()
    if state.phase ~= 2 or not state.confirm or not validaddr(state.macroObject) then return; end
    -- Only slot 0, current in-game macro selection; no loop over memory.
    -- IMPORTANT: FFI may crash client; pcall cannot catch access violations.
    state.confirm=false;
    local ok, result=pcall(function()
        local func=ffi.cast('Decker_FsMacroContainer_getName_f',state.addresses.get_name);
        local ptr=func(state.macroObject,0);
        if ptr == nil then return '(null name pointer)'; end
        -- Max 8 bytes, matching native macro title limit, to avoid unbounded scans.
        local str=ffi.string(ptr,8);
        return (str:gsub('%z.*$',''));
    end);
    if ok then
        state.nameSummary='CTRL slot 1 / index 0: '..(result=='' and '(empty)' or tostring(result));
    else
        state.nameSummary='Lua error: '..tostring(result);
    end
    state.phase=3;
    say(state.nameSummary);
end
-- Index 0..9 = first row, 10..19 = second row. Never write to macro data.
-- A native crash cannot be caught by pcall. Explicitly opt in after prior one-name test.
local function read_all_names()
    if state.phase < 2 or not state.confirmAll or not validaddr(state.macroObject) or
       not validaddr(state.addresses.get_name) then return; end
    state.confirmAll=false;
    -- Recheck pointer chain before entering native function calls.
    local mem=ashita and ashita.memory;
    local ok,outer=pcall(function() return mem.read_uint32(state.addresses.macro_object); end);
    local ok2,obj=false,nil;
    if ok and validaddr(outer) and outer % 4 == 0 then
        ok2,obj=pcall(function() return mem.read_uint32(outer); end);
    end
    if not ok2 or not validaddr(obj) or obj ~= state.macroObject then
        state.nameSummary='ABORT: macro object pointer changed; rescan and validate';
        state.names={}; state.nameCount=0; state.phase=1; state.autoRefresh=false; state.clickConsent=false; state.allowAllClicks=false; return;
    end
    local names={}; local nonempty=0;
    local good,err=pcall(function()
        local func=ffi.cast('Decker_FsMacroContainer_getName_f',state.addresses.get_name);
        for i=0,19 do
            local ptr=func(obj,i);
            local label='';
            if ptr ~= nil then label=(ffi.string(ptr,8):gsub('%z.*$','')); end
            -- Strip control characters only for display. Do not change game macro data.
            label=label:gsub('[%c]','');
            names[i+1]=label;
            if label ~= '' then nonempty=nonempty+1; end
        end
    end);
    if not good then
        state.nameSummary='Lua error during read: '..tostring(err);
        state.names={}; state.nameCount=0; state.allowAllClicks=false; return;
    end
    local fingerprint=table.concat(names, '\031');
    if state.debugLog and state.tracePending then
        say(('TRACE names +refresh source=%s frame=%s fingerprint=%s'):format(state.tracePending.source,tostring(state.tracePending.frames or '?'),fingerprint:sub(1,88)));
    end
    if state.previousFingerprint ~= nil then
        state.changeSummary=(fingerprint==state.previousFingerprint) and 'Names unchanged since previous refresh (does not prove same set).' or 'Names changed since previous refresh (book/set or edited macro may have changed).';
    else
        state.changeSummary='First snapshot captured; native book/set number not independently known.';
    end
    if state.awaitingPageFingerprint then
        if fingerprint==state.awaitingPageFingerprint then
            state.switchSummary='WARNING: Native macro names did not change after set request. Set not independently confirmed; verify FFXI set before using the deck.';
            state.trackedSource='unverified (same names)';
        else
            state.switchSummary='Macro names changed after set request (set number still tracked, not independently read).';
        end
        state.awaitingPageFingerprint=nil;
    end
    state.previousFingerprint=fingerprint;
    state.names=names; state.nameCount=nonempty; state.phase=4; state.refreshErrorCount=0;
    state.nameSummary=('Read 20 slots (%d named). Snapshot of CURRENT game book/set.'):format(nonempty);
    state.allowAllClicks=validaddr(state.addresses.controller) and validaddr(state.addresses.run);
    if state.allowAllClicks then state.clickSummary='Mouse execution ready (native pointer checked again on each click).';
    else state.clickSummary='BLOCKED: native execution signatures unavailable'; end
    say(state.nameSummary);
end
-- Opt-in game-state change: not a memory patch, but calls an FFXI native function.
-- Based on upstream ffxi.macros.set_page: arguments 0,2,...18 for UI sets 1..10.
-- No native execution without explicit checkbox and button click.
local function select_page(page)
    if not state.allowSwitch or state.phase < 4 or type(page)~='number' or
       page < 1 or page > 10 or page ~= math.floor(page) then return; end
    if not validaddr(state.addresses.set_page) or not validaddr(state.macroObject) then
        state.switchSummary='BLOCKED: missing set-page signature or macro object'; return;
    end
    local mem=ashita and ashita.memory;
    if not mem or type(mem.read_uint32)~='function' then return; end
    local ok,outer=pcall(function() return mem.read_uint32(state.addresses.macro_object); end);
    local ok2,obj=false,nil;
    if ok and validaddr(outer) and outer % 4 == 0 then
        ok2,obj=pcall(function() return mem.read_uint32(outer); end);
    end
    if not ok2 or obj ~= state.macroObject then
        state.switchSummary='BLOCKED: macro object changed. Rescan and validate.';
        state.phase=1; state.allowSwitch=false; state.autoRefresh=false; state.clickConsent=false; return;
    end
    local navOrigin=state.setRequestSource or 'mouse'; state.setRequestSource=nil;
    if state.debugLog then
        say(('TRACE page source=%s object=%s arg=%d keyPhysical=%s held=%s'):format(navOrigin,hex(obj),2*(page-1),tostring(state.navPhysicalDown),tostring(state.navModifierHeld)));
    end
    local ok3,result=pcall(function()
        return ffi.cast('Decker_FsMacroContainer_setPage_f',state.addresses.set_page)(obj,2*(page-1));
    end);
    if state.debugLog then say(('TRACE page return=%s luaOK=%s'):format(tostring(result),tostring(ok3))); end
    state.tracePending={source=navOrigin,frames=0};
    if not ok3 then state.switchSummary='Lua error: '..tostring(result); return; end
    -- Never claim success from return code alone; require matching in-game visual check.
    state.awaitingPageFingerprint=state.previousFingerprint;
    state.selectedPage=page;
    state.trackedSet=page; state.trackedSource='requested (unverified)'; save_display();
    state.switchSummary=('Requested set %d; native result %s. VERIFY in the game, then refresh names.'):format(page,tostring(result));
    state.pendingRefreshFrames=3; state.nameSummary='Selection requested; refreshing native labels.';
    say(state.switchSummary);
end

-- Explicit book selection. Calls the same native function as the proven Book 1 reset.
-- Book numbering is 1..20 in FFXI; native API accepts zero-based index.
-- Labels are tracked locally, not independently read from game memory.
local function select_native_book(book)
    if type(book)~='number' or book~=math.floor(book) or book<1 or book>20 then
        state.switchSummary='Book must be between 1 and 20.'; return;
    end
    if state.phase<4 or not state.allowSwitch or not validaddr(state.addresses.set_book) or
       not validaddr(state.macroObject) or not validaddr(state.addresses.macro_object) then
        state.switchSummary='Book change blocked: connect and verify native macro functions first.'; return;
    end
    local mem=ashita and ashita.memory;
    if not mem or type(mem.read_uint32)~='function' then return; end
    local ok,outer=pcall(function() return mem.read_uint32(state.addresses.macro_object); end);
    if not ok or not validaddr(outer) or outer%4~=0 then return; end
    local ok2,obj=pcall(function() return mem.read_uint32(outer); end);
    if not ok2 or obj~=state.macroObject then
        state.switchSummary='Book change blocked: macro object changed. Reconnect first.';
        state.phase=1; state.allowSwitch=false; state.autoRefresh=false; return;
    end
    local good,err=pcall(function()
        ffi.cast('Decker_FsMacroContainer_setBook_f',state.addresses.set_book)(obj,book-1);
    end);
    if not good then state.switchSummary='Native book request failed: '..tostring(err); return; end
    state.manualBook=book;
    state.trackedSource='book requested (unverified)';
    state.previousFingerprint=nil;
    state.pendingRefreshFrames=3;
    state.switchSummary=('Requested GAME book %02d. Verify in FFXI; set selection may change.'):format(book);
    state.hudLastActivity=os.clock(); state.hudHasInteracted=true; save_display(); say(state.switchSummary);
end

-- Reset the GAME to Book 1, Set 1, not just the displayed heading.
-- This is a separate opt-in native call and may crash an incompatible client.
local function reset_native_book()
    if state.phase < 4 or not state.allowSwitch or not validaddr(state.addresses.set_book) then
        state.switchSummary='Reset blocked: connect macros and verify book signature first.'; return;
    end
    local mem=ashita and ashita.memory;
    if not mem then return; end
    local ok,outer=pcall(function() return mem.read_uint32(state.addresses.macro_object); end);
    if not ok or not validaddr(outer) then return; end
    local ok2,obj=pcall(function() return mem.read_uint32(outer); end);
    if not ok2 or obj~=state.macroObject then
        state.switchSummary='Reset blocked: native macro object changed.'; return;
    end
    local good,err=pcall(function()
        ffi.cast('Decker_FsMacroContainer_setBook_f',state.addresses.set_book)(obj,0);
    end);
    if not good then state.switchSummary='Native book reset Lua error: '..tostring(err); return; end
    state.manualBook=1;
    select_page(1);
    state.pendingRefreshFrames=3;
    state.trackedSource='requested reset (unverified)';
    save_display();
end
-- Small rate-limited refresh; enabled explicitly only AFTER a successful manual read.
-- No native macro calls on frames other than the elapsed refresh interval.
local function maybe_auto_refresh()
    if not state.autoRefresh or state.phase < 4 then return; end
    local now=os.time();
    if now < state.refreshAt then return; end
    state.refreshAt=now+state.refreshInterval;
    state.confirmAll=true;
    read_all_names();
    if state.phase < 4 or #state.names ~= 20 then
        state.autoRefresh=false;
        state.changeSummary='Auto refresh stopped: failed to read native names.';
    end
end
-- Safely gated native executor experiment, ONLY CTRL slot 1.
-- Upstream run() uses controller object, modifier 1, index 0.
local function try_ctrl1()
    if not state.clickConsent or state.phase < 4 or #state.names ~= 20 then return; end
    state.clickConsent=false;
    if not validaddr(state.addresses.controller) or not validaddr(state.addresses.run) then
        state.clickSummary='BLOCKED: missing native execution signatures'; return;
    end
    if state.names[1]=='' then state.clickSummary='BLOCKED: CTRL+1 has no displayed name'; return; end
    local mem=ashita and ashita.memory;
    local ok,ptr=pcall(function() return mem.read_uint32(state.addresses.controller); end);
    if not ok or not validaddr(ptr) or ptr%4~=0 then
        state.clickSummary='BLOCKED: invalid controller global'; return;
    end
    local ok2,controller=pcall(function() return mem.read_uint32(ptr); end);
    if not ok2 or not validaddr(controller) or controller%4~=0 then
        state.clickSummary='BLOCKED: invalid controller pointer'; return;
    end
    -- Native calls can crash process; pcall only catches Lua errors.
    local ok3,err=pcall(function()
        ffi.cast('Decker_FsMacroContainer_runMacro_f',state.addresses.run)(controller,1,0);
    end);
    state.clickSummary=ok3 and ('CTRL+1 launch requested ('..state.names[1]..'); verify in game.') or ('Lua error: '..tostring(err));
    say(state.clickSummary);
end

-- Native-inspired display: macro name on top, modifier label on its own line.
-- The native name limit is eight bytes, so no UI truncation is required at the default width.
-- Use a separate diagnostic window; no game HUD hooks or memory writes are performed.
local function flash_slot(row,slot)
    state.flashRow=row; state.flashSlot=slot; state.flashUntil=os.clock()+0.30;
end
local function record_execution(row,slot,source)
    state.navRow=row; state.navSlot=slot; state.navSource=source;
    state.lastExecuted={row=row,slot=slot,name=state.names[(row=='CTRL' and 0 or 10)+slot] or '',set=state.trackedSet};
    flash_slot(row,slot);
end
local function execute_slot(row,slot)
    if not state.allowAllClicks then
        if row=='CTRL' and slot==1 and state.clickConsent then try_ctrl1();
        else state.clickSummary='BLOCKED: mouse execution not ready; scan, validate and read names first.'; end
        return;
    end
    if state.phase < 4 or #state.names ~= 20 then state.clickSummary='BLOCKED: macro names not loaded'; return; end
    if not validaddr(state.addresses.controller) or not validaddr(state.addresses.run) then
        state.clickSummary='BLOCKED: native execute signature unavailable'; return;
    end
    local idx=(row=='CTRL' and 0 or 10)+(slot-1);
    local name=state.names[idx+1] or '';
    if name=='' then state.clickSummary='Empty macro slot: no action'; return; end
    local mem=ashita and ashita.memory;
    if not mem then state.clickSummary='BLOCKED: memory API unavailable'; return; end
    local ok,ptr=pcall(function() return mem.read_uint32(state.addresses.controller); end);
    local ok2,controller=false,nil;
    if ok and validaddr(ptr) and ptr%4==0 then
        ok2,controller=pcall(function() return mem.read_uint32(ptr); end);
    end
    if not ok2 or not validaddr(controller) or controller%4~=0 then
        state.clickSummary='BLOCKED: controller pointer invalid'; state.allowAllClicks=false; return;
    end
    -- Per Ashita macro library: CTRL=1, ALT=2, each with zero-based slot 0..9.
    -- Explicit opt-in; neither modifies macros nor patches the original HUD.
    local modifier=(row=='CTRL' and 1 or 2);
    local called,err=pcall(function()
        ffi.cast('Decker_FsMacroContainer_runMacro_f',state.addresses.run)(controller,modifier,slot-1);
    end);
    if called then record_execution(row,slot,'executed'); end
    state.clickSummary=called and (row..'+'..tostring(slot==10 and 0 or slot)..' requested ('..name..')') or ('Lua error: '..tostring(err));
    say(state.clickSummary);
    return called;
end

-- Single validated command only: no Lua, script runners, command chaining or chat.
local function valid_command(command)
    if type(command)~='string' or #command>240 or command:find('[%c;|]') then return false; end
    if command:match('^/equipset %d+$') then local n=tonumber(command:match('%d+')); return n>=1 and n<=100; end
    if command:match('^/lac set [%w_%-]+$') then return true; end
    if command:match('^/item "[^"<>]+" <me>$') or command:match('^/ma "[^"<>]+" <me>$') or command:match('^/ja "[^"<>]+" <me>$') or command:match('^/mount "[^"<>]+"$') then return true; end
    return false;
end
local function request_statebar(i)
    local b=state.statebarSlots[i]; if not b or not state.profileReady then return false; end
    local requested=false;
    if b.source=='command' then
        if not state.allowAllClicks or not valid_command(b.command) then state.clickSummary='StateBar command blocked: connect and use a supported single command.'; return false; end
        local ok,result=pcall(function() return AshitaCore:GetChatManager():QueueCommand(-1,b.command); end); requested=ok and result~=false;
    else requested=execute_slot(b.row,b.slot); end
    if requested and b.kind~='utility' then state.statebarSelected=i; save_display(); end
    return requested;
end
local function restore_section(section)
    for _,key in ipairs(sectionKeys[section] or {}) do state[key]=copy_value(profileDefaults[key]); end
    if section=='Appearance' then state.hudPos=nil; end
    state.held={}; state.navQueue={}; state.deferredNav={}; state.navToggleActive=false;
    save_display();
end

-- Visual theme selection changes macro-name emphasis using a compact native-style label.
-- Single user-initiated connection path; retains the same validated upstream calls.
-- Native FFI reading may crash a mismatched game client; never run automatically on startup.
local function connect_macros()
    state.keybinds=false;
    state.navToggleActive=false;
    scan();
    if state.phase<1 then return; end
    pointer_check();
    if state.phase<2 then return; end
    state.confirmAll=true;
    read_all_names();
    if state.phase==4 and #state.names==20 then
        state.allowSwitch=validaddr(state.addresses.set_page);
        state.autoRefresh=true;
        state.refreshAt=os.time()+3;
        state.clickSummary=state.allowAllClicks and 'Mouse execution ready' or 'Mouse execution not available';
        -- Restore deliberate preferences only after native connection succeeds.
        state.acknowledgeKeys=state.savedAck;
        state.keybinds=state.savedKeybinds and state.acknowledgeKeys and state.allowAllClicks;
        state.navKeysEnabled=state.savedNavEnabled;
        state.navToggleActive=false;
    end
end
-- Display-only glass renderer. Native buttons retain hit testing, IDs and execution.
-- No font atlas mutation in d3d_present; load a bounded set once in the load event.
local glass={fonts={},diagnostic='Default font; awaiting load',custom=true};
local fontFiles={['Arial Bold']='arialbd.ttf',['Segoe UI Bold']='segoeuib.ttf',['Times New Roman Bold']='timesbd.ttf'};
local function load_glass_fonts()
    if type(imgui.AddFontFromFileTTF)~='function' then glass.diagnostic='Custom fonts unavailable; using host default'; return; end
    local root=os.getenv('WINDIR') or 'C:\\Windows';
    for name,file in pairs(fontFiles) do
        local path=root..'\\Fonts\\'..file;
        local f=io.open(path,'rb');
        if f then
            f:close(); local ok,font=pcall(imgui.AddFontFromFileTTF,path,20);
            if ok and font then glass.fonts[name]=font; end
        end
    end
    glass.diagnostic=glass.fonts['Arial Bold'] and 'Arial Bold ready' or 'Arial Bold unavailable; using host default';
end
local function pair(a,b)
    if type(a)=='number' then return a,b; end
    if a then
        local ok,x,y=pcall(function() return a[1] or a.x,a[2] or a.y; end);
        if ok and type(x)=='number' and type(y)=='number' then return x,y; end
        ok,x,y=pcall(function() return a.x,a.y; end);
        if ok and type(x)=='number' and type(y)=='number' then return x,y; end
    end
end
local function push_glass_background(opacity)
    local n,v=0,0;
    if imgui.PushStyleColor and imgui.PopStyleColor then
        for _,entry in ipairs({{ImGuiCol_WindowBg,{0,0,0,opacity}},{ImGuiCol_Border,{0,0,0,0}}}) do
            if type(entry[1])=='number' then imgui.PushStyleColor(entry[1],entry[2]); n=n+1; end
        end
    end
    if imgui.PushStyleVar and imgui.PopStyleVar then
        for _,id in pairs({ImGuiStyleVar_WindowBorderSize,ImGuiStyleVar_FrameBorderSize}) do
            if type(id)=='number' then imgui.PushStyleVar(id,0); v=v+1; end
        end
    end
    return n,v;
end
local function pop_glass_background(n,v)
    if n>0 then imgui.PopStyleColor(n); end
    for i=1,v do imgui.PopStyleVar(); end
end
local function glass_available()
    for _,name in ipairs({'GetWindowDrawList','GetCursorScreenPos','GetFont','CalcTextSize','GetTextLineHeight','PushFont','PopFont','GetColorU32'}) do
        if type(imgui[name])~='function' then return false; end
    end
    return glass.custom;
end
local function draw_glass_text(dl,text,x,y,w,h,shortcut,cooling)
    local font=glass.fonts[state.macroFont] or imgui.GetFont();
    imgui.PushFont(font);
    local ok,err=pcall(function()
        local natural=imgui.GetTextLineHeight();
        local function width(t,size)
            local tw=pair(imgui.CalcTextSize(t)); return (tw or 0)*size/natural;
        end
        local size=math.min(state.macroFontSize*state.scale,math.max(10,h-18));
        local shown=text;
        if width(shown,size)>w-10 then size=math.max(10,math.min(size,(w-10)/math.max(1,width(shown,1)))); end
        while #shown>0 and width(shown,size)>w-10 do
            -- Native macro names are byte strings. Do not split UTF-8 continuation bytes.
            shown=shown:match('^(.*)[%z\1-\127\194-\244][\128-\191]*$') or '';
        end
        if shown~=text then
            while #shown>0 and width(shown..'...',size)>w-10 do shown=shown:match('^(.*)[%z\1-\127\194-\244][\128-\191]*$') or ''; end
            shown=shown..'...';
        end
        local col=imgui.GetColorU32(cooling and {1,.30,.30,1} or {.96,.96,.97,1});
        local tx=x+(w-width(shown,size))/2; local ty=y+math.max(2,(h-12-size)/2);
        dl:AddText(font,size,{tx+1,ty+1},imgui.GetColorU32({0,0,0,1}),shown);
        dl:AddText(font,size,{tx,ty},col,shown);
        local ks=math.min(10*state.scale,math.max(7,h/4));
        dl:AddText(font,ks,{x+w-width(shortcut,ks)-5,y+h-ks-3},imgui.GetColorU32({.68,.70,.74,1}),shortcut);
    end);
    imgui.PopFont();
    if not ok then error(err); end
end
local function draw_row(title,offset)
    local w=math.floor(state.hudWidth*state.scale);
    local h=math.floor(state.hudHeight*state.scale);
    if type(imgui.GetContentRegionAvail)=='function' then
        local ok,avail=pcall(imgui.GetContentRegionAvail);
        local aw=ok and pair(avail);
        if aw then w=math.max(42,math.floor((aw-36)/10)); end
    end
    for i=1,10 do
        if i>1 then imgui.SameLine(); end
        local name=state.names[offset+i] or '';
        local shortcut=state.mappingMode=='numbers' and tostring(i==10 and 0 or i)
            or state.mappingMode=='functions' and ('F'..i)
            or DIRECT_NAMES[state.directKeys[offset+i]] or '?';
        local flashing=state.flashRow==title and state.flashSlot==i and os.clock()<state.flashUntil;
        local e=state.lastExecuted;
        local remembered=e and e.row==title and e.slot==i and e.set==state.trackedSet and e.name==name and state.trackedSource~='unverified (same names)';
        local selected=state.navRow==title and state.navSlot==i;
        local cooling=cooldown_recast(state.cooldownBindings[offset+i]);
        local a=state.buttonOpacity;
        local accents={{.30,.22,.10,a},{.10,.23,.34,a},{.25,.15,.33,a},{.23,.25,.28,a}};
        local base=flashing and {.45,.34,.13,a} or remembered and (accents[state.theme] or accents[1]) or {.025,.028,.035,a};
        local nc,nv=0,0;
        local function colour(id,value) if type(id)=='number' and imgui.PushStyleColor and imgui.PopStyleColor then imgui.PushStyleColor(id,value); nc=nc+1; end end
        colour(ImGuiCol_Button,base);
        colour(ImGuiCol_ButtonHovered,{base[1]+.05,base[2]+.05,base[3]+.05,a});
        colour(ImGuiCol_ButtonActive,{.45,.34,.13,a});
        colour(ImGuiCol_Text,cooling and {1,.3,.3,1} or {.96,.96,.97,1});
        colour(ImGuiCol_Border,selected and {.85,.68,.30,1} or {0,0,0,0});
        if type(ImGuiStyleVar_FrameBorderSize)=='number' and imgui.PushStyleVar and imgui.PopStyleVar then
            imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize,selected and 1 or 0); nv=1;
        end
        local custom=glass_available();
        local x,y;
        if custom then x,y=pair(imgui.GetCursorScreenPos()); custom=x~=nil; end
        local label=custom and '' or (name..'\n'..shortcut);
        local clicked=imgui.Button(label..'##decker_'..title..i,{w,h});
        if nc>0 then imgui.PopStyleColor(nc); end
        if nv>0 then imgui.PopStyleVar(); end
        if custom then
            local ok,err=pcall(function()
                local dl=imgui.GetWindowDrawList();
                if dl.AddRectFilledMultiColor then
                    local top=imgui.GetColorU32({1,1,1,.035*a}); local bottom=imgui.GetColorU32({0,0,0,.05*a});
                    dl:AddRectFilledMultiColor({x+2,y+2},{x+w-2,y+h-2},top,top,bottom,bottom);
                end
                if selected then dl:AddRect({x+1,y+1},{x+w-1,y+h-1},imgui.GetColorU32({.85,.68,.30,1}),2,0,1); end
                draw_glass_text(dl,name,x,y,w,h,shortcut,cooling);
            end);
            if not ok then glass.custom=false; glass.diagnostic='Host draw API fallback: '..tostring(err); end
        end
        if imgui.IsItemHovered and imgui.SetTooltip and imgui.IsItemHovered() and name~='' then imgui.SetTooltip('%s',name); end
        if clicked then execute_slot(title,i); end
    end
end
-- Draw the panel behind the two rows without introducing a child window or changing layout.
local function draw_macro_panel()
    if not glass_available() then return; end
    pcall(function()
        local x,y=pair(imgui.GetCursorScreenPos()); local aw=pair(imgui.GetContentRegionAvail());
        if x and aw then imgui.GetWindowDrawList():AddRectFilled({x-2,y-2},{x+aw,y+state.hudHeight*state.scale*2+6},imgui.GetColorU32({0,0,0,state.panelOpacity}),2); end
    end);
end
-- DirectInput scancodes: 1..0 (2..11) and F1..F10 (59..68).
-- Keyboard overrides remain OFF until explicit activation. Native FFXI chat/edit focus
-- cannot yet be identified reliably in VanaCore. Warn in UI before enabling.
local function mapped_key(key)
    if type(key)~='number' then return nil,nil; end
    if state.mappingMode~='split' then
        if direct_conflict(key,0) then return nil,nil; end
        local start=state.mappingMode=='numbers' and 2 or 59;
        for i=1,10 do if key==(state.mappingMode=='numbers' and (i==10 and 11 or i+1) or 58+i) then return state.navRow or 'CTRL',i; end end
        return nil,nil;
    end
    for i,code in ipairs(state.directKeys) do
        if code~=0 and code==key and not direct_conflict(code,i) then
            return i<=10 and 'CTRL' or 'ALT',i<=10 and i or i-10;
        end
    end
    return nil,nil;
end
local function shortcuts_active()
    return state.keybinds and state.acknowledgeKeys and state.allowAllClicks
        and state.phase>=4 and #state.names==20;
end
-- Keep keyboard macro routing and FFXI's native modifier combinations separate.
local function modifier_down()
    return state.held[29] or state.held[157] or state.held[56] or state.held[184]
        or state.held[42] or state.held[54];
end
-- Dedicated navigation modifiers. Right Shift is the default.
-- When navigation is enabled the chosen modifier is reserved exclusively for
-- Decker (including its held state) so FFXI cannot also switch its own bar.
-- Navigation remains opt-in, because reserving Shift affects normal Shift use.
local NAV_KEYS={RSHIFT=54,LSHIFT=42,END=207,HOME=199};
local function nav_scan() return NAV_KEYS[state.navModifier] or 54; end
local function other_modifier_down()
    for _,key in ipairs({29,157,56,184,42,54}) do
        if key~=nav_scan() and state.held[key] then return true; end
    end
    return false;
end
local function navigate_once(key)
    if state.phase<4 or not state.allowSwitch then return; end
    local page=state.trackedSet or 1;
    state.setRequestSource='keyboard';
    select_page(((page-1+(key==200 and -1 or 1))%10)+1);
end
-- Navigation is Decker-owned; the game never receives a synthetic held Shift.
-- In sticky mode tap the modifier once to arm arrows/space/enter, again to exit.
-- In hold mode arrows/space/enter apply only while the modifier is held.
local ROW_KEYS={END=207,HOME=199,INSERT=210,DELETE=211,N=49,F9=67,F10=68,F11=87,F12=88};
local function row_key() return ROW_KEYS[state.rowSwitchKey] or 207; end
local NAV_ACTIONS={ [200]=true,[208]=true,[203]=true,[205]=true,[57]=true,[28]=true,[156]=true };
local function nav_is_active()
    return state.navKeysEnabled
       and (state.stickyNavigation and state.navToggleActive or
           (not state.stickyNavigation and state.navModifierHeld))
       and not other_modifier_down();
end
local function nav_clear()
    state.navToggleActive=false;
    state.navModifierHeld=false;
    state.navCaptured={};
    state.navPressed={};
    state.navPhysicalDown=false;
    state.navPhysicalKeys={}; state.navQueue={}; state.deferredNav={}; state.navSetVerifyFrames=0; state.navSetExpectedFingerprint=nil;
end
-- Navigation is queued and run from the UI frame. Set changes are deferred
-- a few frames so native input state can settle before calling set_page.
local function nav_command(key)
    state.hudLastActivity=os.clock();
    if key==200 or key==208 then
        state.deferredNav=state.deferredNav or {};
        state.deferredNav[#state.deferredNav+1]={key=key,frames=4};
    elseif key==57 or key==row_key() then
        state.navRow=(state.navRow=='CTRL') and 'ALT' or 'CTRL';
        state.navSource='Decker navigation';
    elseif key==203 or key==205 then
        state.navSlot=((state.navSlot or 1)-1+(key==203 and -1 or 1))%10+1;
        state.navSource='Decker navigation';
    elseif key==28 or key==156 then
        execute_slot(state.navRow or 'CTRL',state.navSlot or 1);
        -- Navigation ends only by modifier toggle or physical modifier release.
    end
end
-- key_data only suppresses input. Physical key edges are processed from
-- key_state once, preventing inconsistent arrow events on VanaCore.
ashita.events.register('key_data','decker_custom_set_navigation',function(e)
    if not state.navKeysEnabled then return; end
    if e.key==nav_scan() then
        e.blocked=true;
        return;
    end
    if not NAV_ACTIONS[e.key] and e.key~=row_key() then return; end
    if nav_is_active() or state.navCaptured[e.key] then
        e.blocked=true;
        -- Some clients deliver the first arrow press through key_data before
        -- key_state has populated its physical-edge cache. Capture that edge
        -- here so navigation works before clicking any macro or focusing HUD.
        if e.down and not state.navCaptured[e.key] then
            state.navCaptured[e.key]=true;
            state.navQueue[#state.navQueue+1]=e.key;
            state.hudLastActivity=os.clock();
        elseif not e.down then
            state.navCaptured[e.key]=nil;
            state.navPhysicalKeys[e.key]=false;
        end
    end
end);
ashita.events.register('key_state','decker_custom_set_state',function(e)
    if not e.data_raw or (type(e.size)=='number' and e.size<256) then return; end
    local ptr=ffi.cast('uint8_t*',e.data_raw);
    local modifier=nav_scan();
    local physicalDown=ptr[modifier]~=0;
    if state.navKeysEnabled and state.stickyNavigation
            and physicalDown and not state.navPhysicalDown and not other_modifier_down() then
        state.navToggleActive=not state.navToggleActive; state.hudLastActivity=os.clock(); state.hudForceReveal=true;
        if state.echoLock then print(chat.header(addon.name)..(state.navToggleActive and 'Navigation LOCKED' or 'Navigation UNLOCKED')); end
    end
    if state.navKeysEnabled and physicalDown and not state.navPhysicalDown then
        -- A modifier press must always be able to wake the HUD, even before macro pointers connect.
        state.hudLastActivity=os.clock(); state.hudHasInteracted=true; state.hudForceReveal=true;
    end
    state.navPhysicalDown=physicalDown;
    state.navModifierHeld=physicalDown;
    local active=state.navKeysEnabled
        and (state.stickyNavigation and state.navToggleActive or
             (not state.stickyNavigation and physicalDown))
        and not other_modifier_down();
    if state.navKeysEnabled then ptr[modifier]=0; end
    local activeKeys={}; for key,_ in pairs(NAV_ACTIONS) do activeKeys[key]=true; end; activeKeys[row_key()]=true;
    for key,_ in pairs(activeKeys) do
        local wasDown=state.navPhysicalKeys[key] or false;
        local nowDown=ptr[key]~=0;
        -- Captured keys remain blocked until physically released.
        if active and nowDown and not wasDown and not state.navCaptured[key] then
            state.navCaptured[key]=true;
            state.navQueue[#state.navQueue+1]=key; state.hudLastActivity=os.clock();
        end
        state.navPhysicalKeys[key]=nowDown;
        if not nowDown then state.navCaptured[key]=nil; state.navPressed[key]=nil; end
        if (active or state.navCaptured[key]) and nowDown then ptr[key]=0; end
    end
end);
-- Use native ALT/CTRL + up/down for set selection, refresh the on-screen names
-- after the game's own input handler has processed the press. No arrow blocking.
ashita.events.register('key_data','decker_native_arrow_watch',function(e)
    if e.key==29 or e.key==157 or e.key==56 or e.key==184 or e.key==42 or e.key==54 then
        state.held[e.key]=e.down and true or nil;
    end
    if not e.blocked and (e.key==200 or e.key==208) and e.down and modifier_down() and not (state.navKeysEnabled and (state.navModifierHeld or state.navToggleActive))
        and state.phase>=4 and #state.names==20 then
        state.pendingRefreshFrames=3;
        state.nativeArrowRefreshes=state.nativeArrowRefreshes+1;
        -- Native arrow navigation is allowed through. A known Decker-requested set
        -- gives us a tracking anchor, but is NOT an independently verified getter.
        if state.trackedSet then
            local delta=(e.key==200) and -1 or 1;
            state.trackedSet=((state.trackedSet-1+delta)%10)+1;
            state.trackedSource='estimated';
            save_display();
        end

    end
end);
-- Native left/right may repeat more quickly than Lua input notifications.
-- Do not claim an authoritative selection cursor without a verified game getter.
ashita.events.register('key_data','decker_native_horizontal_watch',function(e)
    if e.key~=203 and e.key~=205 then return; end
    if e.down and modifier_down() and state.phase>=4
        and not (state.navKeysEnabled and (state.navModifierHeld or state.navToggleActive)) then
        state.navSlot=nil;
        state.navRow=nil;
        state.navSource='Native selection unverified';
    end
end);
-- StateBar hotkeys are independent of the main HUD mapping. Only intercept when
-- the player has opted into keyboard overrides; reject collisions with main keys.
local function statebar_hotkey_slot(code)
    if not state.statebarEnabled or not state.statebarHotkeysEnabled or not state.keybinds or not state.acknowledgeKeys then return nil; end
    if not shortcuts_active() or modifier_down() then return nil; end
    if mapped_key(code) then return nil; end
    if state.navKeysEnabled and (code==nav_scan() or code==row_key() or NAV_ACTIONS[code]) then return nil; end
    local found=nil;
    for i=1,#state.statebarSlots do if state.statebarHotkeys[i]==code and code~=0 then if found then return nil; end; found=i; end end
    return found;
end
ashita.events.register('key_data','decker_statebar_key_press',function(e)
    local i=statebar_hotkey_slot(e.key);
    if not i or e.blocked then return; end
    if state.suppressed[e.key] then
        e.blocked=true;
        if not e.down then state.suppressed[e.key]=nil; state.held[e.key]=nil; end
        return;
    end
    if e.down then
        e.blocked=true;
        if not state.held[e.key] then
            state.held[e.key]=true; state.suppressed[e.key]=true;
            local b=state.statebarSlots[i];
            if b then request_statebar(i); end
        end
    end
end);
ashita.events.register('key_data','decker_exclusive_key_press',function(e)
    local row,slot=mapped_key(e.key);
    if not row and not state.suppressed[e.key] then return; end
    -- Always finish suppressing a key-release corresponding to a captured press.
    if state.suppressed[e.key] then
        e.blocked=true;
        if not e.down then
            state.suppressed[e.key]=nil;
            state.held[e.key]=nil;
        end
        return;
    end
    if not row or not shortcuts_active() or e.blocked or modifier_down() then return; end
    if e.down then
        if not state.held[e.key] then
            state.held[e.key]=true;
            state.suppressed[e.key]=true;
            e.blocked=true;
            execute_slot(row,slot);
        else
            e.blocked=true;
        end
    end
end);
-- Ashita separates initial DirectInput press (key_data) and held state
-- (key_state). Both must be suppressed to avoid native double execution.
ashita.events.register('key_state','decker_exclusive_key_state',function(e)
    if not e.data_raw then return; end
    if not shortcuts_active() and next(state.suppressed)==nil then return; end
    local ptr=ffi.cast('uint8_t*',e.data_raw);
    local size=type(e.size)=='number' and e.size or 256;
    local keys={};
    if state.mappingMode=='split' then
        for _,code in ipairs(state.directKeys) do if code>0 then keys[code]=true; end end
    else
        for i=1,10 do keys[state.mappingMode=='numbers' and (i==10 and 11 or i+1) or 58+i]=true; end
    end
    for code,_ in pairs(state.suppressed) do keys[code]=true; end
    for code,_ in pairs(keys) do
        if code<size and (state.suppressed[code] or (shortcuts_active() and not modifier_down() and mapped_key(code)~=nil)) then ptr[code]=0; end
    end
end);
ashita.events.register('load','decker_load',function() load_glass_fonts(); say('Decker v'..addon.version..' loaded',false); end);
ashita.events.register('command','decker_cmd',function(e)
    local a=e.command:args(); if not a[1] or a[1]:lower()~='/decker' then return; end
    e.blocked=true;
    local cmd=(a[2] or 'show'):lower();
    if cmd=='debug' then
        local v=(a[3] or ''):lower();
        if v=='on' then state.debugLog=true; say('Debug logging enabled.',true)
        elseif v=='off' then state.debugLog=false; say('Debug logging disabled.',true)
        else say('Debug is '..(state.debugLog and 'ON' or 'OFF')..'. Use /decker debug on|off',true); end
    elseif cmd=='book' then
        local n=tonumber(a[3]);
        if n and n==math.floor(n) and n>=1 and n<=40 then
            state.manualBook=n; save_display(); say(('Book display manually set to %02d (not read from game).'):format(n));
        else
            state.manualBook=1; save_display(); say('Book label reset to 01 (default, not verified).');
        end
    elseif cmd=='setlabel' then
        local n=tonumber(a[3]);
        if n and n==math.floor(n) and n>=1 and n<=10 then
            state.trackedSet=n; state.trackedSource='manual'; save_display(); say(('Set display manually anchored to %d.'):format(n));
        else
            state.trackedSet=1; state.trackedSource='default (unverified)'; save_display(); say('Set label reset to 1 (default, not verified).');
        end
    elseif cmd=='resetbook' then reset_native_book()
    elseif cmd=='switchbook' then select_native_book(tonumber(a[3]))
    elseif cmd=='navon' then state.navKeysEnabled=true; state.savedNavEnabled=true; save_display(); say('Custom set navigation enabled.',true)
    elseif cmd=='navoff' then state.navKeysEnabled=false; state.savedNavEnabled=false; nav_clear(); save_display(); say('Custom set navigation disabled.',true)
    elseif cmd=='cooldown' then
        local row=(a[3] or ''):lower(); local slot=tonumber(a[4]);
        local kind=(a[5] or ''):lower(); local id=tonumber(a[6]);
        if (row=='ctrl' or row=='alt') and slot and slot>=1 and slot<=10 and slot==math.floor(slot) then
            local index=(row=='alt' and 10 or 0)+slot;
            if kind=='clear' then state.cooldownBindings[index]=nil; save_display(); say('Cooldown mapping cleared.',true);
            elseif (kind=='spell' or kind=='ability') and id and id>=0 and id==math.floor(id) then
                state.cooldownBindings[index]={kind=kind,id=id}; save_display(); say('Cooldown mapping saved for '..row..' '..slot,true);
            else say('Usage: /decker cooldown ctrl 1 spell 123 | ability TIMER_ID | clear',true); end
        else say('Usage: /decker cooldown ctrl|alt SLOT spell|ability ID',true); end
    elseif cmd=='settings' then state.showTests=not state.showTests
    elseif cmd=='connect' then connect_macros()
    elseif cmd=='scan' then scan()
    elseif cmd=='pointers' then pointer_check()
    elseif cmd=='show' then state.visible=true; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; state.hudForceReveal=true
    elseif cmd=='hide' then state.visible=false
    elseif cmd=='toggle' then state.visible=not state.visible; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; state.hudForceReveal=true
    elseif cmd=='keysoff' then state.keybinds=false; state.acknowledgeKeys=false; state.savedKeybinds=false; state.savedAck=false; save_display(); state.held={}; say('Keyboard overrides disabled; captured keys release on key-up.')
    else say('/decker connect | debug on|off | show | hide | keysoff | book N | setlabel N',true); end
end);
-- Updater protocol 1 deliberately replaces only this single source file.
-- HTTPS/PowerShell runs in a separate process; the game thread only polls its exit code.
local updater={channel='development',status='Choose a channel, then check for updates.',job=nil,manifest=nil,installed=false}
local function updater_dir()
    local source=(debug.getinfo(1,'S') or {}).source or '';
    return source:sub(1,1)=='@' and source:sub(2):match('^(.*[\\/])') or nil;
end
local function update_read(path)
    local f=io.open(path,'rb'); if not f then return nil; end
    local bytes=f:read('*a'); f:close(); return bytes;
end
local function update_exists(path)
    local f=io.open(path,'rb'); if not f then return false; end; f:close(); return true;
end
local function update_write(path,bytes)
    local f=io.open(path,'wb'); if not f then return false; end
    local ok=f:write(bytes); local closed=f:close(); return ok~=nil and closed~=nil;
end
local function update_manifest(bytes)
    if type(bytes)~='string' or #bytes>1024 then return nil; end
    local m={}; for line in bytes:gmatch('[^\r\n]+') do
        local k,v=line:match('^(%w+)=(.+)$'); if not k or m[k] then return nil; end; m[k]=v;
    end
    if m.protocol~='1' or not m.version or not m.version:match('^%d+%.%d+%.%d+%-?[%w.]*$') or not m.commit or #m.commit~=40 or m.commit:find('[^%x]') or not m.sha256 or #m.sha256~=64 or m.sha256:find('[^%x]') then return nil; end
    return m;
end
local function update_newer(candidate,current)
    local function parts(v) local a,b,c=v:match('^(%d+)%.(%d+)%.(%d+)'); return {tonumber(a) or 0,tonumber(b) or 0,tonumber(c) or 0}; end
    local a,b=parts(candidate),parts(current);
    for i=1,3 do if a[i]~=b[i] then return a[i]>b[i]; end end
    -- A stable build can replace a development build of the same numeric version.
    return not candidate:find('-',1,true) and current:find('-',1,true)~=nil;
end
local update_script=[=[
param([ValidateSet('Check','Download')][string]$Mode,[ValidateSet('development','stable')][string]$Channel)
$ErrorActionPreference='Stop'
$dir=$PSScriptRoot
$status=Join-Path $dir '.decker-update-status.txt'
$meta=Join-Path $dir '.decker-update-manifest.txt'
$stage=Join-Path $dir '.decker-update-source.lua'
try {
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 Add-Type -AssemblyName System.Net.Http
 $client=New-Object System.Net.Http.HttpClient
 $client.Timeout=[TimeSpan]::FromSeconds(20)
 $client.MaxResponseContentBufferSize=1048576
 $client.DefaultRequestHeaders.UserAgent.ParseAdd('Decker-Updater/1')
 if($Mode -eq 'Check') {
  $branch=if($Channel -eq 'stable'){'main'}else{'dev/decker-v1.49.5-integration'}
  $url='https://raw.githubusercontent.com/danhughes381/FFXI-Decker/'+$branch+'/updates/'+$Channel+'.txt'
  $text=$client.GetStringAsync($url).GetAwaiter().GetResult()
 } else { $text=[IO.File]::ReadAllText($meta) }
 if($text.Length -gt 1024){throw 'Manifest too large'}
 $m=@{}
 foreach($line in ($text -split '\r?\n')) {
  if($line -eq ''){continue}
  if($line -notmatch '^(protocol|version|commit|sha256)=(.+)$'){throw 'Invalid manifest'}
  if($m.ContainsKey($Matches[1])){throw 'Duplicate manifest field'}
  $m[$Matches[1]]=$Matches[2]
 }
 if($m.Count -ne 4 -or $m.protocol -ne '1' -or $m.version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.]+)?$' -or $m.commit -notmatch '^[a-fA-F0-9]{40}$' -or $m.sha256 -notmatch '^[a-fA-F0-9]{64}$'){throw 'Unsupported manifest'}
 if($Mode -eq 'Check') { [IO.File]::WriteAllText($meta,$text,[Text.Encoding]::ASCII) }
 else {
  $url='https://raw.githubusercontent.com/danhughes381/FFXI-Decker/'+$m.commit+'/addons/decker/decker.lua'
  $bytes=$client.GetByteArrayAsync($url).GetAwaiter().GetResult()
  $hash=[Security.Cryptography.SHA256]::Create()
  $actual=([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-','').ToLowerInvariant()
  $hash.Dispose()
  if($actual -ne $m.sha256.ToLowerInvariant()){throw 'SHA-256 mismatch; nothing installed'}
  [IO.File]::WriteAllBytes($stage,$bytes)
 }
 $client.Dispose()
 [IO.File]::WriteAllText($status,'OK',[Text.Encoding]::ASCII)
 exit 0
} catch {
 [IO.File]::WriteAllText($status,('Update failed: '+$_.Exception.Message),[Text.Encoding]::ASCII)
 exit 1
}
]=]
local update_kernel=nil
local function update_windows()
    if ffi.os~='Windows' then return nil,'Updater requires Windows PowerShell; manual ZIP installation is available.'; end
    if update_kernel then return update_kernel; end
    local ok,result=pcall(function()
        ffi.cdef[[
        typedef struct { uint32_t cb; void* reserved; void* desktop; void* title; uint32_t x,y,xsize,ysize,xcount,ycount,fill,flags; uint16_t show,reservedSize; void* reservedBytes; void* input; void* output; void* error; } DeckerUpdateStartup;
        typedef struct { void* process; void* thread; uint32_t processId; uint32_t threadId; } DeckerUpdateProcess;
        int __stdcall CreateProcessW(const uint16_t*,uint16_t*,void*,void*,int,uint32_t,void*,const uint16_t*,DeckerUpdateStartup*,DeckerUpdateProcess*);
        int __stdcall GetExitCodeProcess(void*,uint32_t*);
        int __stdcall CloseHandle(void*);
        int __stdcall TerminateProcess(void*,unsigned int);
        int __stdcall MultiByteToWideChar(unsigned int,uint32_t,const char*,int,uint16_t*,int);
        ]];
        return ffi.load('kernel32');
    end);
    if not ok then return nil,'Windows updater API unavailable: '..tostring(result); end
    update_kernel=result; return result;
end
local function update_wide(k,text)
    local n=k.MultiByteToWideChar(65001,8,text,#text,nil,0); if n==0 then return nil; end
    local w=ffi.new('uint16_t[?]',n+1); if k.MultiByteToWideChar(65001,8,text,#text,w,n)==0 then return nil; end; return w;
end
local function update_start(mode)
    if updater.job or updater.installed then return; end
    local k,why=update_windows(); if not k then updater.status=why; return; end
    local dir=updater_dir(); if not dir then updater.status='Cannot locate Decker folder.'; return; end
    local script=dir..'.decker-update.ps1';
    if script:find('["%c]') then updater.status='Unsupported installation path.'; return; end
    if not update_write(script,update_script) then updater.status='Cannot write updater script; check folder permissions.'; return; end
    if mode=='Check' then updater.manifest=nil; os.remove(dir..'.decker-update-manifest.txt'); end
    os.remove(dir..'.decker-update-status.txt'); os.remove(dir..'.decker-update-source.lua');
    local system=os.getenv('SystemRoot') or 'C:\\Windows';
    if system:find('["%c]') then updater.status='Invalid Windows system path.'; return; end
    local exe=system..'\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';
    local command='"'..exe..'" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'..script..'" -Mode '..mode..' -Channel '..updater.channel;
    local app=update_wide(k,exe); local cmd=update_wide(k,command);
    if not app or not cmd then updater.status='Cannot encode Windows installation path.'; return; end
    local si=ffi.new('DeckerUpdateStartup[1]'); si[0].cb=ffi.sizeof('DeckerUpdateStartup');
    local pi=ffi.new('DeckerUpdateProcess[1]');
    if k.CreateProcessW(app,cmd,nil,nil,0,0x08000000,nil,nil,si,pi)==0 then updater.status='Cannot start Windows PowerShell. Manual install remains available.'; return; end
    k.CloseHandle(pi[0].thread);
    updater.job={handle=pi[0].process,mode=mode,started=os.time(),pollAt=0};
    updater.status=mode=='Check' and 'Checking for updates...' or 'Downloading and verifying update...';
end
local function update_promote(path)
    local dir=updater_dir(); if not dir then return false,'Cannot locate Decker folder.'; end
    local bytes=update_read(path);
    if not bytes or #bytes<1000 or #bytes>1048576 then return false,'Invalid update size.'; end
    local version=bytes:match("addon%.version%s*=%s*'([^']+)'");
    if not version then return false,'Missing Decker version.'; end
    local compiled,why=loadstring(bytes,'@'..dir..'decker.lua');
    if not compiled then return false,'LuaJIT syntax rejected: '..tostring(why); end
    local staged=dir..'.decker-install.lua';
    if not update_write(staged,bytes) then return false,'Cannot stage update.'; end
    local live=dir..'decker.lua'; local backup=dir..'decker.lua.bak';
    if update_read(backup) and not os.remove(backup) then os.remove(staged); return false,'Cannot replace previous backup.'; end
    if not os.rename(live,backup) then os.remove(staged); return false,'Cannot back up current Decker; nothing installed.'; end
    if not os.rename(staged,live) then
        local restored=os.rename(backup,live); os.remove(staged);
        return false,restored and 'Install failed; original restored.' or 'Install and restore failed. Restore decker.lua.bak manually before reloading.';
    end
    return true,version;
end
local function update_reload()
    save_display(); state.keybinds=false; state.navKeysEnabled=false; state.navToggleActive=false; state.navQueue={}; state.deferredNav={};
    local ok,result=pcall(function() return AshitaCore:GetChatManager():QueueCommand(-1,'/addon reload decker'); end);
    if not ok or result==false then updater.status='Installed. Run /addon reload decker to activate.'; end
end
local function update_poll()
    local job=updater.job; if not job or os.time()<job.pollAt then return; end; job.pollAt=os.time()+1;
    local k=update_kernel; local exit=ffi.new('uint32_t[1]');
    if k.GetExitCodeProcess(job.handle,exit)==0 then k.TerminateProcess(job.handle,1); k.CloseHandle(job.handle); updater.job=nil; updater.status='Cannot read updater process status; nothing installed.'; return; end
    if exit[0]==259 then
        if os.time()-job.started>45 then k.TerminateProcess(job.handle,1); k.CloseHandle(job.handle); updater.job=nil; updater.status='Update timed out; nothing installed.'; end
        return;
    end
    k.CloseHandle(job.handle); updater.job=nil;
    local dir=updater_dir();
    if exit[0]~=0 then updater.status=(update_read(dir..'.decker-update-status.txt') or 'PowerShell failed; check Windows permissions and network.'):sub(1,300); return; end
    local manifest=update_manifest(update_read(dir..'.decker-update-manifest.txt'));
    if not manifest then updater.status='Invalid update manifest; nothing installed.'; return; end
    if job.mode=='Check' then
        updater.manifest=manifest;
        updater.status=update_newer(manifest.version,addon.version) and ('Available: v'..manifest.version) or 'No newer version on this channel.';
        return;
    end
    if not updater.manifest or manifest.commit~=updater.manifest.commit or manifest.sha256~=updater.manifest.sha256 or manifest.version~=updater.manifest.version then updater.status='Manifest changed; check for updates again.'; return; end
    local path=dir..'.decker-update-source.lua'; local bytes=update_read(path) or '';
    if bytes:match("addon%.version%s*=%s*'([^']+)'")~=manifest.version then updater.status='Source version mismatch; nothing installed.'; return; end
    local ok,detail=update_promote(path);
    if not ok then updater.status=detail; return; end
    updater.installed=true; updater.status='Installed v'..detail..'; reloading Decker...'; update_reload();
end
local function update_rollback()
    if updater.job or updater.installed then return; end
    local dir=updater_dir(); if not dir then return; end
    local ok,detail=update_promote(dir..'decker.lua.bak');
    if not ok then updater.status=detail; return; end
    updater.installed=true; updater.status='Restored v'..detail..'; reloading Decker...'; update_reload();
end
ashita.events.register('unload','decker_updater_cleanup',function()
    if updater.job and update_kernel then update_kernel.TerminateProcess(updater.job.handle,1); update_kernel.CloseHandle(updater.job.handle); updater.job=nil; end
end);

ashita.events.register('d3d_present','decker_draw',function()
    update_poll();
    if os.clock()-state.lastProfileCheck>1 then state.lastProfileCheck=os.clock(); refresh_profile(); end
    if #state.navQueue>0 then
        -- Consume input transitions once per frame, in order.  Limit queued
        -- set changes while a native request is unresolved; never advance
        -- trackedSet repeatedly against an unverified game state.
        local queue=state.navQueue; state.navQueue={};
        for _,key in ipairs(queue) do
            if key==200 or key==208 then
                if not state.deferredNav or #state.deferredNav==0 then
                    nav_command(key);
                elseif state.debugLog then
                    say('TRACE navigation: extra set request ignored while prior request is pending');
                end
            else
                nav_command(key);
            end
        end
    end
    -- Execute navigation on a later UI frame, after input handling has settled.
    if state.deferredNav and #state.deferredNav>0 then
        local item=state.deferredNav[1]; item.frames=item.frames-1;
        if item.frames<=0 then
            table.remove(state.deferredNav,1);
            if not state.navKeysEnabled or state.phase<4 then
                if state.debugLog then say('TRACE navigation: queued set request cancelled; navigation unavailable'); end
            else
                navigate_once(item.key);
            end
            -- Refresh repeatedly over the next frames because native macro data
            -- may not be ready on the same frame as a set-page request.
            state.navSetVerifyFrames=18;
        end
    end
    if state.navSetVerifyFrames and state.navSetVerifyFrames>0 then
        state.navSetVerifyFrames=state.navSetVerifyFrames-1;
        if state.tracePending then state.tracePending.frames=18-state.navSetVerifyFrames; end;
        if state.navSetVerifyFrames==17 or state.navSetVerifyFrames==15 or state.navSetVerifyFrames==1 then
            if state.phase>=4 and #state.names==20 then
                state.confirmAll=true; read_all_names();
            end
        end
    end
    -- Keeps scans out of the rendering loop; auto mode is enabled only by user.
    if state.pendingRefreshFrames>0 then
        state.pendingRefreshFrames=state.pendingRefreshFrames-1;
        if state.pendingRefreshFrames==0 and state.phase>=4 and #state.names==20 then
            state.confirmAll=true;
            read_all_names();
        end
    end
    maybe_auto_refresh();
    if state.statebarEnabled and (state.statebarVisibility=='always' or (state.statebarVisibility=='navigation' and (state.navToggleActive or state.navModifierHeld)) or (state.statebarVisibility=='manual' and state.statebarAlways) or state.showTests) then
        local flags=state.statebarLocked and 4 or 0; -- ImGui NoMove, verified numeric constant
        local count=#state.statebarSlots;
        if count>0 then
            local sw=math.floor(100*state.statebarScale);
            local width=state.statebarVertical and (sw+32) or (count*(sw+5)+18);
            local height=state.statebarVertical and (count*36*state.statebarScale+50) or 85;
            imgui.SetNextWindowSize({width,height},ImGuiCond_FirstUseEver);
            local barColours,barVars=push_glass_background(state.statebarOpacity);
            if imgui.Begin('StateBar###DeckerStateBar',nil,flags+1) then
                for i,b in ipairs(state.statebarSlots) do
                    local idx=(b.row=='ALT' and 10 or 0)+b.slot;
                    local name=b.label and b.label~='' and b.label or b.source=='command' and (b.command or 'Configure command') or (state.names[idx] or 'Unassigned');
                    local key=b.source=='command' and (b.kind or 'state') or b.row..' '..tostring(b.slot==10 and 0 or b.slot);
                    if i>1 and not state.statebarVertical then imgui.SameLine(); end
                    -- StateBar selection is independent from the main macro HUD's press highlight.
                    -- Keep the actual macro name legible; never prefix it with SELECTED.
                    local sbSelected=(b.kind~='utility' and state.statebarSelected==i);
                    local sbColours=type(imgui.PushStyleColor)=='function' and type(imgui.PopStyleColor)=='function' and type(ImGuiCol_Button)=='number' and type(ImGuiCol_ButtonHovered)=='number' and type(ImGuiCol_ButtonActive)=='number';
                    if sbColours then
                        local colours={{0.12,0.57,0.28,1},{0.12,0.40,0.70,1},{0.50,0.25,0.65,1},{0.40,0.40,0.40,1}};
                        imgui.PushStyleColor(ImGuiCol_Button,sbSelected and (colours[state.statebarTheme] or colours[1]) or {.025,.028,.035,state.buttonOpacity});
                        imgui.PushStyleColor(ImGuiCol_ButtonHovered,{0.17,0.68,0.34,1.0});
                        imgui.PushStyleColor(ImGuiCol_ButtonActive,{0.09,0.46,0.22,1.0});
                    end
                    local sbPressed=imgui.Button(name..'\n'..key..'##statebar'..i,{sw,math.floor(40*state.statebarScale)});
                    if sbColours then imgui.PopStyleColor(3); end
                    if sbPressed then
                        request_statebar(i);
                    end
                end
                if imgui.Button('Configure##statebarconfig') then state.showTests=true; state.settingsTab='StateBar'; end
            end
            imgui.End();
            pop_glass_background(barColours,barVars);
        end
    end
    if not state.visible then return; end
    local activeNav=state.navKeysEnabled and (state.stickyNavigation and state.navToggleActive or (not state.stickyNavigation and state.navModifierHeld));
    if activeNav and not state.hudWasActive then state.hudLastActivity=os.clock(); end
    state.hudWasActive=activeNav;
    -- Startup grace allows discovery; afterwards normal auto-hide applies even without clicks.
    -- The configured modifier and /decker show can always reveal the HUD.
    if not state.hudReadySince then state.hudReadySince=os.clock(); end
    local idleHidden=state.autoHide and not state.hudForceReveal and not activeNav and not state.showTests and (os.clock()-state.hudLastActivity)>=state.autoHideDelay and (os.clock()-state.hudReadySince)>=10;
    state.hudForceReveal=false;
    -- Never leave a loaded addon invisible without an on-screen recovery control.
    if idleHidden and state.autoHideMode=='hide' then state.autoHideMode='collapse'; end
    if idleHidden and state.autoHideMode=='collapse' then
        if imgui.Begin('Decker v'..addon.version..' - by Mutant X###DeckerCollapsed',nil,0) then
            if imgui.Button('Show Decker') then state.hudLastActivity=os.clock(); state.hudForceReveal=true; end
            imgui.SameLine(); if imgui.Button('Settings##collapsed') then state.showTests=true; state.hudLastActivity=os.clock(); end
        end
        imgui.End();
        return;
    end
    local hudw=math.floor(10*(state.hudWidth*state.scale+4)+32);
    imgui.SetNextWindowSize({hudw, math.floor(2*state.hudHeight*state.scale+96)},ImGuiCond_FirstUseEver);
    -- Do not restore saved HUD coordinates through an unverified VanaCore ImGui ABI.
    -- Apply to the HUD only; Settings stays fully opaque.
    local hudColours,hudVars=push_glass_background(state.outerOpacity);
    if imgui.Begin(('Decker v'..addon.version..' - Book%02d (#%d)%s###DeckerMain'):format(state.manualBook or 1,state.trackedSet or 1,(state.navKeysEnabled and (state.stickyNavigation and (state.navToggleActive and ' [LOCKED]' or ' [UNLOCKED]') or (state.navModifierHeld and ' [HELD]' or ' [RELEASED]')) or '')..(state.trackedSource=='unverified (same names)' and ' [UNVERIFIED]' or '')),nil,1+(state.positionLocked and 4 or 0)) then
        -- VanaCore ImGui positions may be math-backed vectors, not Lua arrays.
        -- Avoid numeric indexing of GetWindowPos results until its ABI is verified.

        imgui.Text(('DECKER  |  Book %d (#%d)%s'):format(state.manualBook or 1,state.trackedSet or 1,state.navKeysEnabled and (state.navToggleActive and '  LOCKED' or state.navModifierHeld and '  HELD' or '  UNLOCKED') or '')..(state.trackedSource=='unverified (same names)' and '  UNVERIFIED' or ''));
        if #state.names==20 then
            draw_macro_panel();
            draw_row('CTRL',0);
            draw_row('ALT',10);
            if state.allowSwitch then
                if imgui.Button('<##deckprev') then select_page(((state.trackedSet or 1)+8)%10+1); end
                imgui.SameLine(); imgui.Text(('Set %d/10'):format(state.trackedSet or 1));
                imgui.SameLine(); if imgui.Button('>##decknext') then select_page((state.trackedSet or 1)%10+1); end
                imgui.SameLine();
            end
            if imgui.Button(state.positionLocked and 'Unlock position' or 'Lock position') then state.positionLocked=not state.positionLocked; save_display(); end
            imgui.SameLine(); if imgui.Button('Settings') then state.showTests=not state.showTests; state.hudLastActivity=os.clock(); end
        else
            imgui.Text('Decker is not connected to native macros.');
            if imgui.Button('Connect macros') then connect_macros(); end
            imgui.SameLine();
            if imgui.Button(state.positionLocked and 'Unlock position' or 'Lock position') then state.positionLocked=not state.positionLocked; save_display(); end
            imgui.SameLine(); if imgui.Button('Settings') then state.showTests=not state.showTests; state.hudLastActivity=os.clock(); end
            imgui.TextWrapped('Connect invokes native FFXI reading functions. As with earlier builds, incompatible clients may crash.');
            if state.phase~=0 then imgui.TextWrapped(state.nameSummary..' / '..state.pointerSummary); end
        end
        if imgui.TextDisabled then imgui.TextDisabled('By Mutant X'); else imgui.Text('By Mutant X'); end
    end
    imgui.End();
    pop_glass_background(hudColours,hudVars);
    if state.showTests then
        imgui.SetNextWindowSize({490,370},ImGuiCond_FirstUseEver);
        if imgui.Begin('Decker v'..addon.version..' - Settings',nil,0) then
            if imgui.Button('X  Close Settings') then state.showTests=false; end
            imgui.Text('v'..addon.version..' | '..(state.profileId or 'Waiting for login'));
            imgui.Separator();
            -- Four user-facing sections; technical pages live under More.
            local currentTab=state.settingsTab;
            local moreActive=(currentTab=='General' or currentTab=='Profiles' or currentTab=='Updates');
            for i,tab in ipairs({{'Quick Setup','Controls'},{'Appearance','Appearance'},{'StateBar','StateBar'},{'More','General'}}) do
                if i>1 then imgui.SameLine(); end
                local active=(tab[2]=='General' and moreActive) or currentTab==tab[2];
                if imgui.Button((active and '['..tab[1]..']' or tab[1])..'##tab'..tab[2]) then state.settingsTab=tab[2]; end
            end
            imgui.Separator();
            if moreActive then
                imgui.Text('More options:');
                for i,tab in ipairs({'General','Profiles','Updates'}) do
                    if i>1 then imgui.SameLine(); end
                    if imgui.Button((state.settingsTab==tab and '['..tab..']' or tab)..'##more'..tab) then state.settingsTab=tab; end
                end
                imgui.Separator();
            end
            if state.settingsTab=='Profiles' then
                imgui.TextWrapped('Active character: '..(state.profileId or 'Waiting for character login'));
                imgui.TextWrapped('Detection: '..state.profileDiagnostic);
                imgui.TextWrapped('Profile file: '..(state.profileId and ('decker_profile_'..state.profileId..'.cfg') or '(none; saves disabled)'));
                imgui.TextWrapped('Profiles are saved separately per server and character. Settings are not copied between characters.');
            elseif state.settingsTab=='Updates' then
                imgui.Text('Installed: v'..addon.version);
                if updater.channel=='stable' then imgui.TextWrapped('No stable updater release has been published yet.'); end
                imgui.TextWrapped('Check, install and reload Decker here. Character settings are preserved. Development builds may have unverified changes.');
                if not updater.job and not updater.installed then
                    if imgui.BeginCombo('Update channel',updater.channel) then
                        for _,channel in ipairs({'development','stable'}) do
                            if imgui.Selectable(channel,updater.channel==channel) then updater.channel=channel; updater.manifest=nil; updater.status='Channel changed; check for updates.'; end
                        end
                        imgui.EndCombo();
                    end
                    if imgui.Button('Check for updates') then update_start('Check'); end
                    if updater.manifest and update_newer(updater.manifest.version,addon.version) then
                        if imgui.Button('Install update and reload Decker') then update_start('Download'); end
                    end
                    local directory=updater_dir();
                    if directory and (updater.backupCheckedAt or 0)~=os.time() then updater.backupCheckedAt=os.time(); updater.backupAvailable=update_exists(directory..'decker.lua.bak'); end
                    if updater.backupAvailable and imgui.Button('Roll back previous version') then updater.confirmRollback=true; end
                    if updater.confirmRollback then
                        imgui.Text('Restore the previous Decker source and reload?');
                        if imgui.Button('Confirm rollback') then updater.confirmRollback=false; update_rollback(); end
                        imgui.SameLine(); if imgui.Button('Cancel rollback') then updater.confirmRollback=false; end
                    end
                end
                imgui.TextWrapped(updater.status);
                imgui.TextWrapped('Windows PowerShell is required. Downloads run in the background over HTTPS, are SHA-256 checked and compiled before installation. A backup enables rollback. Reload affects Decker only; reconnect macros afterward.');
            elseif state.settingsTab=='StateBar' then
                local enabled={state.statebarEnabled};
                if imgui.Checkbox('Enable StateBar',enabled) then state.statebarEnabled=enabled[1]; save_display(); end
                local vert={state.statebarVertical};
                if imgui.Checkbox('Vertical arrangement',vert) then state.statebarVertical=vert[1]; save_display(); end
                local locked={state.statebarLocked};
                if imgui.Checkbox('Lock StateBar position',locked) then state.statebarLocked=locked[1]; save_display(); end
                local always={state.statebarAlways};
                if imgui.Checkbox('Visible in manual mode',always) then state.statebarAlways=always[1]; save_display(); end
                imgui.Text('Visibility (independent of macro HUD):');
                for _,mode in ipairs({'always','navigation','manual'}) do
                    if imgui.Button((state.statebarVisibility==mode and '[X] ' or '')..mode..'##sbvis') then state.statebarVisibility=mode; save_display(); end
                    imgui.SameLine();
                end
                imgui.NewLine();
                imgui.Text(('StateBar opacity: %d%%'):format(math.floor(state.statebarOpacity*100+0.5)));
                if imgui.Button('Less opaque##sb') then state.statebarOpacity=math.max(0,state.statebarOpacity-.05); save_display(); end
                imgui.SameLine();
                if imgui.Button('More opaque##sb') then state.statebarOpacity=math.min(1,state.statebarOpacity+.05); save_display(); end
                imgui.Text('StateBar colour theme:');
                for i,name in ipairs({'Classic','Blue','Green','Purple'}) do
                    if imgui.Button((state.statebarTheme==i and '[X] ' or '')..name..'##sbtheme') then state.statebarTheme=i; save_display(); end
                    if i<4 then imgui.SameLine(); end
                end
                if imgui.Button('StateBar smaller') then state.statebarScale=math.max(.7,state.statebarScale-.1); save_display(); end
                imgui.SameLine(); imgui.Text(('%.0f%%'):format(state.statebarScale*100)); imgui.SameLine();
                if imgui.Button('StateBar larger') then state.statebarScale=math.min(1.5,state.statebarScale+.1); save_display(); end
                imgui.TextWrapped('The last pressed StateBar slot stays highlighted until another State slot is requested; Utility slots preserve it. Main Decker macro highlighting is independent. This indicates the last requested action, not a verified equipped set.');
                imgui.Separator();
                imgui.TextWrapped('Independent StateBar hotkeys (current macro book and set). Keys used by main Decker or navigation are reserved.');
                local sbhot={state.statebarHotkeysEnabled};
                if imgui.Checkbox('Enable StateBar hotkeys (requires keyboard overrides)',sbhot) then state.statebarHotkeysEnabled=sbhot[1]; save_display(); end
                if state.statebarHotkeysEnabled and (not state.keybinds or not state.acknowledgeKeys) then
                    imgui.TextWrapped('Enable direct keyboard overrides and acknowledge the warning under Quick Setup first.');
                end
                for i,b in ipairs(state.statebarSlots) do
                    imgui.Separator(); imgui.Text('Slot '..i);
                    local label={b.label or ''}; if imgui.InputText('Label (optional)##sblabel'..i,label,25) then b.label=label[1]:gsub('[%c#]',''):sub(1,24); save_display(); end
                    if imgui.BeginCombo('Type##sbtype'..i,b.kind or 'state') then
                        for _,kind in ipairs({'state','utility'}) do if imgui.Selectable(kind,b.kind==kind) then b.kind=kind; if kind=='utility' and state.statebarSelected==i then state.statebarSelected=0; end; save_display(); end end
                        imgui.EndCombo();
                    end
                    if imgui.BeginCombo('Action##sbsource'..i,b.source or 'macro') then
                        for _,source in ipairs({'macro','command'}) do if imgui.Selectable(source,b.source==source) then b.source=source; save_display(); end end
                        imgui.EndCombo();
                    end
                    if b.source=='command' then
                        local text={b.command or ''};
                        if imgui.InputText('Command##sbcmd'..i,text,241) then b.command=text[1]; if valid_command(b.command) then save_display(); end end
                        if not valid_command(b.command) then imgui.TextWrapped('Use /equipset 1, /lac set PDT, /item "Food" <me>, /ma "Spell" <me>, /ja "Ability" <me> or /mount "Name".'); end
                    end
                    if imgui.BeginCombo('StateBar slot '..i..'##bar'..i,b.row..' '..b.slot) then
                        for _,row in ipairs({'CTRL','ALT'}) do
                            for slot=1,10 do
                                if imgui.Selectable(row..' '..slot..'##barchoice'..i..row..slot,b.row==row and b.slot==slot) then
                                    b.row=row; b.slot=slot; save_display();
                                end
                            end
                        end
                        imgui.EndCombo();
                    end
                    imgui.SameLine();
                    local current=state.statebarHotkeys[i] or 0;
                    if imgui.BeginCombo('Hotkey##statebarhotkey'..i,DIRECT_NAMES[current] or 'None') then
                        for _,option in ipairs(DIRECT_KEY_OPTIONS) do
                            local label,code=option[1],option[2];
                            local clash=(code~=0 and (mapped_key(code)~=nil or (state.navKeysEnabled and (code==nav_scan() or code==row_key() or NAV_ACTIONS[code]))));
                            if not clash then
                                for j=1,#state.statebarSlots do if j~=i and state.statebarHotkeys[j]==code and code~=0 then clash=true; end end
                            end
                            if not clash and imgui.Selectable(label..'##statebarhotopt'..i..'_'..code,current==code) then state.statebarHotkeys[i]=code; save_display(); end
                        end
                        imgui.EndCombo();
                    end
                    imgui.SameLine();
                    if imgui.Button('Remove##bar'..i) then table.remove(state.statebarSlots,i); table.remove(state.statebarHotkeys,i); if state.statebarSelected==i then state.statebarSelected=0 elseif state.statebarSelected>i then state.statebarSelected=state.statebarSelected-1 end; save_display(); break; end
                end
                if #state.statebarSlots<12 and imgui.Button('Add StateBar slot') then table.insert(state.statebarSlots,{row='CTRL',slot=1}); save_display(); end
                imgui.TextWrapped('Hotkeys are optional and independent. Dedicated-book execution is unavailable: current book/set cannot be independently restored. Modifier shortcuts are unavailable pending input verification. Commands never run arbitrary Lua.');
            end
            if state.settingsTab=='Appearance' then
            if imgui.CollapsingHeader('Display') then
                        local auto={state.autoHide};
            imgui.Text('Character profile: '..(state.profileId or 'waiting for login'));
            if imgui.Button('Unlock HUD for dragging') then state.hudPos=nil; state.positionLocked=false; save_display(); end
            if imgui.Checkbox('Auto-hide macro display',auto) then state.autoHide=auto[1]; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; save_display(); end
            imgui.Text('Hide after inactivity:');
            for _,seconds in ipairs({2,5,10,15,30}) do
                if seconds~=2 then imgui.SameLine(); end
                if imgui.Button((state.autoHideDelay==seconds and '[' or '')..seconds..'s'..(state.autoHideDelay==seconds and ']' or '')..'##hide'..seconds) then state.autoHideDelay=seconds; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; save_display(); end
            end
            imgui.Text('Auto-hide collapses to a recoverable tab (full hide disabled).')
            imgui.SameLine(); if imgui.Button('Collapse to tab'..(state.autoHideMode=='collapse' and ' [selected]' or '')) then state.autoHideMode='collapse'; save_display(); end
            imgui.TextWrapped('The macro display stays visible while navigation is active. Settings stays visible while open. Keyboard shortcuts keep working when hidden.')
            for _,item in ipairs({{'Outer window','outerOpacity'},{'Inner macro panel','panelOpacity'},{'Macro buttons','buttonOpacity'}}) do
                local key=item[2];
                imgui.Text(('%s opacity: %d%%'):format(item[1],math.floor(state[key]*100+.5)));
                if imgui.Button('Less##'..key) then state[key]=math.max(0,state[key]-.05); save_display(); end
                imgui.SameLine(); if imgui.Button('More##'..key) then state[key]=math.min(1,state[key]+.05); save_display(); end
            end
            if imgui.BeginCombo('Macro font',state.macroFont) then
                for _,name in ipairs({'Arial Bold','Segoe UI Bold','Times New Roman Bold','Default'}) do
                    if imgui.Selectable(name,state.macroFont==name) then state.macroFont=name; save_display(); end
                end
                imgui.EndCombo();
            end
            imgui.Text(glass.diagnostic);
            imgui.Text(state.macroFont=='Default' and 'Using host default font' or glass.fonts[state.macroFont] and ('Using '..state.macroFont) or (state.macroFont..' missing; using host default'));
            imgui.Text(('Macro font size: %d'):format(state.macroFontSize));
            if imgui.Button('Font smaller') then state.macroFontSize=math.max(10,state.macroFontSize-1); save_display(); end
            imgui.SameLine(); if imgui.Button('Font larger') then state.macroFontSize=math.min(28,state.macroFontSize+1); save_display(); end
            if imgui.Button('Classic') then state.theme=1; save_display(); end
            imgui.SameLine(); if imgui.Button('Blue') then state.theme=2; save_display(); end
            imgui.SameLine(); if imgui.Button('Purple') then state.theme=3; save_display(); end
            imgui.SameLine(); if imgui.Button('Minimal') then state.theme=4; save_display(); end
            if imgui.Button('Size -') then state.scale=math.max(.7,state.scale-.1); save_display(); end
            imgui.SameLine(); imgui.Text(('Scale %.0f%%'):format(state.scale*100)); imgui.SameLine();
            if imgui.Button('Size +') then state.scale=math.min(1.5,state.scale+.1); save_display(); end
            if imgui.Button('Narrower') then state.hudWidth=math.max(80,state.hudWidth-8); save_display(); end
            imgui.SameLine(); if imgui.Button('Wider') then state.hudWidth=math.min(140,state.hudWidth+8); save_display(); end
            local ck={state.compactKeys};
            if imgui.Checkbox('Compact key labels',ck) then state.compactKeys=ck[1]; save_display(); end
            imgui.Separator();
            end
            end -- General / Appearance tab
            if state.settingsTab=='Controls' then
             imgui.Text('QUICK SETUP - KEYBOARD')
             imgui.Separator();
            if imgui.Button('Connect macros##quick') then connect_macros(); end
            imgui.Text('1. Choose your keyboard layout:');
            for _,mode in ipairs({{'split','Split: F1-F10 / 1-0'},{'numbers','1-0 on selected row'},{'functions','F1-F10 on selected row'}}) do
                if imgui.Button((state.mappingMode==mode[1] and '[X] ' or '')..mode[2]) then state.mappingMode=mode[1]; state.held={}; state.suppressed={}; save_display(); end
            end
             imgui.Text('2. Activate your chosen keys:');
imgui.Text('Keyboard permission');
            imgui.TextWrapped('Split mapping sets labels only. To execute F1-F10 and 1-0 directly: Connect macros, acknowledge the chat/menu risk, then enable experimental keyboard overrides below. Custom navigation is separate.');
            imgui.Text('Keyboard: '..(shortcuts_active() and 'ENABLED' or 'DISABLED')..' | Macros: '..(state.allowAllClicks and 'CONNECTED' or 'NOT CONNECTED'));
            local ack={state.acknowledgeKeys};
            if imgui.Checkbox('I understand the chat/menu risk',ack) then
                state.acknowledgeKeys=ack[1]; state.savedAck=ack[1];
                if not ack[1] then state.keybinds=false; state.savedKeybinds=false; state.held={}; end
                save_display();
            end
            if state.acknowledgeKeys and state.allowAllClicks then
                local enabled={state.keybinds};
                if imgui.Checkbox('Enable experimental keyboard overrides',enabled) then state.keybinds=enabled[1]; state.savedKeybinds=enabled[1]; state.held={}; save_display(); end
            end
             if not state.allowAllClicks then imgui.TextWrapped('Connect macros on the main HUD first, then return here to enable execution.'); end
             imgui.Text('Direct execution: '..(state.keybinds and 'ON' or 'OFF'));
             imgui.Separator();
             if imgui.CollapsingHeader('Advanced navigation and key assignments') then
            local echo={state.echoLock};
            if imgui.Checkbox('Echo lock / unlock to chat',echo) then state.echoLock=echo[1]; save_display(); end
            imgui.TextWrapped('Only Toggle / Lock changes are announced. Hold mode stays quiet to avoid chat spam.');
            imgui.Text('Navigation');
            imgui.TextWrapped('Selected modifier + Up/Down changes sets through Decker. When enabled, the selected modifier is reserved and will not work normally in FFXI. Disable before typing or editing.');
            if imgui.BeginCombo('Navigation modifier',state.navModifier) then
                for _,choice in ipairs({'RSHIFT','LSHIFT','END','HOME'}) do
                    if imgui.Selectable(choice,state.navModifier==choice) then
                        state.navModifier=choice;
                        state.navModifierHeld=false;
                        state.navCaptured={};
                        state.navKeysEnabled=false; state.savedNavEnabled=false; nav_clear(); -- re-enable deliberately after rebinding
                        save_display();
                    end
                end
                imgui.EndCombo();
            end
            imgui.TextWrapped('Arrow Left/Right: select slot. Space or Switch Row Key: switch Decker row. Enter: execute. Up/Down: change set. Escape: handled by FFXI (does not unlock).')
            if imgui.BeginCombo('Switch Row Key',state.rowSwitchKey) then
                for _,choice in ipairs({'END','HOME','INSERT','DELETE','N','F9','F10','F11','F12'}) do
                    if imgui.Selectable(choice,state.rowSwitchKey==choice) then
                        state.rowSwitchKey=choice; state.navCaptured={}; state.navPhysicalKeys={}; save_display();
                    end
                end
                imgui.EndCombo();
            end
            imgui.TextWrapped('Switch Row Key works in Hold and Toggle modes. It changes Decker row, not FFXI palette focus.')
            if imgui.BeginCombo('Navigation behaviour', state.stickyNavigation and 'Toggle / Lock' or 'Hold to navigate') then
                if imgui.Selectable('Toggle / Lock',state.stickyNavigation) then
                    state.stickyNavigation=true; nav_clear(); save_display();
                end
                if imgui.Selectable('Hold to navigate',not state.stickyNavigation) then
                    state.stickyNavigation=false; nav_clear(); save_display();
                end
                imgui.EndCombo();
            end
            imgui.TextWrapped(state.stickyNavigation and
                'Tap the modifier once to LOCK navigation, again to UNLOCK. Escape does not unlock.' or
                'Navigation works only while you physically hold the modifier. Release to restore normal arrow controls.')
            imgui.Text(state.navKeysEnabled and (state.stickyNavigation and (state.navToggleActive and 'LOCKED' or 'UNLOCKED') or (state.navModifierHeld and 'HELD' or 'RELEASED')) or 'Custom navigation OFF')
            local nav={state.navKeysEnabled};
            if imgui.Checkbox('Enable custom navigation',nav) then
                state.navKeysEnabled=nav[1]; state.savedNavEnabled=nav[1]; nav_clear(); save_display();
            end
                        imgui.Separator();
            imgui.Separator();
            imgui.Text('Cooldown text colours (experimental)');
            local cool={state.cooldownEnabled};
            if imgui.Checkbox('Red macro text when ability/spell is recasting',cool) then state.cooldownEnabled=cool[1]; save_display(); end
            imgui.TextWrapped('Only explicitly mapped actions are checked. Unmapped buttons stay their normal colour. Red buttons remain clickable. Spell IDs and ability recast timer IDs are different; do not use ability IDs as timer IDs.');
            for i=1,20 do
                local b=state.cooldownBindings[i];
                local label=(i<=10 and 'CTRL ' or 'ALT ')..tostring((i-1)%10+1);
                imgui.Text(label..': '..(b and (b.kind..' '..b.id) or 'unmapped'));
                imgui.SameLine();
                if imgui.Button('Clear##cool'..i) then state.cooldownBindings[i]=nil; save_display(); end
            end
            imgui.TextWrapped('To map a button: /decker cooldown ctrl 1 spell 123, or /decker cooldown alt 2 ability 5. Use /decker cooldown ctrl 1 clear to remove. Ability value is a recast timer ID.');
                        imgui.Separator();
            imgui.Text('Upper row - CTRL macros (slots 1-10)');
            imgui.TextWrapped('Pick a direct key for each macro. These only work when experimental keyboard overrides are enabled.');
            for i=1,20 do
                if i==11 then imgui.Separator(); imgui.Text('Lower row - ALT macros (slots 1-10)'); end
                local slot=(i-1)%10+1;
                local code=state.directKeys[i] or 0;
                local name=DIRECT_NAMES[code] or 'None';
                if imgui.BeginCombo(('Slot %d##direct%d'):format(slot,i),name) then
                    for _,choice in ipairs(DIRECT_KEY_OPTIONS) do
                        local candidate=choice[2];
                        if imgui.Selectable(choice[1]..'##directchoice'..i..'_'..candidate,code==candidate) then
                            if not direct_conflict(candidate,i) then
                                state.directKeys[i]=candidate; state.held={}; state.suppressed={}; save_display();
                            else
                                state.keySummary='Binding conflict: key already used or reserved by navigation';
                            end
                        end
                    end
                    imgui.EndCombo();
                end
            end
            imgui.TextWrapped(state.keySummary);
            if imgui.Button('Reset direct keys to defaults') then
                state.directKeys=default_direct_keys();
                state.held={}; state.suppressed={}; save_display();
            end
            if imgui.Button('Release keyboard overrides') then state.keybinds=false; state.acknowledgeKeys=false; state.savedKeybinds=false; state.savedAck=false; state.held={}; save_display(); end
            imgui.Text('/decker keysoff also disables overrides');
            end
            end -- Controls tab
            if state.settingsTab=='General' and imgui.CollapsingHeader('Book and Set controls') then
                if state.allowSwitch then
                    imgui.Text('Jump to macro set:');
                    for i=1,10 do
                        if i>1 then imgui.SameLine(); end
                        if imgui.Button(tostring(i)..'##more_set'..i,{30,24}) then select_page(i); end
                    end
                else
                    imgui.TextWrapped('Macro set switching is unavailable until native macros connect.');
                end
            end
            if state.settingsTab=='General' and imgui.CollapsingHeader('Quick Start Guide') then
                imgui.TextWrapped('Decker - Enhanced In-Game Macro Interface for FFXI')
                imgui.TextWrapped('1. Open FFXI and load Decker in Ashita.')
                imgui.TextWrapped('2. Open Settings. Select Refresh macro names to load your current Ctrl/Alt macro labels.')
                imgui.TextWrapped('3. Open Settings > Controls. Choose a comfortable Navigation modifier (Right Shift is an example).')
                imgui.TextWrapped('IMPORTANT: Avoid Ctrl and Alt for Decker navigation. Keep them for FFXI original macros.')
                imgui.TextWrapped('4. Choose Hold to navigate or Toggle / Lock, whichever feels best.')
                imgui.TextWrapped('5. Enable custom navigation, then close Settings.')
                imgui.TextWrapped('6. Hold or tap your chosen modifier. Left/Right selects slots; End switches Ctrl/Alt rows.')
                imgui.TextWrapped('7. Up/Down changes sets; Enter runs the selected macro.')
                imgui.TextWrapped('8. Release or tap the modifier again to exit navigation. Ready!')
                imgui.Separator()
                imgui.TextWrapped('If macro names are missing or outdated, use Refresh macro names again. Your original FFXI macros remain unchanged.')
            end
            imgui.Separator();
            if state.settingsTab=='General' and imgui.Button(state.showAdvanced and 'Hide advanced diagnostics' or 'Show advanced diagnostics') then state.showAdvanced=not state.showAdvanced; end
            if state.settingsTab=='General' and state.showAdvanced then
                local logging={state.debugLog};
                if imgui.Checkbox('Developer chat logging',logging) then state.debugLog=logging[1]; end
                imgui.TextWrapped('Native book/set getters remain unverified. Native arrow selection is not highlighted until a reliable getter exists.');
                imgui.TextWrapped('Read status: '..state.nameSummary);
                imgui.TextWrapped('Pointers: '..state.pointerSummary);
                imgui.TextWrapped('Signatures: '..state.summary);
                imgui.TextWrapped('Native set/book numbers are not independently detected.');
                imgui.TextWrapped('Decker does not modify the original FFXI HUD.');
                if imgui.Button('Reconnect (native calls)') then connect_macros(); end
                imgui.SameLine(); if imgui.Button('Rescan only') then scan(); end
                if imgui.Button('Show/hide signature details') then state.details=not state.details; end
                if state.details then for _,p in ipairs(state.signatures) do imgui.TextWrapped(p[1]..': '..p[2]); end end
            end
            if (state.settingsTab=='General' or state.settingsTab=='Controls') and state.phase>=4 and imgui.Button('Refresh macro names') then state.confirmAll=true; read_all_names(); end
            imgui.Separator(); imgui.Text('Decker v'..addon.version..'  |  by Mutant X')
            imgui.TextWrapped('CatseyeXI: T1 Sanctioned - approved 19 October 2026.');
            local section=moreActive and 'General' or state.settingsTab;
            if imgui.Button('Restore section defaults') then state.resetSection=section; end
            if state.resetSection==section then
                imgui.Text('Restore only this section?');
                if imgui.Button('Confirm restore') then restore_section(section); state.resetSection=nil; end
                imgui.SameLine(); if imgui.Button('Cancel restore') then state.resetSection=nil; end
            end
            if imgui.Button('Close settings') then state.showTests=false; end
        end
        imgui.End();
    end
end);
