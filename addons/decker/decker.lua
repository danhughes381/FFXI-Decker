-- Decker 1.50.16-dev: opt-in immediate (0s) post-action HUD hide for Toggle mode.
-- Native macro calls and opt-in DirectInput keyboard hooks; no original HUD patches.
-- CAUTION: Opt-in native FFI call may crash the FFXI process if signatures/API differ.
addon.name = 'Decker';
addon.author = 'Mutant X';
addon.version = '1.50.16-dev';
addon.desc = 'FFXI-inspired dual-row macro HUD; validated mouse execution and opt-in keyboard controls.';
require('common');
local chat = require('chat');
local imgui = require('imgui');
local ffi = require('ffi');
ffi.cdef[[typedef const char* (__thiscall* Decker_FsMacroContainer_getName_f)(uint32_t, uint32_t); typedef int32_t (__thiscall* Decker_FsMacroContainer_setPage_f)(uint32_t, uint32_t); typedef int32_t (__thiscall* Decker_FsMacroContainer_setBook_f)(uint32_t, uint32_t); typedef void (__thiscall* Decker_FsMacroContainer_runMacro_f)(uint32_t, uint8_t, uint8_t);]];
local state = { visible=true, signatures={}, addresses={}, summary='Not scanned', pointerSummary='Not checked', nameSummary='Not attempted', phase=0, confirm=false, confirmAll=false, scanning=false, names={}, setHint='Current in-game set (not independently detected)', nameCount=0, allowSwitch=false, selectedPage=nil, previousFingerprint=nil, changeSummary='Not checked', switchSummary='Not attempted', autoRefresh=false, refreshAt=0, refreshInterval=3, compact=true, details=false, showTests=false, clickConsent=false, clickSummary='Not attempted', scale=1.0, refreshErrorCount=0, hudWidth=92, hudHeight=43, allowAllClicks=false, nativeHudStudy=false, theme=1, compactKeys=true, keybinds=false, acknowledgeKeys=false, held={}, keySummary='Exclusive bindings OFF by default', preserveNativeArrows=true, pendingRefreshFrames=0, manualBook=1, trackedSet=1, trackedSource='default (unverified)', suppressed={}, nativeArrowRefreshes=0, showAdvanced=false, debugLog=false, flashRow=nil, flashSlot=nil, flashUntil=0, navSlot=nil, navRow=nil, navSource='unverified', navHeld={}, navModifier='RSHIFT', navKeysEnabled=false, navModifierHeld=false, navCaptured={}, navUpHeld=false, navDownHeld=false, stickyNavigation=true, navToggleActive=false, navPressed={}, navPhysicalDown=false, navHeldKeys={}, navPhysicalKeys={}, navQueue={}, navRow='CTRL', navSlot=1, navSource='default', savedNavEnabled=false, savedKeybinds=false, savedAck=false, rowSwitchKey='END', hudOpacity=1.0, echoLock=true, autoHide=false, autoHideDelay=10, autoHideMode='hide', hudLastActivity=os.clock(), hudWasActive=false, hudReadySince=nil, hudHasInteracted=false, hudForceReveal=false };
-- Configurable direct bindings. Defaults retain the original 1-0 / F1-F10 scheme.
-- All direct shortcuts are opt-in; never rewrite FFXI's native macro keys.
local BOOK_COUNT=20; -- Matches the target client's visible macro-book menu.
local DIRECT_KEY_OPTIONS={
    {'None',0},{'1',2},{'2',3},{'3',4},{'4',5},{'5',6},{'6',7},{'7',8},{'8',9},{'9',10},{'0',11},
    {'F1',59},{'F2',60},{'F3',61},{'F4',62},{'F5',63},{'F6',64},{'F7',65},{'F8',66},{'F9',67},{'F10',68},
    {'F11',87},{'F12',88},{'Q',16},{'W',17},{'E',18},{'R',19},{'T',20},{'Y',21},{'U',22},{'I',23},{'O',24},{'P',25},
    {'A',30},{'S',31},{'D',32},{'F',33},{'G',34},{'H',35},{'J',36},{'K',37},{'L',38},
    {'Z',44},{'X',45},{'C',46},{'V',47},{'B',48},{'N',49},{'M',50},
    {'Insert',210},{'Delete',211},{'Home',199},{'End',207},{'Page Up',201},{'Page Down',209},
    {'Num 0',82},{'Num 1',79},{'Num 2',80},{'Num 3',81},{'Num 4',75},
    {'Num 5',76},{'Num 6',77},{'Num 7',71},{'Num 8',72},{'Num 9',73},
    {'Num +',78},{'Num -',74},{'Num *',55},{'Num /',181},{'Num .',83},
    {'Minus',12},{'Equals',13},{'Left bracket',26},{'Right bracket',27},
    {'Semicolon',39},{'Apostrophe',40},{'Backslash',43},{'Comma',51},{'Period',52},{'Slash',53}
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
state.mappingMode='numbers'; state.positionLocked=false; state.hudPos=nil; state.profileId=nil; state.profileReady=false; state.lastProfileCheck=0;
local function copy_value(v)
    if type(v)~='table' then return v; end
    local t={}; for k,x in pairs(v) do t[k]=copy_value(x); end; return t;
end
-- Glass preferences are display-only and participate in character profile isolation.
state.savedKeybinds=true; state.savedAck=true;
state.bookNames={}; state.bookAliases={}; state.bookPath=''; state.bookNameStatus='No saved book titles imported';
state.showScrollbars=true;
state.outerOpacity=.05; state.panelOpacity=.15; state.buttonOpacity=.85;
state.statebarOpacity=.15; state.macroFont='Arial Bold'; state.macroFontSize=18;
state.motionEnabled=true; -- Pure draw-only effects; reduced-motion preference, per profile.
state.hudImmediateHide=false; -- Session-only: 0s hides after an action or after Toggle navigation ends.
state.guideOpen=false; state.guideStep=1; state.guideDemoRow='CTRL'; state.guideDemoSlot=2; state.guideDemoMode='Hold'; state.guideDemoAt=0; -- Session-only, never saved.
local profileDefaults=copy_value(state);
local sectionKeys={
    Controls={'mappingMode','directKeys','navModifier','rowSwitchKey','stickyNavigation','navKeysEnabled','keybinds','acknowledgeKeys','savedNavEnabled','savedKeybinds','savedAck','echoLock'},
    Appearance={'showScrollbars','outerOpacity','panelOpacity','buttonOpacity','macroFont','macroFontSize','scale','theme','hudWidth','hudHeight','compactKeys','hudOpacity','autoHide','autoHideDelay','autoHideMode','positionLocked','motionEnabled'},
    StateBar={'statebarEnabled','statebarVertical','statebarLocked','statebarAlways','statebarScale','statebarOpacity','statebarTheme','statebarVisibility','statebarSelected','statebarHotkeys','statebarHotkeysEnabled','statebarSlots'},
    General={'bookNames','bookAliases','bookPath','bookNameStatus','manualBook','trackedSet','cooldownEnabled','cooldownBindings'},
};
-- First-install defaults also form the profile-isolation boundary.
profileDefaults.autoHide=false; profileDefaults.autoHideMode='hide';
profileDefaults.cooldownEnabled=false; profileDefaults.cooldownBindings={};
local function direct_conflict(code,index)
    if code==0 then return false; end
    if state.mappingMode=='split' or state.mappingMode=='custom' or index>0 then for i,k in ipairs(state.directKeys) do if i~=index and k==code then return true; end end end
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
    f:write('showscrollbars=',state.showScrollbars and '1' or '0','\n');
    f:write('motionenabled=',state.motionEnabled and '1' or '0','\n');
    f:write('glassversion=1\nouteropacity=',state.outerOpacity,'\npanelopacity=',state.panelOpacity,'\nbuttonopacity=',state.buttonOpacity,'\nmacrofont=',state.macroFont:gsub(' ','_'),'\nmacrofontsize=',state.macroFontSize,'\n');
    f:write('theme=',state.theme,'\nscale=',state.scale,'\nwidth=',state.hudWidth,'\nheight=',state.hudHeight,'\ncompact=',state.compactKeys and '1' or '0','\nbook=',state.manualBook or 1,'\nset=',state.trackedSet or 1,'\nopacity=',state.hudOpacity,'\nautohide=',state.autoHide and '1' or '0','\nautohidedelay=',state.autoHideDelay,'\nautohidemode=',state.autoHideMode,'\necholock=',state.echoLock and '1' or '0','\nrowswitchkey=',state.rowSwitchKey,'\nnavmodifier=',state.navModifier,'\nnavmode=',state.stickyNavigation and 'toggle' or 'hold','\nnavenabled=',state.navKeysEnabled and '1' or '0','\nkeybinds=',state.keybinds and '1' or '0','\nackkeys=',state.acknowledgeKeys and '1' or '0','\n');
    f:write('mappingmode=',state.mappingMode,'\npositionlocked=',state.positionLocked and '1' or '0','\nnavrow=',state.navRow or 'CTRL','\n');
    if state.hudPos then f:write('posx=',math.floor(state.hudPos[1]),'\nposy=',math.floor(state.hudPos[2]),'\n'); end
    f:write('statebarenabled=',state.statebarEnabled and '1' or '0','\nstatebarvertical=',state.statebarVertical and '1' or '0','\nstatebarlocked=',state.statebarLocked and '1' or '0','\nstatebaralways=',state.statebarAlways and '1' or '0','\nstatebarscale=',state.statebarScale,'\nstatebaropacity=',state.statebarOpacity,'\nstatebartheme=',state.statebarTheme,'\nstatebarvisibility=',state.statebarVisibility,'\nstatebarselected=',state.statebarSelected or 0,'\n');
    f:write('statebarcount=',#state.statebarSlots,'\n');
    f:write('statebarhotkeysenabled=',state.statebarHotkeysEnabled and '1' or '0','\n');
    for i,b in ipairs(state.statebarSlots) do f:write('statebar',i,'=',b.row,':',b.slot,'\n'); f:write('statebarhotkey',i,'=',state.statebarHotkeys[i] or 0,'\n'); f:write('statebartype',i,'=',b.kind or 'state','\n'); f:write('statebarcommand',i,'=',(b.command or ''):gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n'); f:write('statebarsource',i,'=',b.source or 'macro','\n'); f:write('statebarlabel',i,'=',(b.label or ''):gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n'); end
    f:write('bookpath=',(state.bookPath or ''):gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n');
    for i=1,40 do
        for _,field in ipairs({'bookNames','bookAliases'}) do
            local value=state[field][i];
            if value and value~='' then f:write(field:lower(),i,'=',value:gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n'); end
        end
    end
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
        local field,index;
        if key then field,index=key:match('^(booknames)(%d+)$'); if not field then field,index=key:match('^(bookaliases)(%d+)$'); end end
        if key=='bookpath' or field then
            local raw=value or '';
            if #raw<=2048 and #raw%2==0 and not raw:find('[^%x]') then
                local decoded=raw:gsub('%x%x',function(c) return string.char(tonumber(c,16)); end);
                if not decoded:find('%c') then
                    if key=='bookpath' then state.bookPath=decoded;
                    elseif tonumber(index)>=1 and tonumber(index)<=40 then state[field=='booknames' and 'bookNames' or 'bookAliases'][tonumber(index)]=decoded; end
                end
            end
        end
        if key=='showscrollbars' then state.showScrollbars=value=='1'; end
        if key=='motionenabled' and (value=='0' or value=='1') then state.motionEnabled=value=='1'; end
        if key=='mappingmode' and (value=='split' or value=='numbers' or value=='functions' or value=='custom') then state.mappingMode=value; end
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
        if key=='autohidedelay' and (n==0 or n==2 or n==5 or n==10 or n==15 or n==30) then state.autoHideDelay=n; end
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
        elseif key=='book' and n and n==math.floor(n) and n>=1 and n<=BOOK_COUNT then state.manualBook=n;
        elseif key=='set' and n and n==math.floor(n) and n>=1 and n<=10 then state.trackedSet=n; state.trackedSource='saved (unverified)'; end
    end
    f:close();
    if state.mappingMode=='split' then
        local defaults=default_direct_keys();
        for i=1,20 do if state.directKeys[i]~=defaults[i] then state.mappingMode='custom'; break; end end
    end
end
-- Format researched in MacroEditor MacroFileManager; independent bounded reader.
local function parse_book_titles(bytes)
    if type(bytes)~='string' or #bytes~=344 then return nil,'Expected a 344-byte macro title file'; end
    local names={};
    for i=1,20 do
        local record=bytes:sub(25+(i-1)*16,40+(i-1)*16);
        local zero=record:find('%z');
        if not zero or record:sub(zero):find('[^%z]') then return nil,'Invalid title record'; end
        local title=record:sub(1,zero-1);
        if title:find('[^ -~]') then return nil,'This title file needs non-ASCII decoding; use Decker labels for now'; end
        names[i]=title;
    end
    return names;
end
local function import_book_titles()
    local path=(state.bookPath or ''):gsub('[\\/]+$','');
    if path=='' or path:find('%c') then state.bookNameStatus="Enter this character's macro folder first"; return false; end
    local function read(name,optional)
        local f=io.open(path..'/'..name,'rb');
        if not f then return optional and {} or nil,'Cannot open '..name; end
        local bytes=f:read(345); f:close(); return parse_book_titles(bytes);
    end
    local first,err=read('mcr.ttl',false); if not first then state.bookNameStatus=err; return false; end
    state.bookNames=first; state.bookNameStatus='Imported saved in-game titles; refresh after saving a rename in game'; save_display(); return true;
end
local function book_label(book)
    local name=state.bookAliases[book] or state.bookNames[book];
    return ('Book %d'):format(book)..(name and name~='' and (' - '..name) or '');
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
    state.hudPos=nil; state.keyAssignmentPage=false; state.statebarSelected=0; state.navRow='CTRL'; state.navSlot=1;
    state.names={}; state.phase=0; state.allowAllClicks=false; state.allowSwitch=false;
    state.autoRefresh=false; state.clickConsent=false; state.confirmAll=false;
    state.navToggleActive=false; state.navModifierHeld=false; state.navPhysicalDown=false;
    state.navCaptured={}; state.navPressed={}; state.navPhysicalKeys={}; state.navQueue={}; state.deferredNav={};
    state.navSetVerifyFrames=0; state.pendingRefreshFrames=0; state.lastExecuted=nil;
    state.flashRow=nil; state.flashSlot=nil; state.flashUntil=0;
    state.guideOpen=false; state.guideStep=1; state.guideDemoRow='CTRL'; state.guideDemoSlot=2; state.guideDemoMode='Hold';
    state.hudReadySince=nil; state.hudLastActivity=os.clock(); state.hudImmediateHide=false;
    if id then
        load_display(); state.profileReady=true;
        state.navKeysEnabled=state.savedNavEnabled;
        -- Connection gates execution; saved on/off choice applies only after Connect succeeds.
        state.keybinds=false; state.acknowledgeKeys=false;
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
-- Target client exposes 20 macro books; native API accepts zero-based index.
-- Labels are tracked locally, not independently read from game memory.
local function select_native_book(book)
    if type(book)~='number' or book~=math.floor(book) or book<1 or book>BOOK_COUNT then
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
    if state.autoHide and state.autoHideDelay==0 then state.hudImmediateHide=true; end
end
local function execute_slot(row,slot)
    if state.guideOpen then return false; end -- Simulated guide is strictly non-executing, including hotkeys.
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
    if state.guideOpen then return false; end -- Guide cannot fire StateBar commands or macros.
    local b=state.statebarSlots[i]; if not b or not state.profileReady then return false; end
    local requested=false;
    if b.source=='command' then
        if not state.allowAllClicks or not valid_command(b.command) then state.clickSummary='StateBar command blocked: connect and use a supported single command.'; return false; end
        local ok,result=pcall(function() return AshitaCore:GetChatManager():QueueCommand(-1,b.command); end); requested=ok and result~=false;
    else requested=execute_slot(b.row,b.slot); end
    if requested and state.autoHide and state.autoHideDelay==0 then state.hudImmediateHide=true; end
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
    state.keybinds=false; state.acknowledgeKeys=false;
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
        state.acknowledgeKeys=state.savedKeybinds; state.savedAck=state.savedKeybinds;
        state.keybinds=state.savedKeybinds and state.allowAllClicks;
        state.navKeysEnabled=state.savedNavEnabled;
        state.navToggleActive=false;
    end
end
-- Display-only glass renderer. Native buttons retain hit testing, IDs and execution.
-- No font atlas mutation in d3d_present; load a bounded set once in the load event.
local glass={fonts={},fontTiers={},diagnostic='Default font; awaiting load',custom=true};
local fontFiles={['Arial Bold']='arialbd.ttf',['Segoe UI Bold']='segoeuib.ttf',['Times New Roman Bold']='timesbd.ttf'};
local fontSizes={16,20,28};
local function load_glass_fonts()
    -- Fonts are registered on load only, never while presenting a frame.
    -- Keep 20px as the default so existing profiles have the same appearance.
    if type(imgui.AddFontFromFileTTF)~='function' then glass.diagnostic='Custom fonts unavailable; using host default'; return; end
    local root=os.getenv('WINDIR') or 'C:\\Windows';
    for name,file in pairs(fontFiles) do
        local path=root..'\\Fonts\\'..file;
        local f=io.open(path,'rb');
        if f then
            f:close(); local tiers={};
            for _,px in ipairs(fontSizes) do
                local ok,font=pcall(imgui.AddFontFromFileTTF,path,px);
                if ok and font then tiers[px]=font; end
            end
            glass.fontTiers[name]=tiers;
            glass.fonts[name]=tiers[20] or tiers[16] or tiers[28];
        end
    end
    glass.diagnostic=glass.fonts['Arial Bold'] and 'Arial Bold ready (multi-size)' or 'Arial Bold unavailable; using host default';
end
local function glass_font_for(size)
    local tiers=glass.fontTiers[state.macroFont];
    if tiers then
        for _,px in ipairs(fontSizes) do if px>=size and tiers[px] then return tiers[px]; end end
        for i=#fontSizes,1,-1 do if tiers[fontSizes[i]] then return tiers[fontSizes[i]]; end end
    end
    return glass.fonts[state.macroFont] or imgui.GetFont();
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
-- Apply locked coordinates every frame as well as NoMove. Accept host vector forms.
local windowGeometry={};
local geometryProfile=nil;
local function geometry(id)
    if geometryProfile~=state.profileId then windowGeometry={}; geometryProfile=state.profileId; end
    windowGeometry[id]=windowGeometry[id] or {};
    return windowGeometry[id];
end
local function pin_window(id,locked)
    local g=geometry(id);
    if locked and g.pos and type(imgui.SetNextWindowPos)=='function' then
        -- A saved locked position must remain usable after monitor/resolution changes.
        -- Never reposition during an unlocked drag; absent GetIO leaves the old behaviour.
        if type(imgui.GetIO)=='function' then
            local ok,sw,sh=pcall(function() return pair(imgui.GetIO().DisplaySize); end);
            local x,y=pair(g.pos);
            if ok and x and y and type(sw)=='number' and type(sh)=='number' and sw>0 and sh>0 then
                local xmax=math.max(0,sw-math.min(g.w or 1,sw));
                local ymax=math.max(0,sh-math.min(g.h or 1,sh));
                g.pos={math.max(0,math.min(xmax,x)),math.max(0,math.min(ymax,y))};
            end
        end
        imgui.SetNextWindowPos(g.pos,ImGuiCond_Always or 1);
    end
end
local function remember_window(id,locked)
    local g=geometry(id);
    if (not locked or not g.pos) and type(imgui.GetWindowPos)=='function' then
        local ok,a,b=pcall(imgui.GetWindowPos);
        if ok then local x,y=pair(a,b); if x and y then g.pos={x,y}; end end
    end
end
local function size_window(id,w,h)
    local g=geometry(id);
    local changed=g.w~=w or g.h~=h;
    imgui.SetNextWindowSize({w,h},changed and (ImGuiCond_Always or 1) or ImGuiCond_FirstUseEver);
    g.w=w; g.h=h;
end
local function scrollbar_flags() return state.showScrollbars and 0 or (ImGuiWindowFlags_NoScrollbar or 8); end
local function push_glass_background(opacity)
    local n,v=0,0;
    if imgui.PushStyleColor and imgui.PopStyleColor then
        for _,entry in ipairs({{ImGuiCol_WindowBg,{0,0,0,opacity}},{ImGuiCol_Border,{0,0,0,0}},
            {ImGuiCol_TitleBg,{0,0,0,0}},{ImGuiCol_TitleBgActive,{0,0,0,0}},{ImGuiCol_TitleBgCollapsed,{0,0,0,0}}}) do
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
local function draw_glass_text(dl,text,x,y,w,h,shortcut,cooling,displayScale)
    local textScale=displayScale or state.scale;
    local initialSize=math.min(state.macroFontSize*textScale,math.max(10,h-18));
    local font=glass_font_for(initialSize);
    imgui.PushFont(font);
    local ok,err=pcall(function()
        local natural=imgui.GetTextLineHeight();
        local function width(t,size)
            local tw=pair(imgui.CalcTextSize(t)); return (tw or 0)*size/natural;
        end
        local size=initialSize;
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
        local ks=math.min(10*textScale,math.max(7,h/4));
        if width(shortcut,ks)>w-10 then ks=ks*(w-10)/math.max(1,width(shortcut,ks)); end
        dl:AddText(font,ks,{x+w-width(shortcut,ks)-5,y+h-ks-3},imgui.GetColorU32({.68,.70,.74,1}),shortcut);
    end);
    imgui.PopFont();
    if not ok then error(err); end
end
local function draw_row(title,offset)
    local now=os.clock(); -- One animation clock sample for the entire row.
    local w=math.floor(state.hudWidth*state.scale);
    local h=math.floor(state.hudHeight*state.scale);
    for i=1,10 do
        if i>1 then imgui.SameLine(); end
        local name=state.names[offset+i] or '';
        local shortcut=state.mappingMode=='numbers' and tostring(i==10 and 0 or i)
            or state.mappingMode=='functions' and ('F'..i)
            or DIRECT_NAMES[state.directKeys[offset+i]] or '?';
        if not state.compactKeys then shortcut=title..' '..tostring(i==10 and 0 or i)..' | '..shortcut; end
        local flashing=state.flashRow==title and state.flashSlot==i and now<state.flashUntil;
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
                -- Bounded draw-only micro-motion: no textures, input changes or extra windows.
                if state.motionEnabled then
                    if selected and type(dl.AddRect)=='function' then
                        local glow=.15+.13*(.5+.5*math.sin(now*3.2));
                        dl:AddRect({x+2,y+2},{x+w-2,y+h-2},imgui.GetColorU32({.95,.79,.45,glow}),2,0,1);
                    end
                    if flashing and type(dl.AddRectFilledMultiColor)=='function' then
                        local fade=math.max(0,math.min(1,(state.flashUntil-now)/.30));
                        dl:AddRectFilledMultiColor({x+3,y+h-5},{x+w-3,y+h-3},
                            imgui.GetColorU32({.95,.73,.35,fade*.85}),imgui.GetColorU32({1,.94,.65,fade*.85}),
                            imgui.GetColorU32({1,.94,.65,fade*.85}),imgui.GetColorU32({.95,.73,.35,fade*.85}));
                    end
                end
                draw_glass_text(dl,name,x,y,w,h,shortcut,cooling);
            end);
            if not ok then glass.custom=false; glass.diagnostic='Host draw API fallback: '..tostring(err); end
        end
        if imgui.IsItemHovered and imgui.SetTooltip and imgui.IsItemHovered() and name~='' then imgui.SetTooltip(name); end
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

-- Small, original preview UI. A guide click only changes guideDemoRow/guideDemoMode;
-- it NEVER reaches native macro execution, SetBook/SetPage or the StateBar.
local GUIDE_STEPS={
    {'Meet your two rows','Your original FFXI CTRL and ALT macro rows remain together in Decker. Tap the example labels below to explore them; these are fictional examples, NOT your actual macros.'},
    {'Selecting versus executing','A selection highlight is not an execution. Decker executes only on your actual approved mouse/keyboard input outside this guide. Tap Flash or Cure to move the example highlight safely.'},
    {'Hold and Toggle','Hold shows the macro HUD while the modifier is pressed. Toggle locks its visibility until switched off or auto-hide. Try the two demonstration modes; your real preference does not change.'},
    {'Books, sets and StateBar','The Macro set selector moves across sets 1-10, and Book across books 1-20 when connected. StateBar provides separate state/utility slots; its highlights only record a request, not verified equipment.'},
};
local function open_guide()
    state.guideOpen=true; state.guideStep=1;
    state.guideDemoRow='CTRL'; state.guideDemoSlot=2; state.guideDemoMode='Hold'; state.guideDemoAt=os.clock();
end
local function guide_draw()
    if not state.guideOpen then return; end
    imgui.SetNextWindowSize({530,300},ImGuiCond_FirstUseEver);
    local opened={state.guideOpen};
    if imgui.Begin('Decker Interactive Guide - SAFE PREVIEW##decker_guide',opened,scrollbar_flags()) then
        local step=math.max(1,math.min(#GUIDE_STEPS,state.guideStep or 1));
        local detail=GUIDE_STEPS[step];
        imgui.Text(('GUIDE %d/%d | %s'):format(step,#GUIDE_STEPS,detail[1]));
        imgui.Separator();
        imgui.TextWrapped(detail[2]);
        imgui.Text('SIMULATED INPUT - NO IN-GAME MACROS OR GEAR CHANGES');
        local preview={
            {'CTRL','Flash','Provoke'},
            {'ALT','Cure III','Protect'},
        };
        for _,row in ipairs(preview) do
            imgui.Text(row[1]..' row');
            imgui.SameLine();
            for n=2,3 do
                if n>2 then imgui.SameLine(); end
                local picked=state.guideDemoRow==row[1] and state.guideDemoSlot==n;
                local txt=(picked and '[ SELECTED ] ' or '')..row[n]..'##guide_'..row[1]..n;
                local p=imgui.GetCursorScreenPos and {pair(imgui.GetCursorScreenPos())} or nil;
                if imgui.Button(txt,{145,32}) then
                    state.guideDemoRow=row[1]; state.guideDemoSlot=n; state.guideDemoAt=os.clock();
                end
                if picked and state.motionEnabled and p and type(p[1])=='number' and type(p[2])=='number'
                    and type(imgui.GetWindowDrawList)=='function' and type(imgui.GetColorU32)=='function' then
                    pcall(function()
                        local draw=imgui.GetWindowDrawList();
                        if type(draw.AddRect)=='function' then
                            local k=.35+.2*math.sin(os.clock()*3);
                            draw:AddRect({p[1]+1,p[2]+1},{p[1]+144,p[2]+31},imgui.GetColorU32({.95,.75,.38,k}),3,0,1);
                        end
                    end);
                end
            end
        end
        if step==3 then
            imgui.Text('Preview mode: '..state.guideDemoMode..' (your saved setting is unchanged)');
            if imgui.Button('Try Hold##guide_hold') then state.guideDemoMode='Hold'; end
            imgui.SameLine(); if imgui.Button('Try Toggle##guide_toggle') then state.guideDemoMode='Toggle'; end
        elseif step==4 then
            imgui.Text('Example: Book 1 / 20   |   Macro set 1 / 10   |   StateBar: PDT');
        else
            imgui.Text('Preview selection: '..(state.guideDemoRow=='CTRL' and 'Upper' or 'Lower')..' - '..(state.guideDemoRow=='CTRL' and (state.guideDemoSlot==2 and 'Flash' or 'Provoke') or (state.guideDemoSlot==2 and 'Cure III' or 'Protect')));
        end
        imgui.Separator();
        if step>1 then
            if imgui.Button('Back##guide_back') then state.guideStep=step-1; end
            imgui.SameLine();
        end
        if step<#GUIDE_STEPS then
            if imgui.Button('Next##guide_next') then state.guideStep=step+1; end
        else
            if imgui.Button('Finish##guide_finish') then state.guideOpen=false; end
        end
        imgui.SameLine();
        if imgui.Button('Close guide##guide_close') then state.guideOpen=false; end
    end
    imgui.End();
    if not opened[1] then state.guideOpen=false; end
end

-- DirectInput scancodes: 1..0 (2..11) and F1..F10 (59..68).
-- Keyboard overrides remain OFF until explicit activation. Native FFXI chat/edit focus
-- cannot yet be identified reliably in VanaCore. Warn in UI before enabling.
local function mapped_key(key)
    if type(key)~='number' then return nil,nil; end
    if state.mappingMode=='numbers' or state.mappingMode=='functions' then
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
local function statebar_input_ready()
    return state.statebarEnabled and state.statebarHotkeysEnabled and state.allowAllClicks
        and state.profileReady and state.phase>=4 and #state.names==20;
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
    if state.guideOpen then return; end
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
    if state.guideOpen then return; end -- No real set/page actions during a tutorial.
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
        if state.echoLock then
            local word=state.navToggleActive and 'locked' or 'unlocked';
            if state.navToggleActive and type(chat.color1)=='function' then local ok,coloured=pcall(chat.color1,76,word); if ok then word=coloured; end end
            print(chat.header(addon.name)..'Macros '..word);
        end
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
-- StateBar has its own explicit keyboard switch; native connection is still required.
-- Only active main shortcuts and enabled navigation reserve keys against it.
local function statebar_hotkey_slot(code)
    if not statebar_input_ready() or modifier_down() then return nil; end
    if shortcuts_active() and mapped_key(code) then return nil; end
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
    if not shortcuts_active() and not statebar_input_ready() and next(state.suppressed)==nil then return; end
    local ptr=ffi.cast('uint8_t*',e.data_raw);
    local size=type(e.size)=='number' and e.size or 256;
    local keys={};
    if state.mappingMode=='split' or state.mappingMode=='custom' then
        for _,code in ipairs(state.directKeys) do if code>0 then keys[code]=true; end end
    else
        for i=1,10 do keys[state.mappingMode=='numbers' and (i==10 and 11 or i+1) or 58+i]=true; end
    end
    if state.statebarEnabled and state.statebarHotkeysEnabled then
        for _,code in pairs(state.statebarHotkeys) do if code>0 then keys[code]=true; end end
    end
    for code,_ in pairs(state.suppressed) do keys[code]=true; end
    for code,_ in pairs(keys) do
        -- If key_data misses a release, the physical state is authoritative.
        -- Clear captured direct keys as well as StateBar keys before suppression.
        if code<size and state.suppressed[code] and ptr[code]==0 then
            state.suppressed[code]=nil; state.held[code]=nil;
        end
        if code<size and statebar_hotkey_slot(code) then
            local down=ptr[code]~=0;
            if down and not state.held[code] then
                state.held[code]=true; state.suppressed[code]=true;
                request_statebar(statebar_hotkey_slot(code));
            elseif not down then
                state.held[code]=nil; state.suppressed[code]=nil;
            end
        end
        if code<size and (state.suppressed[code] or statebar_hotkey_slot(code)~=nil or (shortcuts_active() and not modifier_down() and mapped_key(code)~=nil)) then ptr[code]=0; end
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
        if n and n==math.floor(n) and n>=1 and n<=BOOK_COUNT then
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
    elseif cmd=='guide' then open_guide()
    elseif cmd=='settings' then state.showTests=true
    elseif cmd=='closesettings' then state.showTests=false
    elseif cmd=='help' then
        say('/decker settings - open Settings | /decker closesettings - close Settings | /decker guide - simulated tutorial',true);
        say('/decker show | hide | toggle - macro HUD visibility | /decker connect - connect native macros',true);
        say('/decker keysoff - disable main and StateBar hotkeys | /decker navoff - disable navigation',true);
    elseif cmd=='connect' then connect_macros()
    elseif cmd=='scan' then scan()
    elseif cmd=='pointers' then pointer_check()
    elseif cmd=='show' then state.visible=true; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; state.hudForceReveal=true
    elseif cmd=='hide' then state.visible=false; state.showTests=false
    elseif cmd=='toggle' then state.visible=not state.visible; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; state.hudForceReveal=true
    elseif cmd=='keysoff' then state.statebarHotkeysEnabled=false; state.keybinds=false; state.acknowledgeKeys=false; state.savedKeybinds=false; state.savedAck=false; save_display(); state.held={}; say('Keyboard overrides disabled; captured keys release on key-up.')
    else say('/decker help | settings | closesettings | connect | show | hide | toggle | keysoff | book N | setlabel N',true); end
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
        local versions=('Installed: v%s | %s channel: v%s'):format(addon.version,updater.channel,manifest.version);
        updater.status=update_newer(manifest.version,addon.version) and ('Update available. '..versions) or manifest.version==addon.version and ('Up to date. '..versions) or ('No newer update. '..versions);
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
        local flags=state.statebarLocked and (ImGuiWindowFlags_NoMove or 4) or 0;
        local count=#state.statebarSlots;
        if count>0 then
            local sw=math.floor(100*state.statebarScale);
            local width=state.statebarVertical and (sw+32) or (count*sw+math.max(0,count-1)*8+32);
            local sh=math.floor(40*state.statebarScale);
            if not glass_available() then sh=math.max(sh,(imgui.GetTextLineHeight and imgui.GetTextLineHeight() or 20)*2+8); end
            local footer=state.showTests and 50 or 16;
            local height=state.statebarVertical and (count*(sh+4)+footer) or (sh+footer);
            size_window('statebar',width,height);
            pin_window('statebar',state.statebarLocked);
            local barColours,barVars=push_glass_background(state.statebarOpacity);
            if imgui.Begin('###DeckerStateBar',{true},flags+(ImGuiWindowFlags_NoTitleBar or 1)+scrollbar_flags()) then
                remember_window('statebar',state.statebarLocked);
                for i,b in ipairs(state.statebarSlots) do
                    local idx=(b.row=='ALT' and 10 or 0)+b.slot;
                    local name=b.label and b.label~='' and b.label or b.source=='command' and (b.command or 'Configure command') or (state.names[idx] or 'Unassigned');
                    local key=DIRECT_NAMES[state.statebarHotkeys[i] or 0];
                    local caption=name..(key and key~='None' and ('\n'..key) or '');
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
                    local custom=glass_available(); local x,y;
                    if custom then x,y=pair(imgui.GetCursorScreenPos()); custom=x~=nil; end
                    local sbPressed=imgui.Button((custom and '' or caption)..'##statebar'..i,{sw,sh});
                    if custom then
                        local ok,err=pcall(function() draw_glass_text(imgui.GetWindowDrawList(),name,x,y,sw,sh,key~='None' and key or '',false,state.statebarScale); end);
                        if not ok then glass.custom=false; glass.diagnostic='StateBar draw fallback: '..tostring(err); end
                    end
                    if imgui.IsItemHovered and imgui.SetTooltip and imgui.IsItemHovered() then
                        local action=b.source=='command' and (b.command or '') or ('Current book/set: '..b.row..' '..tostring(b.slot==10 and 0 or b.slot));
                        local behaviour=b.kind=='utility' and 'Utility: one-off action; keeps current State highlight.' or 'State: stays highlighted after activation; gear is not verified.';
                        imgui.SetTooltip(name..'\n'..action..'\nKey: '..(key or 'None')..'\n'..behaviour);
                    end
                    if sbColours then imgui.PopStyleColor(3); end
                    if sbPressed then
                        request_statebar(i);
                    end
                end
                if state.showTests and imgui.Button('Settings##statebarconfig') then state.settingsTab='StateBar'; end
            end
            imgui.End();
            pop_glass_background(barColours,barVars);
        end
    end
    local activeNav=state.navKeysEnabled and (state.stickyNavigation and state.navToggleActive or (not state.stickyNavigation and state.navModifierHeld));
    -- Explicit wake requests must not be consumed by the 0s mode before interaction.
    if state.hudForceReveal then state.hudImmediateHide=false; end
    -- With 0s selected, release of active Toggle navigation is an end-of-activity event.
    if state.hudWasActive and not activeNav and state.autoHide and state.autoHideDelay==0 then
        state.hudImmediateHide=true;
    end
    if activeNav and not state.hudWasActive then state.hudLastActivity=os.clock(); end
    state.hudWasActive=activeNav;
    -- Timed options keep the existing startup grace and idle behaviour.
    -- 0s is event-based: do not hide on startup or before the first usable action.
    if not state.hudReadySince then state.hudReadySince=os.clock(); end
    -- Hold visibility follows the physical key immediately; timers belong to Toggle.
    local holdMode=state.navKeysEnabled and not state.stickyNavigation;
    local holdHidden=holdMode and not state.navModifierHeld;
    local timedHide=state.autoHideDelay>0 and (os.clock()-state.hudLastActivity)>=state.autoHideDelay and (os.clock()-state.hudReadySince)>=10;
    local instantHide=state.autoHideDelay==0 and state.hudImmediateHide;
    local idleHidden=not holdMode and state.autoHide and not state.hudForceReveal and not activeNav and not state.showTests and (instantHide or timedHide);
    state.hudForceReveal=false;
    -- /decker settings and /decker show recover the HUD without a permanent window.
    if state.visible and idleHidden and state.autoHideMode=='collapse' then
        size_window('collapsed',88,40);
        pin_window('collapsed',state.positionLocked);
        if imgui.Begin('###DeckerCollapsed',{true},(ImGuiWindowFlags_NoTitleBar or 1)+(state.positionLocked and (ImGuiWindowFlags_NoMove or 4) or 0)+scrollbar_flags()) then
            remember_window('collapsed',state.positionLocked);
            if imgui.Button('Decker##recovery') then state.showTests=true; end
        end
        imgui.End();
    end
    if state.visible and not holdHidden and not idleHidden then
    local hudw=math.floor(10*state.hudWidth*state.scale+9*8+32);
    size_window('hud',hudw,math.floor(2*state.hudHeight*state.scale+90));
    pin_window('hud',state.positionLocked);
    -- Explicit open-state table keeps flags in the host binding's three-argument Begin overload.
    -- Hidden IDs preserve window identity; the single content heading is drawn below.
    -- Apply to the HUD only; Settings stays fully opaque.
    local hudColours,hudVars=push_glass_background(state.outerOpacity);
    if imgui.Begin('###DeckerMain',{true},(ImGuiWindowFlags_NoTitleBar or 1)+(state.positionLocked and (ImGuiWindowFlags_NoMove or 4) or 0)+scrollbar_flags()) then
        remember_window('hud',state.positionLocked);
        -- VanaCore ImGui positions may be math-backed vectors, not Lua arrays.
        -- Avoid numeric indexing of GetWindowPos results until its ABI is verified.

        -- Fixed header columns keep status length from moving the key details.
        local book=state.manualBook or 1;
        local title=state.bookAliases[book] or state.bookNames[book] or '';
        if #title>15 then title=title:sub(1,15)..'...'; end
        local header=('DECKER | Book %d%s (#%d)'):format(book,title~='' and (' - '..title) or '',state.trackedSet or 1);
        local function header_width(text)
            if imgui.CalcTextSize then local ok,a,b=pcall(imgui.CalcTextSize,text); if ok then local w=pair(a,b); if w then return w; end end end
            return #text*8;
        end
        local origin=8;
        if imgui.GetCursorPos then local ok,a,b=pcall(imgui.GetCursorPos); if ok then origin=pair(a,b) or origin; end end
        local statusX=origin+header_width('DECKER | Book 20 - WWWWWWWWWWWWWWWWWW (#10)')+14*state.scale;
        local keysX=statusX+header_width('UNLOCKED')+48*state.scale;
        local active=state.navKeysEnabled and (state.stickyNavigation and state.navToggleActive or (not state.stickyNavigation and state.navModifierHeld));
        local status=active and (state.stickyNavigation and 'LOCKED' or 'HELD') or 'UNLOCKED';
        imgui.Text(header);
        if imgui.IsItemHovered and imgui.SetTooltip and imgui.IsItemHovered() then imgui.SetTooltip(book_label(state.manualBook or 1)..(state.trackedSource=='unverified (same names)' and '\nSet selection unverified: native macro names did not change.' or '')); end
        imgui.SameLine(statusX,0);
        local colourStatus=imgui.PushStyleColor and imgui.PopStyleColor and type(ImGuiCol_Text)=='number';
        if colourStatus then imgui.PushStyleColor(ImGuiCol_Text,active and {1,.25,.25,1} or {1,1,1,1}); end
        imgui.Text(status);
        if colourStatus then imgui.PopStyleColor(); end
        imgui.SameLine(keysX,0);
        imgui.Text('Active row: '..(state.navRow=='ALT' and 'Lower' or 'Upper'));
        if #state.names==20 then
            draw_macro_panel();
            draw_row('CTRL',0);
            draw_row('ALT',10);
            if state.allowSwitch then
                if imgui.Button('<##deckprev') then select_page(((state.trackedSet or 1)+8)%10+1); end
                imgui.SameLine(); imgui.Text(('Macro set %d/10'):format(state.trackedSet or 1));
                imgui.SameLine(); if imgui.Button('>##decknext') then select_page((state.trackedSet or 1)%10+1); end
                imgui.SameLine();
                if validaddr(state.addresses.set_book) then
                    if imgui.Button('<##bookprev') then select_native_book(((state.manualBook or 1)+BOOK_COUNT-2)%BOOK_COUNT+1); end
                    imgui.SameLine();
                    local sized=imgui.PushItemWidth and imgui.PopItemWidth;
                    if sized then imgui.PushItemWidth(130*state.scale); end
                    if imgui.BeginCombo('##hudbook',('Book %d/%d'):format(state.manualBook or 1,BOOK_COUNT)) then
                        for number=1,BOOK_COUNT do
                            if imgui.Selectable(book_label(number)..'##hudbookchoice'..number,state.manualBook==number) then select_native_book(number); end
                        end
                        imgui.EndCombo();
                    end
                    if sized then imgui.PopItemWidth(); end
                    imgui.SameLine(); if imgui.Button('>##booknext') then select_native_book((state.manualBook or 1)%BOOK_COUNT+1); end
                    imgui.SameLine();
                end
            end
            if imgui.Button(state.positionLocked and 'Unlock position' or 'Lock position') then state.positionLocked=not state.positionLocked; save_display(); end
            imgui.SameLine(); if imgui.Button('Settings') then state.showTests=not state.showTests; state.hudLastActivity=os.clock(); end
        else
            imgui.Text('Decker is not connected to native macros.');
            if imgui.Button('Connect to in-game macros') then connect_macros(); end
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
    end -- visible macro HUD; Settings is independent
    if state.showTests then
        imgui.SetNextWindowSize({490,370},ImGuiCond_FirstUseEver);
        local thinScroll=type(ImGuiStyleVar_ScrollbarSize)=='number' and imgui.PushStyleVar and imgui.PopStyleVar;
        if thinScroll then imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize,7); end
        local settingsOpen={state.showTests};
        if imgui.Begin('Decker v'..addon.version..' - Settings',settingsOpen,scrollbar_flags()) then
            if imgui.Button('X  Close Settings') then state.showTests=false; end
            imgui.SameLine(); if imgui.Button('Show macros##settings') then state.visible=true; state.hudLastActivity=os.clock(); state.hudForceReveal=true; end
            imgui.SameLine(); if imgui.Button('Interactive guide##settingsguide') then open_guide(); end
            imgui.TextWrapped('Chat commands: /decker settings | guide | show | hide | help');
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
                imgui.TextWrapped('Stable and Development channels are available. Check to see the published version on your selected channel.');
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
                imgui.Text('Selected State highlight colour:');
                for i,name in ipairs({'Green','Blue','Purple','Grey'}) do
                    if imgui.Button((state.statebarTheme==i and '[X] ' or '')..name..'##sbtheme') then state.statebarTheme=i; save_display(); end
                    if i<4 then imgui.SameLine(); end
                end
                if imgui.Button('StateBar smaller') then state.statebarScale=math.max(.7,state.statebarScale-.1); save_display(); end
                imgui.SameLine(); imgui.Text(('%.0f%%'):format(state.statebarScale*100)); imgui.SameLine();
                if imgui.Button('StateBar larger') then state.statebarScale=math.min(1.5,state.statebarScale+.1); save_display(); end
                imgui.TextWrapped('State: a lasting mode, such as PDT or MDT; its button stays highlighted after activation. Utility: a one-off action, such as food or a mount; it leaves your State highlight unchanged. Both run the action you assign. A highlight records your request; it does not verify equipped gear.');
                imgui.Separator();
                imgui.TextWrapped('Each button has an action to run and a separate key to press. Enable StateBar hotkeys to reserve those keys; this switch is independent of the main macro keyboard switch. Disable before typing or editing macros.');
                local sbhot={state.statebarHotkeysEnabled};
                if imgui.Checkbox('Enable StateBar hotkeys',sbhot) then state.statebarHotkeysEnabled=sbhot[1]; save_display(); end
                imgui.Text('StateBar keyboard: '..(not state.statebarHotkeysEnabled and 'OFF' or not state.statebarEnabled and 'Enable StateBar first' or statebar_input_ready() and 'READY' or 'WAITING - Connect to in-game macros'));
                if not state.allowAllClicks and imgui.Button('Connect to in-game macros##statebarconnect') then connect_macros(); end
                imgui.TextWrapped(state.clickSummary);
                for i,b in ipairs(state.statebarSlots) do
                    imgui.Separator(); imgui.Text('Slot '..i);
                    local label={b.label or ''}; if imgui.InputText('Label (optional)##sblabel'..i,label,25) then b.label=label[1]:gsub('[%c#]',''):sub(1,24); save_display(); end
                    if imgui.BeginCombo('Highlight behaviour##sbtype'..i,b.kind=='utility' and 'Utility: one-off action' or 'State: keep highlighted') then
                        for _,kind in ipairs({'state','utility'}) do if imgui.Selectable(kind=='utility' and 'Utility: food/mount; keep current State highlight' or 'State: PDT/MDT; keep this button highlighted',b.kind==kind or (b.kind==nil and kind=='state')) then b.kind=kind; if kind=='utility' and state.statebarSelected==i then state.statebarSelected=0; end; save_display(); end end
                        imgui.EndCombo();
                    end
                    if imgui.BeginCombo('Action type##sbsource'..i,b.source=='command' and 'Single command' or 'Existing FFXI macro') then
                        for _,source in ipairs({'macro','command'}) do if imgui.Selectable(source=='command' and 'Single command' or 'Existing FFXI macro',b.source==source or (b.source==nil and source=='macro')) then b.source=source; save_display(); end end
                        imgui.EndCombo();
                    end
                    if b.source=='command' then
                        local text={b.command or ''};
                        if imgui.InputText('Command##sbcmd'..i,text,241) then b.command=text[1]; if valid_command(b.command) then save_display(); end end
                        if not valid_command(b.command) then imgui.TextWrapped('Use /equipset 1, /lac set PDT, /item "Food" <me>, /ma "Spell" <me>, /ja "Ability" <me> or /mount "Name".'); end
                    end
                    if b.source~='command' then
                    imgui.TextWrapped('FFXI macro source: choose the action from its upper (CTRL) or lower (ALT) row. These are the two native rows, regardless of your Decker key labels.');
                    if imgui.BeginCombo('Macro to run##bar'..i,(b.row=='CTRL' and 'Upper row (CTRL) ' or 'Lower row (ALT) ')..tostring(b.slot==10 and 0 or b.slot)) then
                        for _,row in ipairs({'CTRL','ALT'}) do
                            for slot=1,10 do
                                if imgui.Selectable((row=='CTRL' and 'Upper (CTRL) ' or 'Lower (ALT) ')..tostring(slot==10 and 0 or slot)..' - '..(state.names[(row=='CTRL' and 0 or 10)+slot] or '')..'##barchoice'..i..row..slot,b.row==row and b.slot==slot) then
                                    b.row=row; b.slot=slot; save_display();
                                end
                            end
                        end
                        imgui.EndCombo();
                    end
                    end -- native macro source
                    imgui.Text('Keyboard trigger (optional):');
                    local current=state.statebarHotkeys[i] or 0;
                    if imgui.BeginCombo('Key to press##statebarhotkey'..i,DIRECT_NAMES[current] or 'None') then
                        for _,option in ipairs(DIRECT_KEY_OPTIONS) do
                            local label,code=option[1],option[2];
                            local clash=(code~=0 and ((shortcuts_active() and mapped_key(code)~=nil) or (state.navKeysEnabled and (code==nav_scan() or code==row_key() or NAV_ACTIONS[code]))));
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
                imgui.TextWrapped('StateBar macros use the current book and set. Hotkeys are single keys: letters, F1-F12, number pad, punctuation and editing keys. Ctrl/Alt combinations remain native FFXI controls. Changing State/Utility changes highlighting, not the action.');
            end
            if state.settingsTab=='Appearance' then
            if imgui.CollapsingHeader('Display',ImGuiTreeNodeFlags_DefaultOpen or 32) then
                        local auto={state.autoHide};
            imgui.Text('Character profile: '..(state.profileId or 'waiting for login'));
            if imgui.Button('Unlock HUD for dragging') then state.hudPos=nil; state.positionLocked=false; save_display(); end
            imgui.TextWrapped('Hold mode shows macros while the mod key is down and hides them on release. These inactivity settings apply to Toggle mode.');
            if imgui.Checkbox('Auto-hide macro display (Toggle mode)',auto) then state.autoHide=auto[1]; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; state.hudImmediateHide=false; save_display(); end
            imgui.Text('Hide after activity / inactivity:');
            for _,seconds in ipairs({0,2,5,10,15,30}) do
                if seconds~=0 then imgui.SameLine(); end
                local duration=seconds==0 and 'Immediately (0s)' or (seconds..'s');
                if imgui.Button((state.autoHideDelay==seconds and '[' or '')..duration..(state.autoHideDelay==seconds and ']' or '')..'##hide'..seconds) then state.autoHideDelay=seconds; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; state.hudImmediateHide=false; save_display(); end
            end
            imgui.TextWrapped('0s hides just after a macro or StateBar action, or when Toggle navigation ends. It never hides before your first action. The 2-30s choices retain inactivity timing.');
            imgui.Text('When the macros auto-hide:');
            if imgui.Button('Hide completely'..(state.autoHideMode=='hide' and ' [selected]' or '')) then state.autoHideMode='hide'; save_display(); end
            imgui.SameLine(); if imgui.Button('Keep small Decker button'..(state.autoHideMode=='collapse' and ' [selected]' or '')) then state.autoHideMode='collapse'; save_display(); end
            imgui.TextWrapped('First-time setup: select Hide completely only after Decker is working and you know how to reopen it with /decker settings or /decker show.');
            imgui.TextWrapped('/decker settings opens Settings. /decker show reveals macros. /decker hide hides macros. /decker help lists commands.');
            local motion={state.motionEnabled};
            if imgui.Checkbox('Subtle animations (uncheck for reduced motion)',motion) then state.motionEnabled=motion[1]; save_display(); end
            imgui.TextWrapped('Animation is visual-only: selection glow and a brief confirmation line after a macro request. Disabling motion leaves the normal selected/pressed highlights.');
            local scroll={state.showScrollbars};
            if imgui.Checkbox('Show scrollbars',scroll) then state.showScrollbars=scroll[1]; save_display(); end
            imgui.TextWrapped('Scrollbar visibility applies to the macro HUD, StateBar and Settings. Mouse-wheel scrolling remains available.');
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
            imgui.Text('Last-used macro highlight colour:');
            if imgui.Button('Classic') then state.theme=1; save_display(); end
            imgui.SameLine(); if imgui.Button('Blue') then state.theme=2; save_display(); end
            imgui.SameLine(); if imgui.Button('Purple') then state.theme=3; save_display(); end
            imgui.SameLine(); if imgui.Button('Minimal') then state.theme=4; save_display(); end
            if imgui.Button('Display smaller') then state.scale=math.max(.7,state.scale-.1); save_display(); end
            imgui.SameLine(); imgui.Text(('Scale %.0f%%'):format(state.scale*100)); imgui.SameLine();
            if imgui.Button('Display larger') then state.scale=math.min(1.5,state.scale+.1); save_display(); end
            imgui.Text(('Macro button width: %d (before display scaling)'):format(state.hudWidth));
            if imgui.Button('Narrower buttons') then state.hudWidth=math.max(80,state.hudWidth-8); save_display(); end
            imgui.SameLine(); if imgui.Button('Wider buttons') then state.hudWidth=math.min(140,state.hudWidth+8); save_display(); end
            local ck={state.compactKeys};
            if imgui.Checkbox('Short key labels (F1 instead of CTRL 1 | F1)',ck) then state.compactKeys=ck[1]; save_display(); end
            imgui.Separator();
            end
            end -- General / Appearance tab
            if state.settingsTab=='Controls' then
                imgui.Text('KEYS AND MACRO CONTROLS');
                if imgui.Button('Connect to in-game macros##quick') then connect_macros(); end
                if state.allowAllClicks and state.phase>=4 and #state.names==20 then
                    local enabled={shortcuts_active()};
                    if imgui.Checkbox('Use my assigned keys',enabled) then
                        state.keybinds=enabled[1]; state.savedKeybinds=enabled[1];
                        state.acknowledgeKeys=enabled[1]; state.savedAck=enabled[1];
                        state.held={}; save_display();
                    end
                    imgui.TextWrapped('Uses the keys in your selected layout or custom slots. Disable before typing or editing macros.');
                else
                    imgui.TextWrapped('Connect to in-game macros to use your assigned keys. Enabled by default after connection; untick it if preferred.');
                end
                if shortcuts_active() then
                    local layout=({numbers='Both rows: 1-0',functions='Both rows: F1-F10',split='F1-F10 / 1-0',custom='Custom keys in use'})[state.mappingMode];
                    imgui.Text('Key layout: '..(layout or 'Both rows: 1-0'));
                    if not state.keyAssignmentPage then
                        for _,mode in ipairs({{'numbers','Both rows: 1-0'},{'functions','Both rows: F1-F10'},{'split','F1-F10 / 1-0'},{'custom','Custom keys (saved slots)'}}) do
                            if imgui.Button((state.mappingMode==mode[1] and '[X] ' or '')..mode[2]) then
                                state.mappingMode=mode[1];
                                if mode[1]=='split' then state.directKeys=default_direct_keys(); end
                                state.held={}; save_display();
                            end
                        end
                        if imgui.Button('Customise keys for both rows') then state.keyAssignmentPage=true; end
                        if state.mappingMode=='numbers' or state.mappingMode=='functions' then
                            imgui.TextWrapped('Both rows share the same keys. Use your mod key, then the switch row key to select which row they run.');
                            imgui.Text('Active row: '..(state.navRow=='ALT' and 'LOWER' or 'UPPER')..' | Mod key: '..state.navModifier..' | Switch row: '..state.rowSwitchKey);
                        end
                        if imgui.CollapsingHeader('Advanced keys') then
                            imgui.Text('Navigator');
                            if imgui.BeginCombo('Macro visibility mod key',state.navModifier) then
                                for _,choice in ipairs({'RSHIFT','LSHIFT','END','HOME'}) do
                                    if imgui.Selectable(choice,state.navModifier==choice) then
                                        state.navModifier=choice; state.navKeysEnabled=false; state.savedNavEnabled=false; nav_clear(); save_display();
                                    end
                                end
                                imgui.EndCombo();
                            end
                            imgui.TextWrapped('Shows the macros and activates arrow navigation. Default: Right Shift.');
                            if (state.navModifier=='RSHIFT' or state.navModifier=='LSHIFT') and imgui.CollapsingHeader('Windows Shift shortcut help') then
                                imgui.TextWrapped('Five Shift presses can open Windows Sticky Keys. In Windows Settings, search Sticky keys and turn off its keyboard shortcut. You can also choose HOME as your Decker mod key.');
                            end
                            if imgui.BeginCombo('Switch row key',state.rowSwitchKey) then
                                for _,choice in ipairs({'END','HOME','INSERT','DELETE','N','F9','F10','F11','F12'}) do
                                    if imgui.Selectable(choice,state.rowSwitchKey==choice) then state.rowSwitchKey=choice; nav_clear(); save_display(); end
                                end
                                imgui.EndCombo();
                            end
                            imgui.TextWrapped('While the mod is active, this key or Space switches between upper and lower rows.');
                            if imgui.BeginCombo('Macro mod behaviour',state.stickyNavigation and 'Press key once (Toggle)' or 'Hold key pressed down') then
                                if imgui.Selectable('Press key once (Toggle)',state.stickyNavigation) then state.stickyNavigation=true; nav_clear(); save_display(); end
                                if imgui.Selectable('Hold key pressed down',not state.stickyNavigation) then state.stickyNavigation=false; nav_clear(); save_display(); end
                                imgui.EndCombo();
                            end
                            imgui.TextWrapped(state.stickyNavigation and 'Tap the mod key to activate; tap again to finish.' or 'Hold the mod key to activate; release to finish.');
                            local nav={state.navKeysEnabled};
                            if imgui.Checkbox('Enable hotkeys##navigation',nav) then state.navKeysEnabled=nav[1]; state.savedNavEnabled=nav[1]; nav_clear(); save_display(); end
                            imgui.TextWrapped('Enables the mod key, row switching and arrows. Left/Right selects; Up/Down changes set; Enter runs the selection.');
                            local echo={state.echoLock};
                            if imgui.Checkbox('Echo macro visibility on/off to chat',echo) then state.echoLock=echo[1]; save_display(); end
                        end
                    end
                    if not state.keyAssignmentPage and imgui.CollapsingHeader('Cooldown text colours') then
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
                    end -- cooldown options
                    if state.keyAssignmentPage then
                        if imgui.Button('Back to key layouts') then state.keyAssignmentPage=false; end
                        imgui.Text('Custom keys for both rows');
            imgui.Text('Upper row - CTRL macros (slots 1-10)');
            imgui.TextWrapped('Choose a key for each slot. Changing a slot selects Custom keys and replaces the preset layout. Use None to leave a slot unassigned.');
            for i=1,20 do
                if i==11 then imgui.Separator(); imgui.Text('Lower row - ALT macros (slots 1-10)'); end
                local slot=(i-1)%10+1;
                local code=state.directKeys[i] or 0;
                local name=DIRECT_NAMES[code] or 'None';
                if imgui.BeginCombo(('Slot %d##direct%d'):format(slot,i),name) then
                    for _,choice in ipairs(DIRECT_KEY_OPTIONS) do
                        local candidate=choice[2];
                        if imgui.Selectable(choice[1]..'##directchoice'..i..'_'..candidate,code==candidate) then
                            local statebarClash=false;
                            for _,key in pairs(state.statebarHotkeys) do if candidate~=0 and key==candidate then statebarClash=true; end end
                            if not direct_conflict(candidate,i) and not statebarClash then
                                state.directKeys[i]=candidate; state.mappingMode='custom'; state.keySummary='Custom keys in use'; state.held={}; save_display();
                            else
                                state.keySummary='Binding conflict: key already used or reserved by navigation';
                            end
                        end
                    end
                    imgui.EndCombo();
                end
            end
            imgui.TextWrapped(state.keySummary);
            if imgui.Button('Reset to F1-F10 / 1-0 layout') then
                state.directKeys=default_direct_keys(); state.mappingMode='split'; state.keySummary='F1-F10 / 1-0 layout';
                state.held={}; save_display();
            end
                    end -- custom key page
                else
                    imgui.TextWrapped('Key layout and custom key controls become available after connecting and enabling Use my assigned keys.');
                end -- key controls enabled
            end -- Controls tab
            if state.settingsTab=='General' and imgui.CollapsingHeader('Book and Set controls') then
                imgui.TextWrapped('20 macro books, each containing 10 macro sets. Equipment sets are separate saved gear presets, not additional macro books.');
                if state.allowSwitch and validaddr(state.addresses.set_book) then
                    if imgui.BeginCombo('In-game macro book',book_label(state.manualBook or 1)) then
                        for book=1,BOOK_COUNT do if imgui.Selectable(book_label(book)..'##nativebook'..book,state.manualBook==book) then select_native_book(book); end end
                        imgui.EndCombo();
                    end
                else imgui.TextWrapped('Connect to in-game macros to switch books.'); end
                local book=state.manualBook or 1;
                local alias={state.bookAliases[book] or ''};
                if imgui.InputText('Decker name for this book',alias,33) then state.bookAliases[book]=alias[1]~='' and alias[1]:gsub('[%c#]',''):sub(1,32) or nil; save_display(); end
                imgui.TextWrapped('Optional display label only. Leave blank to use the imported in-game title.');
                if imgui.CollapsingHeader('Import saved in-game book names') then
                    local folder={state.bookPath};
                    if imgui.InputText('This character macro folder',folder,1025) then state.bookPath=folder[1]; save_display(); end
                    imgui.TextWrapped('Paste the exact FFXI USER character folder containing mcr.ttl. Reads titles only; no game files are changed.');
                    if imgui.Button('Read or refresh book names') then import_book_titles(); end
                    imgui.TextWrapped(state.bookNameStatus);
                end
                imgui.TextWrapped('Book selection changes the in-game book. Titles come from saved files, not a live getter. Select a set below after switching books.');
                imgui.TextWrapped(state.switchSummary);
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
                imgui.TextWrapped('3. Open Settings > Controls. Choose your Macro visibility mod key (default Right Shift).')
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
        if thinScroll then imgui.PopStyleVar(); end
        if not settingsOpen[1] then state.showTests=false; end
    end
    guide_draw(); -- Independent of Settings and HUD visibility; preview never invokes native calls.
end);
