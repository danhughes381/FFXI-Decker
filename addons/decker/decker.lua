-- Decker 1.50.66-dev: resolve macro commands when the tracked page is stale.
-- Native macro calls and opt-in DirectInput keyboard hooks; no original HUD patches.
-- CAUTION: Opt-in native FFI call may crash the FFXI process if signatures/API differ.
addon.name = 'Decker';
addon.author = 'Mutant X';
addon.version = '1.50.66-dev';
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
-- Shared choices keep UI, saved settings, capture and conflict checks consistent.
local NAV_KEY_OPTIONS={'RSHIFT','LSHIFT','RCTRL','LCTRL','RALT','LALT','NUMPAD1','END','HOME','INSERT','DELETE','PAGEUP','PAGEDOWN','CAPSLOCK','SCROLLLOCK','PAUSE','N','F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12'};
local NAV_KEYS={RSHIFT=54,LSHIFT=42,RCTRL=157,LCTRL=29,RALT=184,LALT=56,NUMPAD1=79,END=207,HOME=199,INSERT=210,DELETE=211,PAGEUP=201,PAGEDOWN=209,CAPSLOCK=58,SCROLLLOCK=70,PAUSE=197,N=49,F1=59,F2=60,F3=61,F4=62,F5=63,F6=64,F7=65,F8=66,F9=67,F10=68,F11=87,F12=88};
local ROW_KEYS=NAV_KEYS;
local DIRECT_NAMES={}; local DIRECT_CODES={};
for _,item in ipairs(DIRECT_KEY_OPTIONS) do DIRECT_NAMES[item[2]]=item[1]; DIRECT_CODES[item[1]]=item[2]; end
local function default_direct_keys()
    local t={}; for i=1,10 do t[i]=58+i; t[10+i]=i==10 and 11 or i+1; end; return t;
end
state.directKeys=default_direct_keys();
state.settingsTab='Controls'; state.statebarEnabled=false; state.statebarVertical=false; state.statebarLocked=false; state.statebarAlways=true; state.statebarScale=1.0; state.statebarOpacity=1; state.statebarTheme=1; state.statebarVisibility='always'; state.statebarSlots={{row='CTRL',slot=1},{row='CTRL',slot=2},{row='CTRL',slot=3},{row='ALT',slot=1}};
state.statebarOpacity=1.0; state.statebarTheme=1; state.statebarVisibility='always'; state.profileDiagnostic='Not checked'; state.statebarSelected=0;
state.statebarHotkeys={}; state.statebarHotkeysEnabled=false; state.statebarActionMode='current';
state.classic75=false; state.classicOrder={1,2,3,4,5,6};
state.statebarLabelSize=0; state.statebarKeySize=10;
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
state.windowPositions={}; state.layoutDirtyAt=nil;
state.autoConnect=false; state.autoConnectPending=false; state.autoConnectAt=0; state.autoConnectAttempted=false;
local analytics; -- forward-declared for character lifecycle cleanup
state.cooldownAutoNames=true;
local profileDefaults=copy_value(state);
local sectionKeys={
    Controls={'mappingMode','directKeys','navModifier','rowSwitchKey','stickyNavigation','navKeysEnabled','keybinds','acknowledgeKeys','savedNavEnabled','savedKeybinds','savedAck','echoLock'},
    Appearance={'showScrollbars','outerOpacity','panelOpacity','buttonOpacity','macroFont','macroFontSize','scale','theme','hudWidth','hudHeight','compactKeys','hudOpacity','autoHide','autoHideDelay','autoHideMode','positionLocked','motionEnabled'},
    StateBar={'classic75','classicOrder','statebarEnabled','statebarVertical','statebarLocked','statebarAlways','statebarScale','statebarLabelSize','statebarKeySize','statebarOpacity','statebarTheme','statebarVisibility','statebarSelected','statebarHotkeys','statebarHotkeysEnabled','statebarSlots'},
    General={'bookNames','bookAliases','bookPath','bookNameStatus','manualBook','trackedSet','cooldownEnabled','cooldownBindings','cooldownAutoNames','autoConnect'},
};
-- First-install defaults also form the profile-isolation boundary.
profileDefaults.autoHide=false; profileDefaults.autoHideMode='hide';
profileDefaults.cooldownEnabled=true; profileDefaults.cooldownBindings={};
local function direct_conflict(code,index)
    if code==0 then return false; end
    if state.mappingMode=='split' or state.mappingMode=='custom' or index>0 then for i,k in ipairs(state.directKeys) do if i~=index and k==code then return true; end end end
    -- Avoid keys reserved for navigation while custom navigation is enabled.
    local reserved={ [203]=true,[205]=true,[200]=true,[208]=true,[28]=true,[1]=true,[57]=true };
    if state.navKeysEnabled and (reserved[code] or code==NAV_KEYS[state.navModifier] or code==ROW_KEYS[state.rowSwitchKey]) then return true; end
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
state.cooldownEnabled=true;
state.cooldownBindings={};
state.macroLayouts={}; state.macroGuards={}; state.guardEditing=false; state.pendingMacroConfirm=nil; state.confirmingMacro=false;
state.layoutEditing=false; state.layoutDraft=nil; state.layoutDraftKey=nil; state.layoutSelected=nil; state.layoutDragging=nil; state.layoutStatus=nil;
state.cooldownDrafts={selected=1,text=''};
local selector;
local cooldown = {};
function cooldown.page()
    if not state.profileReady or state.phase<4 or state.pendingRefreshFrames>0
        or state.awaitingPageFingerprint or state.trackedSource=='unverified (same names)'
        or not state.previousFingerprint or state.nameCount==0 then return nil; end
    return state.manualBook..'.'..state.trackedSet..'.', state.previousFingerprint;
end
function cooldown.macro_signature(index,fallback)
    if selector and selector.actions then
        local commands=selector.actions(index);
        if commands then
            local signature=table.concat(commands,'\031');
            if signature:gsub('\031','')~='' then return signature; end
        end
    end
    return fallback;
end
function cooldown.binding(page,fingerprint,index)
    if not page then return nil; end
    local signature=cooldown.macro_signature(index,fingerprint);
    if signature then
        -- Follow an explicitly mapped macro when its command contents move to
        -- another slot in the same book/set.
        for slot=1,20 do
            local candidate=state.cooldownBindings[page..slot];
            if candidate and candidate.fingerprint==signature then return candidate; end
        end
    end
    local binding=state.cooldownBindings[page..index];
    -- Keep pre-command-fingerprint mappings readable until their macro changes.
    return binding and binding.fingerprint==fingerprint and binding or nil;
end
function cooldown.encode(fingerprint)
    return (fingerprint:gsub('.',function(byte) return ('%02x'):format(byte:byte()); end));
end
function cooldown.decode(value)
    local kind,id,encoded=value:match('^(%l+):(%d+):([0-9a-f]+)$');
    if (kind~='spell' and kind~='ability') or #encoded>800 or #encoded%2~=0 then return nil; end
    local fingerprint=encoded:gsub('..',function(pair) return string.char(tonumber(pair,16)); end);
    local _,separators=fingerprint:gsub('\031','');
    if separators~=19 and separators~=5 then return nil; end
    return {kind=kind,id=tonumber(id),fingerprint=fingerprint};
end
-- Recasts are display observations, not proof that the macro executed a cast.
local recastObserver={observed={},events={},pending={}};
-- Read-only fallback for exact-name labels. Macro command parsing is preferred.
local inferredCooldown={};
function cooldown.infer(name)
    if not state.cooldownAutoNames or type(name)~='string'
        or #name<2 or #name>32 or name:find('[^%w %-%._]') then return nil; end
    local clean=name:match('^%s*(.-)%s*$') or name;
    if inferredCooldown[clean] then return inferredCooldown[clean]; end
    local spaced=clean:gsub('(%l)(%u)','%1 %2');
    local title=spaced:lower():gsub('(%a)([%w_]*)',function(first,rest) return first:upper()..rest; end);
    local compact=clean:lower():gsub('[^%w]','');
    local resourceName=(compact=='shieldbash' or compact=='shldbash') and 'Shield Bash' or title;
    local ok,binding=pcall(function()
        local res=AshitaCore:GetResourceManager();
        if not res then return nil; end
        local spell=res:GetSpellByName(clean,0);
        if not spell and title~=clean then spell=res:GetSpellByName(title,0); end
        if spell and type(spell.Index)=='number' and spell.Index>=0 then
            return {kind='spell',id=spell.Index,inferred=true};
        end
        local ability=res:GetAbilityByName(clean,0);
        if not ability and resourceName~=clean then ability=res:GetAbilityByName(resourceName,0); end
        if ability and type(ability.RecastTimerId)=='number' and ability.RecastTimerId>=0 then
            return {kind='ability',id=ability.RecastTimerId,inferred=true};
        end
    end);
    if ok and binding then inferredCooldown[clean]=binding;return binding; end
end
local function cooldown_recast(binding)
    if not binding or not state.cooldownEnabled then return nil; end
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
    if not ok or type(remaining)~='number' or remaining<0 then return nil; end
    return remaining;
end
function cooldown.label(seconds)
    if type(seconds)~='number' then return nil; end
    if seconds<=0 then return 'READY'; end
    return tostring(math.ceil(seconds))..'s';
end
function cooldown.fraction(seconds,highest)
    if type(seconds)~='number' or seconds<=0 then return 0; end
    if type(highest)~='number' or highest<=0 then return 1; end
    return math.max(0,math.min(1,seconds/highest));
end
function cooldown.reset_observer()
    recastObserver.observed={};recastObserver.events={};recastObserver.pending={};
end
function cooldown.note_request(row,slot)
    local page,fp=cooldown.page();
    local ix=(row=='ALT' and 10 or 0)+slot;
    local b=cooldown.binding(page,fp,ix);
    if not b then return nil; end
    local key=(page or '')..ix..':'..b.kind..':'..b.id;
    recastObserver.pending[key]={at=os.time(),profile=state.profileId,row=row,slot=slot};
    return key;
end
function cooldown.observe(key,seconds)
    if type(key)~='string' or type(seconds)~='number' then return nil; end
    local old=recastObserver.observed[key];
    recastObserver.observed[key]=seconds;
    if old and old>0 and seconds==0 then
        recastObserver.events[#recastObserver.events+1]={name=key,kind='RECAST READY'};
        if #recastObserver.events>8 then table.remove(recastObserver.events,1); end
        return 'recast ready';
    end
    if old and old==0 and seconds>0 then
        local pending=recastObserver.pending[key];recastObserver.pending[key]=nil;
        if pending and pending.profile==state.profileId
          and os.time()-pending.at>=0 and os.time()-pending.at<=10 then
            if analytics and analytics.note_recast then analytics.note_recast(pending.row,pending.slot); end
            return 'recast started after Decker request (cast result unknown)';
        end
        return 'recast started (cast result unknown)';
    end
    return nil;
end
function cooldown.alerts() return recastObserver.events; end
-- Persist deliberate key preferences, not execution gates temporarily cleared by Connect/reload.
local function macro_layout_key()
    return tostring(state.manualBook or 1)..'.'..tostring(state.trackedSet or 1);
end
local function macro_guard_key(index,book,set)
    return tostring(book or state.manualBook or 1)..'.'..tostring(set or state.trackedSet or 1)..'.'..tostring(index);
end
local function macro_guarded(index,book,set)
    return state.macroGuards[macro_guard_key(index,book,set)]==true;
end
local function valid_macro_layout(order)
    if type(order)~='table' or #order~=20 then return false; end
    local seen={};
    for i=1,20 do
        local n=order[i];
        if type(n)~='number' or n~=math.floor(n) or n<1 or n>20 or seen[n] then return false; end
        seen[n]=true;
    end
    return true;
end
local function copy_macro_layout(order)
    local result={}; for i=1,20 do result[i]=order[i]; end; return result;
end
local function identity_macro_layout()
    local order={}; for i=1,20 do order[i]=i; end; return order;
end
-- Keep layout order in a character-named sidecar so server-ID/profile changes
-- after reload cannot make a saved arrangement appear to have vanished.
local function macro_layout_legacy_path()
    local source=(debug.getinfo(1,'S') or {}).source or '';
    if source:sub(1,1)~='@' or not state.profileId then return nil; end
    local directory=source:sub(2):match('^(.*[\\\\/])');
    local character=state.profileId:match('^[^_]+_([%a][%w_]*)$');
    if not directory or not character then return nil; end
    return directory..'decker_layouts_'..character..'.cfg';
end
local function macro_layout_store_path()
    if not state.profileId then return nil; end
    local character=state.profileId:match('^[^_]+_([%a][%w_]*)$');
    if not character then return nil; end
    local ok,base=pcall(function() return AshitaCore:GetInstallPath(); end);
    if not ok or type(base)~='string' or base=='' then return macro_layout_legacy_path(); end
    base=base:gsub('[\\\\/]+$','');
    local directory=base..'\\\\config\\\\addons\\\\decker\\\\';
    local existsOk,exists=pcall(ashita.fs.exists,directory);
    if not existsOk then return macro_layout_legacy_path(); end
    if not exists then
        pcall(ashita.fs.create_dir,directory);
        existsOk,exists=pcall(ashita.fs.exists,directory);
        if not existsOk or not exists then return macro_layout_legacy_path(); end
    end
    return directory..'decker_layouts_'..character..'.cfg';
end
local function write_macro_layout_store(path)
    if type(path)~='string' or path=='' then return false; end
    local ok,f=pcall(io.open,path,'w'); if not ok or not f then return false; end
    local wrote=pcall(function()
        f:write('layoutstore=2\n');
        for key,order in pairs(state.macroLayouts) do
            local book,set=key:match('^(%d+)%.(%d+)$');
            if book and set and tonumber(book)>=1 and tonumber(book)<=BOOK_COUNT and tonumber(set)>=1 and tonumber(set)<=10
                and valid_macro_layout(order) then
                local encoded={}; for i=1,20 do encoded[i]=('%02d'):format(order[i]); end
                f:write('macrolayout.',key,'=',table.concat(encoded),'\n');
            end
        end
    end);
    local closedOk,closed=pcall(function() return f:close(); end);
    return wrote and closedOk and closed~=nil;
end
local function save_macro_layout_store()
    local primary=macro_layout_store_path();
    local fallback=macro_layout_legacy_path();
    local primarySaved=write_macro_layout_store(primary);
    local fallbackSaved=fallback~=primary and write_macro_layout_store(fallback) or false;
    return primarySaved or fallbackSaved;
end
local function read_macro_layout_file(path,overwrite)
    if type(path)~='string' or path=='' then return false; end
    local ok,f=pcall(io.open,path,'r');
    if not ok or not f then return false; end
    local loaded=false;
    for line in f:lines() do
        local key,value=line:match('^([%w.]+)=([%w_.:%-]+)$');
        local book,set; if key then book,set=key:match('^macrolayout%.(%d+)%.(%d+)$'); end
        book,set=tonumber(book),tonumber(set);
        if book and book>=1 and book<=BOOK_COUNT and set and set>=1 and set<=10
            and #value==40 and not value:find('[^%d]') then
            local order,seen={},{}; local valid=true;
            for i=1,20 do
                local slot=tonumber(value:sub((i-1)*2+1,i*2));
                if not slot or slot<1 or slot>20 or seen[slot] then valid=false; break; end
                order[i]=slot; seen[slot]=true;
            end
            local layoutKey=book..'.'..set;
            if valid and (overwrite or not state.macroLayouts[layoutKey]) then
                state.macroLayouts[layoutKey]=order; loaded=true;
            end
        end
    end
    f:close();
    return loaded;
end
local function load_macro_layout_store()
    local loaded=false;
    -- The active per-character profile was read first. Keep any valid entries
    -- it contains, then fill gaps from both persistent and legacy locations.
    local primary=macro_layout_store_path();
    local legacy=macro_layout_legacy_path();
    if primary then loaded=read_macro_layout_file(primary,false) or loaded; end
    if legacy and legacy~=primary then loaded=read_macro_layout_file(legacy,false) or loaded; end
    -- Earlier builds stored layouts in server-qualified profile files beside
    -- the addon. Search all matching character profiles to survive server-ID
    -- changes and updater replacements of the active profile filename.
    local source=(debug.getinfo(1,'S') or {}).source or '';
    local directory=source:sub(1,1)=='@' and source:sub(2):match('^(.*[\\\\/])') or nil;
    local character=state.profileId and state.profileId:match('^[^_]+_([%a][%w_]*)$');
    if directory and character and ashita and ashita.fs and ashita.fs.get_dir then
        local ok,files=pcall(ashita.fs.get_dir,directory,'decker_profile_.*_'..character..'%.cfg',true);
        if ok and type(files)=='table' then
            for _,file in ipairs(files) do
                if type(file)=='string' then
                    local candidate=file:match('[\\\\/]') and file or directory..file;
                    loaded=read_macro_layout_file(candidate,false) or loaded;
                end
            end
        end
    end
    if loaded then save_macro_layout_store(); end
    return loaded;
end
local function current_macro_layout()
    local key=macro_layout_key();
    if state.layoutEditing and state.layoutDraftKey==key and valid_macro_layout(state.layoutDraft) then return state.layoutDraft; end
    local order=state.macroLayouts[key];
    return valid_macro_layout(order) and order or identity_macro_layout();
end
local function cancel_macro_layout()
    state.layoutEditing=false; state.layoutDraft=nil; state.layoutDraftKey=nil; state.layoutSelected=nil; state.layoutDragging=nil; state.layoutStatus=nil;
end
local function begin_macro_layout()
    if not state.profileReady or state.phase<4 or #state.names~=20 or state.guardEditing then return false; end
    state.layoutDraftKey=macro_layout_key();
    state.layoutDraft=copy_macro_layout(current_macro_layout());
    state.layoutEditing=true; state.layoutSelected=nil;
    state.layoutStatus='Click two macros to swap them, then Apply & Save.';
    return true;
end
local function apply_macro_layout()
    local key=macro_layout_key();
    if not state.layoutEditing or state.layoutDraftKey~=key or not valid_macro_layout(state.layoutDraft) then cancel_macro_layout(); return false; end
    state.macroLayouts[key]=copy_macro_layout(state.layoutDraft);
    cancel_macro_layout(); return true;
end
local function swap_macro_layout_slots(a,b)
    if not state.layoutEditing or state.layoutDraftKey~=macro_layout_key() or not valid_macro_layout(state.layoutDraft)
        or a<1 or a>20 or b<1 or b>20 then return; end
    state.layoutDraft[a],state.layoutDraft[b]=state.layoutDraft[b],state.layoutDraft[a];
    state.layoutSelected=nil;
    state.layoutStatus='Unsaved layout changes. Press Apply & Save.';
end
local function save_display()
    if not state.profileReady then return false; end
    local path=settings_path(); if not path then return false; end
    local ok,f=pcall(io.open,path,'w'); if not ok or not f then return false; end
    f:write('showscrollbars=',state.showScrollbars and '1' or '0','\n');
    f:write('motionenabled=',state.motionEnabled and '1' or '0','\n');
    f:write('glassversion=1\nouteropacity=',state.outerOpacity,'\npanelopacity=',state.panelOpacity,'\nbuttonopacity=',state.buttonOpacity,'\nmacrofont=',state.macroFont:gsub(' ','_'),'\nmacrofontsize=',state.macroFontSize,'\n');
    f:write('theme=',state.theme,'\nscale=',state.scale,'\nwidth=',state.hudWidth,'\nheight=',state.hudHeight,'\ncompact=',state.compactKeys and '1' or '0','\nbook=',state.manualBook or 1,'\nset=',state.trackedSet or 1,'\nopacity=',state.hudOpacity,'\nautohide=',state.autoHide and '1' or '0','\nautohidedelay=',state.autoHideDelay,'\nautohidemode=',state.autoHideMode,'\necholock=',state.echoLock and '1' or '0','\nrowswitchkey=',state.rowSwitchKey,'\nnavmodifier=',state.navModifier,'\nnavmode=',state.stickyNavigation and 'toggle' or 'hold','\nnavenabled=',state.navKeysEnabled and '1' or '0','\nkeybinds=',state.savedKeybinds and '1' or '0','\nackkeys=',state.savedAck and '1' or '0','\n');
    f:write('mappingmode=',state.mappingMode,'\npositionlocked=',state.positionLocked and '1' or '0','\nnavrow=',state.navRow or 'CTRL','\n');
    f:write('autoconnect=',state.autoConnect and '1' or '0','\n');
    if state.hudPos then f:write('posx=',math.floor(state.hudPos[1]),'\nposy=',math.floor(state.hudPos[2]),'\n'); end
    f:write('statebarenabled=',state.statebarEnabled and '1' or '0','\nstatebarvertical=',state.statebarVertical and '1' or '0','\nstatebarlocked=',state.statebarLocked and '1' or '0','\nstatebaralways=',state.statebarAlways and '1' or '0','\nstatebarscale=',state.statebarScale,'\nstatebaropacity=',state.statebarOpacity,'\nstatebartheme=',state.statebarTheme,'\nstatebarvisibility=',state.statebarVisibility,'\nstatebarselected=',0,'\n');
    f:write('statebarlabelsize=',state.statebarLabelSize,'\nstatebarkeysize=',state.statebarKeySize,'\n');
    for _,id in ipairs({'hud','statebar','collapsed'}) do
        local pos=state.windowPositions[id];
        if pos then f:write(id,'posx=',pos[1],'\n',id,'posy=',pos[2],'\n'); end
    end
    f:write('classic75=',state.classic75 and '1' or '0','\nclassicorder=',table.concat(state.classicOrder),'\n');
    f:write('statebarcount=',#state.statebarSlots,'\n');
    f:write('statebarhotkeysenabled=',state.statebarHotkeysEnabled and '1' or '0','\n');
    for i,b in ipairs(state.statebarSlots) do f:write('statebar',i,'=',b.row,':',b.slot,'\n'); f:write('statebarhotkey',i,'=',state.statebarHotkeys[i] or 0,'\n'); f:write('statebartype',i,'=',b.kind or 'state','\n'); f:write('statebarcommand',i,'=',(b.command or ''):gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n'); f:write('statebarsource',i,'=',b.source or 'macro','\n'); f:write('statebarlabel',i,'=',(b.label or ''):gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n'); f:write('statebartrack',i,'=',b.trackDefence or 'auto','\n'); end
    f:write('bookpath=',(state.bookPath or ''):gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n');
    for i=1,40 do
        for _,field in ipairs({'bookNames','bookAliases'}) do
            local value=state[field][i];
            if value and value~='' then f:write(field:lower(),i,'=',value:gsub('.',function(c) return string.format('%02X',string.byte(c)); end),'\n'); end
        end
    end
    for key,order in pairs(state.macroLayouts) do
        local book,set=key:match('^(%d+)%.(%d+)$');
        if book and set and tonumber(book)>=1 and tonumber(book)<=BOOK_COUNT and tonumber(set)>=1 and tonumber(set)<=10
            and valid_macro_layout(order) then
            local encoded={}; for i=1,20 do encoded[i]=('%02d'):format(order[i]); end
            f:write('macrolayout.',key,'=',table.concat(encoded),'\n');
        end
    end
    for key,enabled in pairs(state.macroGuards) do
        local book,set,index=key:match('^(%d+)%.(%d+)%.(%d+)$');
        if enabled and book and tonumber(book)>=1 and tonumber(book)<=BOOK_COUNT
            and tonumber(set)>=1 and tonumber(set)<=10 and tonumber(index)>=1 and tonumber(index)<=20 then
            f:write('macroguard.',key,'=1\n');
        end
    end
    f:write('cooldownenabled=',state.cooldownEnabled and '1' or '0','\n','cooldownautonames=',state.cooldownAutoNames and '1' or '0','\n');
    for i=1,20 do local b=state.cooldownBindings[i]; if b then f:write('cooldown',i,'=',b.kind,':',b.id,'\n'); end end
    for key,binding in pairs(state.cooldownBindings) do
        if type(key)=='string' then
            f:write('cooldownpage.',key,'=',binding.kind,':',binding.id,':',cooldown.encode(binding.fingerprint),'\n');
        end
    end
    for i=1,20 do f:write('direct',i,'=',state.directKeys[i] or 0,'\n'); end
    local closed=f:close();
    local layoutsSaved=save_macro_layout_store();
    state.layoutDirtyAt=nil;
    return closed~=nil and layoutsSaved;
end
local function toggle_macro_guard(index)
    if not state.guardEditing or type(index)~='number' or index<1 or index>20 then return false,nil; end
    local key=macro_guard_key(index);
    local previous=state.macroGuards[key];
    if previous then state.macroGuards[key]=nil; else state.macroGuards[key]=true; end
    if save_display() then return true,not previous; end
    state.macroGuards[key]=previous;
    return false,previous;
end
local function load_display()
    local path=settings_path();
    local ok,f=false,nil;
    if path then ok,f=pcall(io.open,path,'r'); end
    if ok and f then
    for line in f:lines() do
        local key,value=line:match('^([%w.]+)=([%w_.:%-]+)$');
        local n=tonumber(value);
        local guardBook,guardSet,guardIndex; if key then guardBook,guardSet,guardIndex=key:match('^macroguard%.(%d+)%.(%d+)%.(%d+)$'); end
        guardBook,guardSet,guardIndex=tonumber(guardBook),tonumber(guardSet),tonumber(guardIndex);
        if value=='1' and guardBook and guardBook>=1 and guardBook<=BOOK_COUNT
            and guardSet and guardSet>=1 and guardSet<=10 and guardIndex and guardIndex>=1 and guardIndex<=20 then
            state.macroGuards[guardBook..'.'..guardSet..'.'..guardIndex]=true;
        end
        local layoutBook,layoutSet; if key then layoutBook,layoutSet=key:match('^macrolayout%.(%d+)%.(%d+)$'); end
        layoutBook,layoutSet=tonumber(layoutBook),tonumber(layoutSet);
        if layoutBook and layoutBook>=1 and layoutBook<=BOOK_COUNT and layoutSet and layoutSet>=1 and layoutSet<=10
            and #value==40 and not value:find('[^%d]') then
            local order,seen={},{}; local valid=true;
            for i=1,20 do
                local slot=tonumber(value:sub((i-1)*2+1,i*2));
                if not slot or slot<1 or slot>20 or seen[slot] then valid=false; break; end
                order[i]=slot; seen[slot]=true;
            end
            if valid then state.macroLayouts[layoutBook..'.'..layoutSet]=order; end
        end
        for _,id in ipairs({'hud','statebar','collapsed'}) do
            if (key==id..'posx' or key==id..'posy') and n and n>=-20000 and n<=20000 then
                state.windowPositions[id]=state.windowPositions[id] or {20,20};
                state.windowPositions[id][key==id..'posx' and 1 or 2]=n;
            end
        end
        if key=='classic75' then state.classic75=value=='1'; end
        if key=='classicorder' and value:match('^[1-6][1-6][1-6][1-6][1-6][1-6]$') then
            local order,seen={}, {};
            for digit in value:gmatch('%d') do
                local index=tonumber(digit);
                seen[index]=true; order[#order+1]=index;
            end
            if seen[1] and seen[2] and seen[3] and seen[4] and seen[5] and seen[6] then state.classicOrder=order; end
        end
        if key=='statebarcount' and n and n>=0 and n<=12 and n==math.floor(n) then state.statebarSlots={}; end
        local ti=key and tonumber(key:match('^statebartype(%d+)$'));
        local xi=key and tonumber(key:match('^statebarcommand(%d+)$'));
        local mi=key and tonumber(key:match('^statebarsource(%d+)$'));
        local li=key and tonumber(key:match('^statebarlabel(%d+)$'));
        local di=key and tonumber(key:match('^statebartrack(%d+)$'));
        local bi=ti or xi or mi or li or di;
        if bi and bi>=1 and bi<=12 and state.statebarSlots[bi] then
            local b=state.statebarSlots[bi];
            if ti and (value=='state' or value=='utility') then b.kind=value; end
            if di and (value=='pdt' or value=='mdt') then b.trackDefence=value; end
            if mi and (value=='macro' or value=='command') then b.source=value; end
            if li and #value<=48 and #value%2==0 and not value:find('[^%x]') then b.label=value:gsub('%x%x',function(h) return string.char(tonumber(h,16)); end):gsub('[%c#]',''); end
            if xi and #value<=480 and #value%2==0 and not value:find('[^%x]') then b.command=value:gsub('%x%x',function(h) return string.char(tonumber(h,16)); end); end
        end
        if key=='statebarlabelsize' and n and (n==0 or (n>=10 and n<=28)) then state.statebarLabelSize=n; end
        if key=='statebarkeysize' and n and n>=8 and n<=18 then state.statebarKeySize=n; end
        if key=='statebaropacity' and n and n>=0 and n<=1 then state.statebarOpacity=n; end
        if key=='statebartheme' and n and n>=1 and n<=4 then state.statebarTheme=n; end
        if key=='statebarvisibility' and (value=='always' or value=='navigation' or value=='manual') then state.statebarVisibility=value; end
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
        if key=='autoconnect' then state.autoConnect=value=='1'; end
        if key=='positionlocked' then state.positionLocked=value=='1'; end
        if key=='navrow' and (value=='CTRL' or value=='ALT') then state.navRow=value; end
        if key=='posx' and n and n>=0 and n<=20000 then state.hudPos=state.hudPos or {0,0}; state.hudPos[1]=n; end
        if key=='posy' and n and n>=0 and n<=20000 then state.hudPos=state.hudPos or {0,0}; state.hudPos[2]=n; end
        if key=='cooldownenabled' then state.cooldownEnabled=value=='1'; end
        if key=='cooldownautonames' then state.cooldownAutoNames=value=='1'; end
        local book,page,slot;
        if key then book,page,slot=key:match('^cooldownpage%.(%d+)%.(%d+)%.(%d+)$'); end
        book,page,slot=tonumber(book),tonumber(page),tonumber(slot);
        if book and book>=1 and book<=BOOK_COUNT and page>=1 and page<=10 and slot>=1 and slot<=20 then
            state.cooldownBindings[book..'.'..page..'.'..slot]=cooldown.decode(value);
        end
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
        if key=='rowswitchkey' and ROW_KEYS[value] then state.rowSwitchKey=value; end
        if key=='stickynav' and (value=='0' or value=='1') then state.stickyNavigation=value=='1'; end
        if key=='navmode' and (value=='toggle' or value=='hold') then state.stickyNavigation=value=='toggle'; end
        if key=='navenabled' and (value=='0' or value=='1') then state.savedNavEnabled=value=='1'; end
        if key=='keybinds' and (value=='0' or value=='1') then state.savedKeybinds=value=='1'; end
        if key=='ackkeys' and (value=='0' or value=='1') then state.savedAck=value=='1'; end
        -- Legacy auto-exit preference intentionally ignored: navigation now has only Toggle and Hold modes.
        if key=='navmodifier' and NAV_KEYS[value] then state.navModifier=value; end
        if key=='theme' and n and n>=1 and n<=4 and n==math.floor(n) then state.theme=n;
        elseif key=='scale' and n and n>=0.7 and n<=1.5 then state.scale=n;
        elseif key=='width' and n and n>=80 and n<=140 then state.hudWidth=n;
        elseif key=='height' and n and n>=30 and n<=90 then state.hudHeight=n;
        elseif key=='compact' and (value=='0' or value=='1') then state.compactKeys=value=='1';
        elseif key=='book' and n and n==math.floor(n) and n>=1 and n<=BOOK_COUNT then state.manualBook=n;
        elseif key=='set' and n and n==math.floor(n) and n>=1 and n<=10 then state.trackedSet=n; state.trackedSource='saved (unverified)'; end
    end
    end -- profile file may be absent after an updater replacement; still load the sidecar below.
    if f then f:close(); end
    if not load_macro_layout_store() then save_macro_layout_store(); end
    if not state.windowPositions.hud and state.hudPos then state.windowPositions.hud=copy_value(state.hudPos); end
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
    local changed=false; for i=1,BOOK_COUNT do if state.bookNames[i]~=first[i] then changed=true; break; end end
    state.bookNames=first; state.bookNameStatus='Imported saved in-game titles; refresh after saving a rename in game'; if changed then save_display(); end; return true;
end
local function refresh_book_titles()
    if not state.profileReady then return false; end
    if state.bookPath=='' then
        local ok,id=pcall(function() return AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0); end);
        if not ok or type(id)~='number' or id<=0 or id>4294967295 or id~=math.floor(id) then return false; end
        local fs=ashita and ashita.fs;
        if not fs or type(fs.get_install_directory)~='function' then return false; end
        local candidates={}; local seen={};
        for _,lang in ipairs({0,1,2,3}) do
            local good,root=pcall(fs.get_install_directory,lang,1);
            if good and type(root)=='string' and root~='' then
                for _,folder in ipairs({string.format('%x',id),string.format('%08x',id)}) do
                    local path=root:gsub('[\\/]+$','')..'/USER/'..folder;
                    local key=path:lower();
                    if not seen[key] then
                        seen[key]=true; local f=io.open(path..'/mcr.ttl','rb');
                        if f then local bytes=f:read(345); f:close(); if parse_book_titles(bytes) then candidates[#candidates+1]=path; end end
                    end
                end
            end
        end
        if #candidates~=1 then
            state.bookNameStatus=#candidates>1 and 'Multiple game folders found; choose this character macro folder below' or 'Saved titles not found automatically; choose this character macro folder below';
            return false;
        end
        state.bookPath=candidates[1];
    end
    return import_book_titles();
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
    analytics.discard_on_profile_change();
    cooldown.reset_observer();
    state.profileId=id; state.profileReady=false; state.statebarDrag=nil;
    for _,keys in pairs(sectionKeys) do for _,key in ipairs(keys) do state[key]=copy_value(profileDefaults[key]); end end
    state.windowPositions={}; state.layoutDirtyAt=nil;
    state.hudPos=nil; state.keyAssignmentPage=false; state.statebarSelected=0; state.navRow='CTRL'; state.navSlot=1;
    state.names={}; state.phase=0; state.allowAllClicks=false; state.allowSwitch=false;
    state.macroLayouts={}; state.macroGuards={}; state.guardEditing=false; state.pendingMacroConfirm=nil; state.confirmingMacro=false; cancel_macro_layout();
    state.autoConnectPending=false; state.autoConnectAttempted=false; state.autoConnectAt=0;
    state.autoRefresh=false; state.clickConsent=false; state.confirmAll=false;
    state.navToggleActive=false; state.navModifierHeld=false; state.navPhysicalDown=false;
    state.navCaptured={}; state.navPressed={}; state.navPhysicalKeys={}; state.navRepeatAt={}; state.navQueue={}; state.deferredNav={};
    state.navSetVerifyFrames=0; state.pendingRefreshFrames=0; state.awaitingPageFingerprint=nil; state.lastExecuted=nil;
    state.flashRow=nil; state.flashSlot=nil; state.flashUntil=0;
    state.guideOpen=false; state.guideStep=1; state.guideDemoRow='CTRL'; state.guideDemoSlot=2; state.guideDemoMode='Hold';
    state.hudReadySince=nil; state.hudLastActivity=os.clock(); state.hudImmediateHide=false;
    if id then
        load_display(); state.profileReady=true; refresh_book_titles();
        state.autoConnectPending=state.autoConnect;
        state.autoConnectAt=os.clock()+2;
        state.navKeysEnabled=state.savedNavEnabled;
        -- Connection gates execution; saved on/off choice applies only after Connect succeeds.
        state.keybinds=false; state.acknowledgeKeys=false;
    end
    state.held={}; state.suppressed={}; state.nativeNavHeld={};
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
-- Explicitly opt-in, memory-only diagnostic ring. Never store chat contents,
-- character names, passwords, macro text or raw packet/key buffers.
local inputDiag={enabled=false,records={},limit=80,sequence=0}
function inputDiag.record(source,reason,code,edge,blocked,context)
    if not inputDiag.enabled then return end
    if type(source)~='string' or type(reason)~='string' then return end
    local t=os.clock()
    local rec={at=t,source=source,reason=reason,
        key=type(code)=='number' and code or -1,
        edge=edge=='up' and 'up' or edge=='down' and 'down' or 'state',
        blocked=blocked and true or false,
        chat=context and context.chat==true or false,
        prompt=context and context.prompt==true or false,
        shift=context and context.shift==true or false}
    local prev=inputDiag.records[#inputDiag.records]
    -- Consolidate duplicate high-frequency polling for one key/state.
    if prev and prev.source==rec.source and prev.reason==rec.reason
        and prev.key==rec.key and prev.edge==rec.edge
        and prev.blocked==rec.blocked and prev.chat==rec.chat
        and prev.prompt==rec.prompt and prev.shift==rec.shift
        and t-prev.at<.5 then
        prev.repeatCount=(prev.repeatCount or 1)+1;prev.at=t;return
    end
    inputDiag.sequence=inputDiag.sequence+1;rec.sequence=inputDiag.sequence
    inputDiag.records[#inputDiag.records+1]=rec
    if #inputDiag.records>inputDiag.limit then table.remove(inputDiag.records,1) end
end
function inputDiag.clear() inputDiag.records={};inputDiag.sequence=0 end
function inputDiag.report(limit)
    local result={}
    limit=math.max(1,math.min(80,tonumber(limit) or 20))
    for i=math.max(1,#inputDiag.records-limit+1),#inputDiag.records do
        local r=inputDiag.records[i]
        result[#result+1]=('input#%d %.3f %s %s k=%d %s blocked=%s chat=%s prompt=%s shift=%s x%d'):format(
            r.sequence,r.at,r.source,r.reason,r.key,r.edge,
            tostring(r.blocked),tostring(r.chat),tostring(r.prompt),
            tostring(r.shift),r.repeatCount or 1)
    end
    return result
end
local function trace_input(source,reason,code,edge,blocked,chatOpen,prompt,shift)
    inputDiag.record(source,reason,code,edge,blocked,{chat=chatOpen,prompt=prompt,shift=shift})
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
    state.awaitingPageFingerprint=state.previousFingerprint;
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
-- Combat Analytics v1: deliberately tracks requests, not successful casts.
-- Memory-only, per-character; no native macro editing, layout remapping or telemetry upload.
analytics = {active=nil,last=nil};
local function analytics_identity()
    if not state.profileReady or not state.profileId then return nil; end
    return state.profileId;
end
function analytics.start(kind,label)
    kind=(kind or ''):lower();
    if kind~='hnm' and kind~='exp' and kind~='practice' then return false,'Use hnm, exp or practice.'; end
    if not analytics_identity() then return false,'Log into a character first.'; end
    if analytics.active then return false,'Stop the current session first.'; end
    label=(label or ''):gsub('[^%w _%-]',''):sub(1,40);
    if label=='' then label=kind:upper(); end
    analytics.active={kind=kind,label=label,profile=state.profileId,
        started=os.time(),attempts=0,requests=0,refused=0,slots={},sourceCounts={}};
    return true,'Started '..kind:upper()..' session: '..label;
end
function analytics.stop()
    local a=analytics.active;
    if not a then return false,'No active session.'; end
    a.ended=os.time();analytics.last=a;analytics.active=nil;
    return true,'Stopped '..a.kind:upper()..' session: '..a.label;
end
function analytics.discard_on_profile_change()
    if analytics.active then analytics.stop(); end
    -- A new profile must not display the previous character's results.
    analytics.last=nil;
end
function analytics.attempt(row,slot,source)
    local a=analytics.active;
    if not a or a.profile~=state.profileId then return nil; end
    if row~='CTRL' and row~='ALT' and row~='STATEBAR' then return nil; end
    if type(slot)~='number' or slot<1 or slot>(row=='STATEBAR' and 20 or 10) then return nil; end
    local ix=(row=='ALT' and 10 or 0)+slot;
    local name;
    if row=='STATEBAR' then
        local b=state.statebarSlots[slot] or {};
        name=(b.label or b.command or 'StateBar'):sub(1,32);
    else name=(state.names[ix] or ''):sub(1,32); end
    local key=table.concat({tostring(state.manualBook),tostring(state.trackedSet),row,tostring(slot),name},'|');
    local item=a.slots[key];
    if not item then
        if a.unique and a.unique>=400 then return nil; end
        item={book=state.manualBook,set=state.trackedSet,row=row,slot=slot,
            name=name,attempts=0,requests=0,refused=0};
        a.slots[key]=item;a.unique=(a.unique or 0)+1;
    end
    item.attempts=item.attempts+1;a.attempts=a.attempts+1;
    source=source or 'unknown';
    if not ({mouse=true,direct=true,navigation=true,statebar=true})[source] then source='unknown'; end
    a.sourceCounts[source]=(a.sourceCounts[source] or 0)+1;
    return item;
end
function analytics.finish(item,accepted)
    if not item then return; end
    local a=analytics.active;
    if not a or a.profile~=state.profileId then return; end
    if accepted then item.requests=item.requests+1;a.requests=a.requests+1;
    else item.refused=item.refused+1;a.refused=a.refused+1; end
end
function analytics.note_recast(row,slot)
    local a=analytics.active;
    if not a or a.profile~=state.profileId then return; end
    a.recastEvidence=(a.recastEvidence or 0)+1;
end
function analytics.report()
    local a=analytics.active or analytics.last;
    if not a then return {'No Combat Analytics session recorded.'}; end
    local duration=math.max(0,(a.ended or os.time())-a.started);
    local result={('Combat Analytics %s: %s (%ds)'):format(a.kind:upper(),a.label,duration),
        ('Requests %d / attempts %d / refused %d / recast-start evidence %d. Native invocation is NOT a confirmed cast.'):format(a.requests,a.attempts,a.refused,a.recastEvidence or 0)};
    local sorted={};for _,entry in pairs(a.slots) do sorted[#sorted+1]=entry;end
    table.sort(sorted,function(x,y)
        if x.attempts~=y.attempts then return x.attempts>y.attempts end
        if x.book~=y.book then return x.book<y.book end
        if x.set~=y.set then return x.set<y.set end
        if x.row~=y.row then return x.row<y.row end
        return x.slot<y.slot;
    end);
    for i=1,math.min(#sorted,10) do
        local e=sorted[i];
        result[#result+1]=('Book %s Set %s %s %s [%s]: %d attempts, %d native requests'):format(
            tostring(e.book),tostring(e.set),e.row,tostring(e.slot),e.name,e.attempts,e.requests);
    end
    if #sorted>10 then result[#result+1]=('...%d other slots'):format(#sorted-10);end
    return result;
end

local function flash_slot(row,slot)
    state.flashRow=row; state.flashSlot=slot; state.flashUntil=os.clock()+0.30;
end
local function record_execution(row,slot,source,displayRow,displaySlot)
    state.navRow=displayRow or row; state.navSlot=displaySlot or slot; state.navSource=source;
    state.lastExecuted={row=row,slot=slot,name=state.names[(row=='CTRL' and 0 or 10)+slot] or '',set=state.trackedSet};
    flash_slot(row,slot);
    if state.autoHide and state.autoHideDelay==0 then state.hudImmediateHide=true; end
end
selector={};
-- Weapon-skill families follow Storm XI's weapon_skills dataset and Ashita skill IDs.
selector.weaponSkills={};
selector.wsNames={};
for family,skills in pairs({
    [1]={1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,228,230,231},
    [2]={16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,224,232},
    [3]={32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,225,226,227,229,233,238,239},
    [4]={48,49,50,51,52,53,54,55,56,57,58,59,60,61,62},
    [5]={64,65,66,67,68,69,70,71,72,73,74,75,76,77,78},
    [6]={80,81,82,83,84,85,86,87,88,89,90,91,92,93,94},
    [7]={96,97,98,99,100,101,102,103,104,105,106,107,108,109,110},
    [8]={112,113,114,115,116,117,118,119,120,121,122,123,124,125,126},
    [9]={128,129,130,131,132,133,134,135,136,137,138,139,140,141,142},
    [10]={144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159},
    [11]={160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,234},
    [12]={176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,235,240},
    [25]={192,193,194,196,197,198,199,200,201,202,203,204},
    [26]={208,209,210,212,213,214,215,216,217,218,219,220,221,222},
}) do
    for _,id in ipairs(skills) do selector.weaponSkills[id]=family; end
end
function selector.read_page(path,page)
    local file=io.open(path..'/mcr'..(page==0 and '' or tostring(page))..'.dat','rb');
    if not file then return nil; end
    local bytes=file:read(7625); file:close();
    return bytes and #bytes==7624 and bytes or nil;
end
function selector.page_label(bytes,index)
    local first=395+(index-1)*380;
    return bytes:sub(first,first+7):match('^[^%z]*'):gsub('[%c]','');
end
function selector.match_page(bytes)
    if not bytes then return false; end
    for index=1,20 do
        if selector.page_label(bytes,index)~=(state.names[index] or '') then return false; end
    end
    return true;
end
function selector.find_action_page(path,tracked,trackedBytes,t)
    if selector.match_page(trackedBytes) then return trackedBytes,tracked; end
    -- A job change or native book navigation can leave Decker's saved page out of date.
    -- Resolve command bodies by live labels without changing the active book or layout.
    local namesKey=table.concat(state.names,'\0');
    if namesKey:gsub('%z','')=='' then return trackedBytes,tracked; end
    local key=path..':'..tracked..':'..namesKey;
    local previous=selector.pageSearch;
    if previous and previous.key==key then
        if previous.page then
            local bytes=selector.read_page(path,previous.page);
            if selector.match_page(bytes) then return bytes,previous.page; end
        elseif t<previous.retry then
            if previous.ambiguous then return nil; end
            return trackedBytes,tracked;
        end
    end
    local found,foundPage;
    for page=0,BOOK_COUNT*10-1 do
        if page~=tracked then
            local bytes=selector.read_page(path,page);
            if selector.match_page(bytes) then
                if found and found:sub(29)~=bytes:sub(29) then
                    selector.pageSearch={key=key,retry=t+5,ambiguous=true};
                    return nil;
                end
                found,foundPage=bytes,page;
            end
        end
    end
    selector.pageSearch={key=key,page=foundPage,retry=t+5};
    if found then return found,foundPage; end
    return trackedBytes,tracked;
end
function selector.actions(index,fresh)
    local path=(state.bookPath or ''):gsub('[\\/]+$','');
    if path=='' then return nil; end
    local page=(state.manualBook-1)*10+state.trackedSet-1;
    local key=path..':'..page..':'..table.concat(state.names,'\0');
    local t=os.clock();
    local cached=selector.actionPage;
    if fresh or not cached or cached.key~=key or t>=cached.untilAt then
        local bytes,resolved=selector.find_action_page(path,page,selector.read_page(path,page),t);
        cached={key=key,untilAt=t+.25,bytes=bytes,page=resolved,commands={}};
        selector.actionPage=cached;
    end
    local bytes=cached.bytes;
    if not bytes or selector.page_label(bytes,index)~=(state.names[index] or '') then return nil; end
    if cached.commands[index] then return cached.commands[index]; end
    local commands={};
    for line=0,5 do
        local first=29+(index-1)*380+line*61;
        commands[#commands+1]=bytes:sub(first,first+60):match('^[^%z]*');
    end
    cached.commands[index]=commands;
    return commands;
end
function cooldown.infer_macro(index)
    if not selector or not selector.actions then return nil,'unavailable'; end
    local commands=selector.actions(index);
    if not commands then return nil,'unavailable'; end
    local found={}; local seen={};
    local ok=pcall(function()
        local resources=AshitaCore:GetResourceManager();
        if not resources then return; end
        for _,command in ipairs(commands) do
            local kind,name=command:match('^%s*/(%a+)%s+"([^"]+)"');
            if not kind then kind,name=command:match('^%s*/(%a+)%s+([^<]+)'); end
            kind=(kind or ''):lower(); name=(name or ''):gsub('%s+$','');
            local resource,entry;
            if name~='' and (kind=='ma' or kind=='magic' or kind=='nin' or kind=='ninjutsu') then
                resource=resources:GetSpellByName(name,0);
                if resource and type(resource.Index)=='number' and resource.Index>=0 then
                    entry={kind='spell',id=resource.Index,name=resource.Name and resource.Name[1] or name};
                end
            elseif name~='' and (kind=='ja' or kind=='jobability') then
                resource=resources:GetAbilityByName(name,0);
                if resource and type(resource.RecastTimerId)=='number' and resource.RecastTimerId>=0 then
                    entry={kind='ability',id=resource.RecastTimerId,name=resource.Name and resource.Name[1] or name};
                end
            end
            if entry then
                local key=entry.kind..':'..entry.id;
                if not seen[key] then seen[key]=true; found[#found+1]=entry; end
            end
        end
    end);
    if not ok then return nil,'unavailable'; end
    if #found==1 then return found[1]; end
    if #found>1 then return nil,'ambiguous',found; end
    return nil,'none';
end
function cooldown.resolve_action(name)
    if type(name)~='string' then return nil; end
    name=name:match('^%s*(.-)%s*$') or '';
    if name=='' or #name>64 then return nil; end
    local ok,binding=pcall(function()
        local resources=AshitaCore:GetResourceManager();
        if not resources then return nil; end
        local spell=resources:GetSpellByName(name,0);
        if spell and type(spell.Index)=='number' and spell.Index>=0 then
            return {kind='spell',id=spell.Index,name=spell.Name and spell.Name[1] or name};
        end
        local ability=resources:GetAbilityByName(name,0);
        if ability and type(ability.RecastTimerId)=='number' and ability.RecastTimerId>=0 then
            return {kind='ability',id=ability.RecastTimerId,name=ability.Name and ability.Name[1] or name};
        end
    end);
    if ok then return binding; end
    return nil;
end
function selector.weapon_family(memory,resources,slot)
    local inventory=memory:GetInventory();
    local entry=inventory:GetEquippedItem(slot);
    local index=entry and tonumber(entry.Index);
    if not index then return nil; end
    if index==0 then return slot==0 and 1 or 0; end -- Unarmed main hand; empty ranged slot.
    local item=inventory:GetContainerItem(math.floor(index/256),index%256);
    if not item or not item.Id or item.Id==0 then return nil; end
    local resource=resources:GetItemById(item.Id);
    return resource and tonumber(resource.Skill) or nil;
end
function selector.missing(known)
    return known==false or tonumber(known)==0;
end
function selector.action_unavailable(kind,name,memory,resources)
    local player=memory:GetPlayer();
    if kind=='ma' or kind=='magic' or kind=='nin' or kind=='ninjutsu' then
        local resource=resources:GetSpellByName(name,0);
        if not resource then return false; end
        local main,sub=tonumber(player:GetMainJob()),tonumber(player:GetSubJob());
        local mainLevel,subLevel=tonumber(player:GetMainJobLevel()),tonumber(player:GetSubJobLevel());
        if main and main>0 and sub and sub>=0 then
            if tonumber(resource.Skill)==39 and main~=13 and sub~=13 then return true; end
            local levels=resource.LevelRequired;
            if levels and (tonumber(resource.Skill) or 0)>0 and mainLevel and mainLevel>0 and subLevel then
                -- Ashita exposes LevelRequired as a one-based array including job 0.
                local mainRequired=tonumber(levels[main+1]);
                local subRequired=sub==0 and -1 or tonumber(levels[sub+1]);
                if mainRequired and subRequired and mainRequired<=99 and subRequired<=99 then
                    local mainCanCast=mainRequired>0 and mainLevel>=mainRequired;
                    local subCanCast=subRequired>0 and subLevel>=subRequired;
                    if not mainCanCast and not subCanCast then return true; end
                end
            end
        end
        return player:HasSpellData() and selector.missing(player:HasSpell(resource.Index));
    end
    local resource=resources:GetAbilityByName(name,0);
    local id=resource and tonumber(resource.Id);
    if kind=='ja' or kind=='jobability' then
        return id and id>=512 and player:HasAbilityData() and selector.missing(player:HasAbility(id));
    end
    if kind=='ws' or kind=='weaponskill' then
        if not id or not selector.weaponSkills[id] then
            local key=name:lower();
            id=selector.wsNames[key];
            if id==nil then
                for candidate in pairs(selector.weaponSkills) do
                    local ws=resources:GetAbilityById(candidate);
                    local label=ws and ws.Name and ws.Name[1];
                    if label then selector.wsNames[label:lower()]=candidate; end
                end
                id=selector.wsNames[key] or false;
                selector.wsNames[key]=id;
            end
        end
        local family=id and selector.weaponSkills[id];
        if not family then return false; end
        local equipped=selector.weapon_family(memory,resources,family>=25 and 2 or 0);
        if equipped and equipped~=family then return true; end
        -- Use the client's current usable list so a learned WS can become unavailable under sync.
        return player:HasAbilityData() and selector.missing(player:HasWeaponSkill(id));
    end
    return false;
end
function selector.unavailable(index)
    local commands=selector.actions(index);
    if not commands then return false; end
    local memory=AshitaCore:GetMemoryManager();
    local resources=AshitaCore:GetResourceManager();
    for _,command in ipairs(commands) do
        local kind,name=command:match('^%s*/(%a+)%s+"([^"]+)"');
        if not kind then kind,name=command:match('^%s*/(%a+)%s+([^<]+)'); end
        if kind then
            local ok,unavailable=pcall(selector.action_unavailable,kind:lower(),name:gsub('%s+$',''),memory,resources);
            if ok and unavailable then return true; end
        end
    end
    return false;
end
function selector.saved_target(index,name)
    local commands=selector.actions(index,true);
    if commands then
        for _,command in ipairs(commands) do
            if command:lower():match('^%s*/[%a]+%s+.*<st%a*>%s*$') then return true; end
        end
        return false;
    end
    return name=='Cure3' or name=='Cure4';
end
local function execute_slot(row,slot,source,displayRow,displaySlot)
    if state.guideOpen or state.layoutEditing or state.guardEditing then return false; end -- Editors never execute macros.
    local visualRow=displayRow or row;
    local visualSlot=displaySlot or slot;
    local idx=(row=='CTRL' and 0 or 10)+(slot-1);
    if source=='statebar' then
        for visualIndex,nativeIndex in ipairs(current_macro_layout()) do
            if nativeIndex==idx+1 then
                visualRow=visualIndex<=10 and 'CTRL' or 'ALT';
                visualSlot=((visualIndex-1)%10)+1;
                break;
            end
        end
    end
    if source~='statebar' and not state.confirmingMacro then
        local mapped=current_macro_layout()[idx+1];
        if mapped then idx=mapped-1; row=idx<10 and 'CTRL' or 'ALT'; slot=(idx%10)+1; end
    end
    local metric=analytics.attempt(row,slot,source);
    local function refused() analytics.finish(metric,false); return false; end
    if not state.allowAllClicks then
        if row=='CTRL' and slot==1 and state.clickConsent then try_ctrl1();
        else state.clickSummary='BLOCKED: mouse execution not ready; scan, validate and read names first.'; end
        return refused();
    end
    if state.phase < 4 or #state.names ~= 20 then state.clickSummary='BLOCKED: macro names not loaded'; return refused(); end
    if not validaddr(state.addresses.controller) or not validaddr(state.addresses.run) then
        state.clickSummary='BLOCKED: native execute signature unavailable'; return refused();
    end
    local name=state.names[idx+1] or '';
    if name=='' then state.clickSummary='Empty macro slot: no action'; return refused(); end
    if not state.confirmingMacro and macro_guarded(idx+1) then
        analytics.finish(metric,false);
        local pending=state.pendingMacroConfirm;
        if not pending or pending.index~=idx+1 or pending.row~=row or pending.slot~=slot
            or pending.book~=(state.manualBook or 1) or pending.set~=(state.trackedSet or 1)
            or pending.fingerprint~=state.previousFingerprint or os.clock()>=pending.expires then
            state.pendingMacroConfirm={row=row,slot=slot,source=source,index=idx+1,book=state.manualBook or 1,
                set=state.trackedSet or 1,fingerprint=state.previousFingerprint,name=name,expires=os.clock()+8,
                displayRow=visualRow,displaySlot=visualSlot};
        end
        state.visible=true; state.hudForceReveal=true; state.hudLastActivity=os.clock();
        state.clickSummary='ARMED: '..name..' - press the separate Confirm 2-hour button.';
        say(state.clickSummary,true);
        return false;
    elseif not state.confirmingMacro then
        state.pendingMacroConfirm=nil;
    end
    local mem=ashita and ashita.memory;
    if not mem then state.clickSummary='BLOCKED: memory API unavailable'; return refused(); end
    local ok,ptr=pcall(function() return mem.read_uint32(state.addresses.controller); end);
    local ok2,controller=false,nil;
    if ok and validaddr(ptr) and ptr%4==0 then
        ok2,controller=pcall(function() return mem.read_uint32(ptr); end);
    end
    if not ok2 or not validaddr(controller) or controller%4~=0 then
        state.clickSummary='BLOCKED: controller pointer invalid'; state.allowAllClicks=false; return refused();
    end
    -- Per Ashita macro library: CTRL=1, ALT=2, each with zero-based slot 0..9.
    -- Explicit opt-in; neither modifies macros nor patches the original HUD.
    local modifier=(row=='CTRL' and 1 or 2);
    local subtargetBefore=selector.read_subtarget();
    local expectsTarget=selector.saved_target(idx+1,name);
    local called,err=pcall(function()
        ffi.cast('Decker_FsMacroContainer_runMacro_f',state.addresses.run)(controller,modifier,slot-1);
    end);
    analytics.finish(metric,called);
    if called then
        -- Any macro launch path can open native targeting. Only navigation keys yield.
        selector.begin_handoff(subtargetBefore,expectsTarget);
        record_execution(row,slot,'executed',visualRow,visualSlot);
        cooldown.note_request(row,slot);
    end
    state.clickSummary=called and (row..'+'..tostring(slot==10 and 0 or slot)..' requested ('..name..')') or ('Lua error: '..tostring(err));
    say(state.clickSummary);
    return called;
end
local function cancel_macro_guard(reason)
    state.pendingMacroConfirm=nil;
    if reason then state.clickSummary=reason; end
end
local function confirm_macro_guard()
    local pending=state.pendingMacroConfirm;
    if not pending then return false; end
    if os.clock()>=pending.expires or pending.book~=(state.manualBook or 1)
        or pending.set~=(state.trackedSet or 1) or pending.fingerprint~=state.previousFingerprint
        or not macro_guarded(pending.index,pending.book,pending.set) then
        cancel_macro_guard('Protected macro confirmation expired or page changed; nothing was executed.');
        say(state.clickSummary,true); return false;
    end
    state.pendingMacroConfirm=nil;
    state.confirmingMacro=true;
    local ok,result=pcall(execute_slot,pending.row,pending.slot,pending.source,pending.displayRow,pending.displaySlot);
    state.confirmingMacro=false;
    if not ok then
        state.clickSummary='Protected macro failed safely: '..tostring(result); say(state.clickSummary,true); return false;
    end
    return result;
end

-- Optional Classic 75 presets leave the existing character bar intact.
local classic = { keys={64,65,67,68,87,88}, layouts={}, empty={} };
classic.jobs={'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH'};
classic.special={
    PLD={{'Accuracy','accuracy','base','accuracy'},{'Kite','kite','kite',true},{'Enmity'}},
    BLM={{'Landing','casting accuracy','casting','accuracy'},{'Damage','casting damage','casting','damage'},{'Burst','casting burst','casting','burst'}},
    WHM={{'Landing'},{'Cure Efficiency'},{'Low Enmity'}},
    NIN={{'Accuracy','accuracy','base','accuracy'},{'Fire','defence fire','defence','fire'},{'Evasion','defence evasion','defence','evasion'}},
    RDM={{'Landing','casting accuracy','casting','accuracy'},{'Fire','defence fire','defence','fire'},{'Convert Prep','/lac set Convert 8'}},
};
classic.planned={
    WAR={'Accuracy','Attack TP','Enmity'}, MNK={'Accuracy','Counter Tank','Evasion'},
    THF={'Accuracy','TH Tag','Evasion'}, DRK={'Accuracy','Attack TP','Stun Recast'},
    BST={'Charm','Pet Tank','Master Melee'}, BRD={'Song Landing','Buff Support','Pull Defence'},
    RNG={'Ranged Acc','Ranged Attack','Low Enmity'}, SAM={'Accuracy','Store TP','WS Accuracy'},
    DRG={'Accuracy','Jump TP','Healing Breath'}, SMN={'Pact Landing','Perpetuation','Pact Gear'},
    BLU={'Spell Landing','Physical Blue','Magical Blue'}, COR={'Ranged Acc','Roll Support','Quick Draw'},
    PUP={'Master Acc','Frame Gear','Overload'}, DNC={'Step Accuracy','Waltz Potency','Evasion'},
    SCH={'Spell Landing','Helix Potency','Light Support'},
};
for _,job in ipairs(classic.jobs) do
    local jobModes=classic.special[job];
    local planned=classic.planned[job];
    local options=jobModes or {{planned[1]},{planned[2]},{planned[3]}};
    local entries={{'PDT','pdt','defence','pdt'},{'MDT','mdt','defence','mdt'},
        options[1],options[2],{'Clear Defence','defence none','defence','none'},options[3]};
    local layout={};
    for i,entry in ipairs(entries) do
        local verb=jobModes and entry[2];
        local command=verb and (verb:sub(1,1)=='/' and verb or '/lac fwd '..job:lower()..' '..verb);
        layout[i]={row='CTRL',slot=1,label=entry[1],source='command',command=command or nil,
            axis=entry[3],value=entry[4],job=job,kind='utility'};
    end
    classic.layouts[job]=layout;
end
function classic.identity()
    if not state.profileReady then return; end
    local ok,id,job,level,sub,sublvl=pcall(function()
        local mm=AshitaCore:GetMemoryManager();
        local player,party=mm:GetPlayer(),mm:GetParty();
        return party:GetMemberServerId(0),player:GetMainJob(),player:GetMainJobLevel(),player:GetSubJob(),player:GetSubJobLevel();
    end);
    if ok and type(id)=='number' and id>0 and classic.jobs[job] and type(level)=='number' and level>0
        and type(sub)=='number' and type(sublvl)=='number' then
        return classic.jobs[job],level,id,job,sub,sublvl;
    end
end
function classic.slots()
    if not state.classic75 then return state.statebarSlots,state.statebarHotkeys; end
    local job,level=classic.identity();
    local layout=classic.layouts[job];
    if not layout then return classic.empty,classic.empty,job,level; end
    if classic.order~=state.classicOrder or classic.orderedJob~=job then
        classic.order=state.classicOrder; classic.orderedJob=job;
        classic.ordered,classic.orderedKeys={}, {};
        for i,index in ipairs(state.classicOrder) do
            classic.ordered[i]=layout[index]; classic.orderedKeys[i]=classic.keys[index];
        end
    end
    return classic.ordered,classic.orderedKeys,job,level;
end
function classic.available(button,job,level)
    return button and button.command and button.job==job and level==75;
end
function classic.saved_modes()
    local job,level,id,jobId,sub,sublvl=classic.identity();
    if level~=75 or not classic.special[job] then return nil; end
    local scope=job=='PLD' and table.concat({id,jobId,level,sub,sublvl},'_')
        or table.concat({id,jobId,level,'shared_subjobs'},'_');
    local t=os.clock();
    if classic.scope==scope and t<(classic.readAt or 0) then return classic.saved; end
    classic.scope=scope; classic.readAt=t+.5; classic.saved=nil;
    local ok,result=pcall(function()
        local root=AshitaCore:GetInstallPath():gsub('\\','/'):gsub('/+$','');
        if classic.root~=root or not classic.modes then
            classic.modes=dofile(root..'/addons/aegis/aegis/swap_modes.lua'); classic.root=root;
        end
        local f=io.open(root..'/config/addons/aegis/'..id..'/profiles/'..job..'/swap_'..scope..'.aegis','rb');
        if not f then return; end
        local raw=f:read(1025); f:close();
        return classic.modes.decode(raw,scope);
    end);
    if ok then classic.saved=result; end
    return classic.saved;
end

-- Direct mode buttons use the same saved state as the Classic 75 presets.
-- Native macro bodies are opaque to Decker, so those slots can opt into PDT/MDT tracking.
classic.modeCommands={
    pdt={'defence','pdt'}, mdt={'defence','mdt'},
    ['defence fire']={'defence','fire'}, ['defence evasion']={'defence','evasion'},
    ['defence earth']={'defence','earth'}, ['defence ice']={'defence','ice'},
    accuracy={'base','accuracy'}, kite={'kite',true},
    ['casting accuracy']={'casting','accuracy'}, ['casting damage']={'casting','damage'},
    ['casting burst']={'casting','burst'}, ['casting enmity']={'casting','enmity'},
    ['ws accuracy']={'ws','accuracy'},
    ['defence none']={}, auto={}, disable={}, ['casting normal']={}, ['ws normal']={}, ['casting cycle']={},
};
function classic.tracked_mode(button)
    if button.source~='command' then
        if button.trackDefence then return true,'defence',button.trackDefence; end
        return false;
    end
    local profile,operation=(button.command or ''):match('^/lac fwd ([a-z]+) (.+)$');
    local job=profile and profile:upper();
    local mode=classic.modeCommands[operation];
    if mode and (classic.special[job] or job=='TANK') then return true,mode[1],mode[2],job; end
    return false;
end
function classic.highlight(button,index,saved,job,unavailable)
    if unavailable then return false,nil; end
    local axis,value=button.axis,button.value;
    local tracked,owner;
    if not state.classic75 then
        local modeAxis,modeValue;
        tracked,modeAxis,modeValue,owner=classic.tracked_mode(button);
        if not tracked then
            return button.kind~='utility' and state.statebarSelected==index or false,
                state.statebarSelected==index and 'manual' or nil;
        end
        if owner and owner~=job and not (owner=='TANK' and (job=='PLD' or job=='NIN' or job=='RDM')) then return false,nil; end
        axis,value=modeAxis,modeValue;
    end
    -- Green means current saved Aegis mode is verified. 'locked' is not a
    -- different mode; it must not hide which defence mode is selected.
    if axis and saved then
        return saved.enabled and saved[axis]==value, 'verified';
    end
    -- If no Aegis readback is available, give amber feedback for a queued
    -- command instead of incorrectly claiming the gear has changed (green).
    if tracked and axis and state.statebarSelected==index then return true,'pending'; end
    return false,nil;
end

-- Single validated command only: no Lua, script runners, command chaining or chat.
local function valid_command(command)
    if type(command)~='string' or #command>240 or command:find('[%c;|]') then return false; end
    if command:match('^/equipset %d+$') then local n=tonumber(command:match('%d+')); return n>=1 and n<=100; end
    if command:match('^/lac set [%w_%-]+$') then return true; end
    local duration=tonumber(command:lower():match('^/lac set convert (%d+)$'));
    if duration then return duration>=1 and duration<=15; end
    local profile,operation=command:match('^/lac fwd ([a-z]+) (.+)$');
    if profile=='pld' or profile=='tank' or profile=='nin' or profile=='rdm' or profile=='blm' or profile=='whm' then
        if operation=='pdt' or operation=='mdt' or operation=='defence none' or operation=='disable' then return true; end
    end
    if profile=='tank' or profile=='rdm' then
        if operation=='casting accuracy' then return true; end
    end
    if profile=='tank' or profile=='nin' or profile=='rdm' or profile=='pld' then
        if operation=='pdt' or operation=='mdt' or operation=='accuracy' or operation=='auto'
            or operation=='kite' or operation=='ws normal' or operation=='ws accuracy' then return true; end
        if profile~='pld' and (operation=='defence fire' or operation=='defence evasion'
            or operation=='defence none') then return true; end
        if (profile=='tank' or profile=='nin') and (operation=='defence earth' or operation=='defence ice') then return true; end
        if (profile=='tank' or profile=='rdm') and operation=='casting enmity' then return true; end
    elseif profile=='blm' and (operation=='casting normal' or operation=='casting accuracy'
        or operation=='casting damage' or operation=='casting burst' or operation=='casting cycle') then
        return true;
    end
    if command:match('^/item "[^"<>]+" <me>$') or command:match('^/ma "[^"<>]+" <me>$') or command:match('^/ja "[^"<>]+" <me>$') or command:match('^/mount "[^"<>]+"$') then return true; end
    return false;
end
local function request_statebar(i)
    if state.guideOpen or state.layoutEditing or state.guardEditing then return false; end -- Editors cannot fire StateBar actions.
    local slots,_,job,level=classic.slots();
    local b=slots[i]; if not b or not state.profileReady then return false; end
    if state.classic75 and not classic.available(b,job,level) then return false; end
    local requested=false;
    if b.source=='command' then
        if not valid_command(b.command) then state.clickSummary='StateBar command blocked: use a supported single command.'; return false; end
        local metric=analytics.attempt('STATEBAR',i,'statebar');
        local ok,result=pcall(function() return AshitaCore:GetChatManager():QueueCommand(-1,b.command); end); requested=ok and result~=false;
        analytics.finish(metric,requested);
    else requested=execute_slot(b.row,b.slot,'statebar'); end
    if requested and state.autoHide and state.autoHideDelay==0 then state.hudImmediateHide=true; end
    if requested then
        local tracked,axis,value=classic.tracked_mode(b);
        classic.readAt=0;
        if state.classic75 then
            state.clickSummary='Requested '..b.label..'; check saved mode or /lac fwd '..b.job:lower()..' status.';
        elseif tracked and not axis then
            state.statebarSelected=0;
        elseif tracked then
            -- Aegis readback takes precedence. Until it is available, retain
            -- an amber requested-mode indicator instead of blanking the StateBar.
            local defenceToggle=axis=='defence' and (value=='pdt' or value=='mdt');
            if defenceToggle and state.statebarSelected==i then state.statebarSelected=0;
            else state.statebarSelected=i; end
        elseif b.kind~='utility' then
            if state.statebarSelected==i then state.statebarSelected=0;
            else state.statebarSelected=i; end
        end
    end
    return requested;
end
function classic.reorder(from,to)
    if from==to then return; end
    if state.classic75 then
        local order=copy_value(state.classicOrder);
        table.insert(order,to,table.remove(order,from));
        state.classicOrder=order;
    else
        local slots,keys=state.statebarSlots,state.statebarHotkeys;
        local key=keys[from];
        table.insert(slots,to,table.remove(slots,from));
        local step=from<to and 1 or -1;
        for i=from,to-step,step do keys[i]=keys[i+step]; end
        keys[to]=key;
        local selected=state.statebarSelected;
        if selected==from then state.statebarSelected=to;
        elseif from<to and selected>from and selected<=to then state.statebarSelected=selected-1;
        elseif from>to and selected<from and selected>=to then state.statebarSelected=selected+1; end
    end
    save_display();
end
local function restore_section(section)
    for _,key in ipairs(sectionKeys[section] or {}) do state[key]=copy_value(profileDefaults[key]); end
    if section=='Appearance' then state.hudPos=nil; end
    if section=='StateBar' then state.statebarDrag=nil; end
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
        local restoreNavigation=state.savedKeybinds and not state.savedNavEnabled;
        if restoreNavigation then state.savedNavEnabled=true; end
        state.navKeysEnabled=state.savedNavEnabled;
        state.navToggleActive=false;
        -- A successful manual connection authorizes future automatic reconnection for this character.
        if not state.autoConnect then state.autoConnect=true; save_display();
        elseif restoreNavigation then save_display(); end
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
    windowGeometry[id]=windowGeometry[id] or {pos=copy_value(state.windowPositions[id] or {20,20}),restore=true};
    return windowGeometry[id];
end
local function pin_window(id,locked)
    local g=geometry(id);
    if (locked or g.restore) and g.pos and type(imgui.SetNextWindowPos)=='function' then
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
        imgui.SetNextWindowPos(g.pos,ImGuiCond_Always or 1); g.restore=false;
    end
end
local function remember_window(id,locked)
    local g=geometry(id);
    if type(imgui.GetWindowPos)=='function' then
        local ok,a,b;
        if locked and g.pos then ok,a=true,g.pos; else ok,a,b=pcall(imgui.GetWindowPos); end
        if ok then
            local x,y=pair(a,b);
            if x and y and x==x and y==y and math.abs(x)<=20000 and math.abs(y)<=20000 then
                x,y=math.floor(x),math.floor(y);
                g.pos={x,y};
                local old=state.windowPositions[id];
                if state.profileReady and (not old or old[1]~=x or old[2]~=y) then
                    state.windowPositions[id]={x,y}; state.layoutDirtyAt=os.clock();
                end
            end
        end
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
local function draw_glass_text(dl,text,x,y,w,h,shortcut,cooling,isStateBar,recastLabel,unavailable)
    local textScale=isStateBar and state.statebarScale or state.scale;
    local preferredLabel=isStateBar and state.statebarLabelSize>0 and state.statebarLabelSize or state.macroFontSize;
    local keySize=isStateBar and math.min(state.statebarKeySize*textScale,h*.45)
        or math.min(10*textScale,math.max(7,h/4));
    local keyInset=isStateBar and 6 or 3;
    local footer=isStateBar and (shortcut~='' and keySize+keyInset+1 or 0) or 12;
    local minTitleSize=isStateBar and 7 or 10;
    local titleHeight=h-footer-(isStateBar and 2 or 6);
    local initialSize=math.min(preferredLabel*textScale,math.max(minTitleSize,titleHeight));
    local font=glass_font_for(initialSize);
    imgui.PushFont(font);
    local ok,err=pcall(function()
        local natural=imgui.GetTextLineHeight();
        local function width(t,size)
            local tw=pair(imgui.CalcTextSize(t)); return (tw or 0)*size/natural;
        end
        local size=initialSize;
        local shown=text;
        if width(shown,size)>w-10 then
            size=math.max(minTitleSize,math.min(size,(w-10)/math.max(1,width(shown,1))));
        end
        while #shown>0 and width(shown,size)>w-10 do
            -- Native macro names are byte strings. Do not split UTF-8 continuation bytes.
            shown=shown:match('^(.*)[%z\1-\127\194-\244][\128-\191]*$') or '';
        end
        if shown~=text then
            while #shown>0 and width(shown..'...',size)>w-10 do shown=shown:match('^(.*)[%z\1-\127\194-\244][\128-\191]*$') or ''; end
            shown=shown..'...';
        end
        local col=imgui.GetColorU32(unavailable and {1,.63,.23,1} or cooling and {1,.30,.30,1} or {.96,.96,.97,1});
        local tx=x+(w-width(shown,size))/2; local ty=y+math.max(2,(h-footer-size)/2);
        dl:AddText(font,size,{tx+1,ty+1},imgui.GetColorU32({0,0,0,1}),shown);
        dl:AddText(font,size,{tx,ty},col,shown);
        if shortcut~='' then
            local ks=keySize;
            if width(shortcut,ks)>w-10 then ks=ks*(w-10)/math.max(1,width(shortcut,ks)); end
            dl:AddText(font,ks,{x+w-width(shortcut,ks)-5,y+h-ks-keyInset},imgui.GetColorU32({.68,.70,.74,1}),shortcut);
        end
    end);
    imgui.PopFont();
    if not ok then error(err); end
end
local function draw_glass_face(dl,x,y,w,h,opacity,accent)
    if dl.AddRectFilledMultiColor then
        local light=imgui.GetColorU32({.78,.87,1,.15*opacity});
        local dark=imgui.GetColorU32({0,0,0,.20*opacity});
        dl:AddRectFilledMultiColor({x+2,y+2},{x+w-2,y+h-2},light,light,dark,dark);
    end
    if dl.AddRect then
        dl:AddRect({x+1,y+1},{x+w-1,y+h-1},
            imgui.GetColorU32(accent or {.67,.75,.88,.23*opacity}),3,0,1);
    end
    if accent and dl.AddRectFilled then
        dl:AddRectFilled({x+5,y+h-4},{x+w-5,y+h-2},imgui.GetColorU32(accent),1);
    end
end
local function draw_row(title,offset)
    local now=os.clock(); -- One animation clock sample for the entire row.
    local order=current_macro_layout();
    local page,fingerprint=cooldown.page();
    local w=math.floor(state.hudWidth*state.scale);
    local h=math.floor(state.hudHeight*state.scale);
    for i=1,10 do
        if i>1 then imgui.SameLine(); end
        local visualIndex=offset+i;
        local physicalIndex=order[visualIndex] or visualIndex;
        local name=state.names[physicalIndex] or '';
        local shortcut=state.mappingMode=='numbers' and tostring(i==10 and 0 or i)
            or state.mappingMode=='functions' and ('F'..i)
            or DIRECT_NAMES[state.directKeys[offset+i]] or '?';
        if not state.compactKeys then shortcut=title..' '..tostring(i==10 and 0 or i)..' | '..shortcut; end
        local e=state.lastExecuted;
        local physicalRow=physicalIndex<=10 and 'CTRL' or 'ALT';
        local physicalSlot=((physicalIndex-1)%10)+1;
        local flashing=state.flashRow==physicalRow and state.flashSlot==physicalSlot and now<state.flashUntil;
        local remembered=e and e.row==physicalRow and e.slot==physicalSlot and e.set==state.trackedSet and e.name==name and state.trackedSource~='unverified (same names)';
        local selected=(state.navRow==title and state.navSlot==i) or (state.layoutEditing and state.layoutSelected==visualIndex);
        local guarded=macro_guarded(physicalIndex);
        local binding=cooldown.binding(page,fingerprint,physicalIndex);
        if not binding then
            local inferred,why=cooldown.infer_macro(physicalIndex);
            binding=inferred or (why=='unavailable' and cooldown.infer(name) or nil);
        end
        local remaining=cooldown_recast(binding);
        local unavailable=selector.unavailable(physicalIndex);
        local cooling=not unavailable and remaining~=nil and remaining>0;
        local recastKey=binding and ((page or 'inferred.')..physicalIndex..':'..binding.kind..':'..binding.id);
        if recastKey and remaining then cooldown.observe(recastKey,remaining); end
        local a=state.buttonOpacity;
        local accents={{.30,.22,.10,a},{.10,.23,.34,a},{.25,.15,.33,a},{.23,.25,.28,a}};
        local base=flashing and {.45,.34,.13,a} or remembered and (accents[state.theme] or accents[1]) or {.025,.028,.035,a};
        local nc,nv=0,0;
        local function colour(id,value) if type(id)=='number' and imgui.PushStyleColor and imgui.PopStyleColor then imgui.PushStyleColor(id,value); nc=nc+1; end end
        colour(ImGuiCol_Button,base);
        colour(ImGuiCol_ButtonHovered,{base[1]+.05,base[2]+.05,base[3]+.05,a});
        colour(ImGuiCol_ButtonActive,{.45,.34,.13,a});
        colour(ImGuiCol_Text,unavailable and {1,.63,.23,1} or cooling and {1,.3,.3,1} or {.96,.96,.97,1});
        colour(ImGuiCol_Border,selected and {.85,.68,.30,1} or {0,0,0,0});
        if type(ImGuiStyleVar_FrameBorderSize)=='number' and imgui.PushStyleVar and imgui.PopStyleVar then
            imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize,selected and 1 or 0); nv=1;
        end
        local custom=glass_available();
        local x,y;
        if custom then x,y=pair(imgui.GetCursorScreenPos()); custom=x~=nil; end
        local sourceLabel=state.layoutEditing and (state.layoutSelected==visualIndex
                and ('SELECTED - CLICK DESTINATION | FROM '..physicalRow..' '..tostring(physicalSlot==10 and 0 or physicalSlot))
                or ('CLICK TO SELECT | FROM '..physicalRow..' '..tostring(physicalSlot==10 and 0 or physicalSlot)))
            or state.guardEditing and (guarded and 'GUARDED' or 'CLICK TO GUARD')
            or guarded and '2HR LOCK' or shortcut;
        local label=custom and '' or (name..'\n'..sourceLabel);
        local clicked=imgui.Button(label..'##decker_'..title..i,{w,h});
        if nc>0 then imgui.PopStyleColor(nc); end
        if nv>0 then imgui.PopStyleVar(); end
        if custom then
            local ok,err=pcall(function()
                local dl=imgui.GetWindowDrawList();
                draw_glass_face(dl,x,y,w,h,a,selected and {.85,.68,.30,1} or nil);
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
                draw_glass_text(dl,name,x,y,w,h,sourceLabel,cooling,false,nil,unavailable);
                if cooling and type(dl.AddLine)=='function' then
                    local totalKey='max:'..recastKey;
                    local high=recastObserver.observed[totalKey] or remaining;
                    if remaining>high then high=remaining; end
                    recastObserver.observed[totalKey]=high;
                    local frac=cooldown.fraction(remaining,high);
                    local cx,cy=x+w-13,y+13;
                    local rad=math.max(6,math.min(10,h*.25));
                    for seg=1,12 do
                        if seg<=math.ceil(frac*12) then
                            local aa=(seg-1)*math.pi/6-math.pi/2;
                            local bb=seg*math.pi/6-math.pi/2;
                            dl:AddLine({cx+math.cos(aa)*rad,cy+math.sin(aa)*rad},
                                {cx+math.cos(bb)*rad,cy+math.sin(bb)*rad},
                                imgui.GetColorU32({.95,.73,.32,.95}),2);
                        end
                    end
                end
            end);
            if not ok then glass.custom=false; glass.diagnostic='Host draw API fallback: '..tostring(err); end
        end
        if imgui.IsItemHovered and imgui.SetTooltip and imgui.IsItemHovered() and name~='' then imgui.SetTooltip(name); end
        if clicked then
            if state.guardEditing then
                local saved,enabled=toggle_macro_guard(physicalIndex);
                if saved then say(enabled and ('2-hour guard enabled for '..name..'.') or ('2-hour guard removed from '..name..'.'),true);
                else say('Could not save the macro guard; profile write failed.',true); end
            elseif state.layoutEditing then
                if state.layoutDraftKey==macro_layout_key() then
                    if not state.layoutSelected then state.layoutSelected=visualIndex;
                    elseif state.layoutSelected==visualIndex then state.layoutSelected=nil;
                    else swap_macro_layout_slots(state.layoutSelected,visualIndex); end
                else cancel_macro_layout(); end
            else execute_slot(title,i,'mouse'); end
        end
    end
end
-- Draw the panel behind the two rows without introducing a child window or changing layout.
function classic.draw_font_controls()
    for _,option in ipairs({
        {'Action label size','statebarLabelSize',10,28},
        {'Hotkey label size','statebarKeySize',8,18},
    }) do
        local label,key,min,max=option[1],option[2],option[3],option[4];
        local size=state[key]>0 and state[key] or state.macroFontSize;
        imgui.Text(('%s (%d)'):format(label,math.floor(size)));
        imgui.SameLine();
        if imgui.Button('-##'..key) and size>min then state[key]=math.max(min,size-1); save_display(); end
        imgui.SameLine();
        if imgui.Button('+##'..key) and size<max then state[key]=math.min(max,size+1); save_display(); end
    end
    if state.statebarLabelSize>0 then
        imgui.SameLine();
        if imgui.Button('Match macro label size##sbfont') then state.statebarLabelSize=0; save_display(); end
    end
    if not glass_available() then imgui.TextWrapped('This client is using the default button font.'); end
end
function classic.draw_order_editor()
    local slots,keys,job=classic.slots();
    if not state.profileReady or #slots==0 then state.statebarDrag=nil; return; end
    local canDrag=true;
    for _,name in ipairs({'IsItemActive','IsMouseDragging','IsMouseDown','IsMouseReleased',
        'GetItemRectMin','GetItemRectMax','IsMouseHoveringRect'}) do
        if type(imgui[name])~='function' then canDrag=false; break; end
    end
    imgui.TextWrapped(canDrag and 'Slot order. Drag a slot up or down, or use its arrows. The hotkey moves with the slot.'
        or 'Slot order. Use the Up and Down buttons. The hotkey moves with the slot.');
    local drag=state.statebarDrag;
    if not canDrag or (drag and (drag.preset~=state.classic75 or drag.job~=job)) then drag=nil; end
    local from,to,target;
    for i,b in ipairs(slots) do
        local key=DIRECT_NAMES[keys[i] or 0] or 'None';
        local name=b.label and b.label~='' and b.label
            or (b.source~='command' and state.names[(b.row=='ALT' and 10 or 0)+b.slot])
            or ('Slot '..i);
        if name=='' then name='Slot '..i; end
        imgui.Button(('%s  [%s]##statebarorder%d'):format(name,key,i),{215,0});
        if canDrag then
            if imgui.IsItemActive() and imgui.IsMouseDragging(0) then
                drag={from=i,preset=state.classic75,job=job};
            end
            local x1,y1=pair(imgui.GetItemRectMin());
            local x2,y2=pair(imgui.GetItemRectMax());
            if x1 and x2 and imgui.IsMouseHoveringRect({x1,y1},{x2,y2},true) then
                target=i;
                if drag and i~=drag.from and glass_available() then
                    local y=i<drag.from and y1 or y2-2;
                    local dl=imgui.GetWindowDrawList();
                    if dl.AddRectFilled then
                        dl:AddRectFilled({x1,y},{x2,y+2},imgui.GetColorU32({.42,.74,1,1}));
                    end
                end
            end
        end
        if i>1 then
            imgui.SameLine();
            if imgui.Button('Up##statebarorder'..i) then from,to=i,i-1; end
        end
        if i<#slots then
            imgui.SameLine();
            if imgui.Button('Down##statebarorder'..i) then from,to=i,i+1; end
        end
    end
    if drag and imgui.IsMouseReleased(0) then
        if target then from,to=drag.from,target; end
        drag=nil;
    elseif drag and not imgui.IsMouseDown(0) then
        drag=nil;
    end
    if from then classic.reorder(from,to); drag=nil; end
    state.statebarDrag=drag;
end

local function draw_macro_panel()
    if not glass_available() then return; end
    pcall(function()
        local x,y=pair(imgui.GetCursorScreenPos());
        local aw=pair(imgui.GetContentRegionAvail());
        if not x or not aw then return; end
        local dl=imgui.GetWindowDrawList();
        local bottom=y+state.hudHeight*state.scale*2+6;
        dl:AddRectFilled({x-2,y-2},{x+aw,bottom},imgui.GetColorU32({.025,.035,.06,state.panelOpacity}),5);
        if dl.AddRect then
            dl:AddRect({x-2,y-2},{x+aw,bottom},imgui.GetColorU32({.67,.75,.88,state.panelOpacity*.65}),5,0,1);
        end
    end);
end

-- Small, original preview UI. A guide click only changes guideDemoRow/guideDemoMode;
-- it NEVER reaches native macro execution, SetBook/SetPage or the StateBar.
local GUIDE_STEPS={
    {'Meet your two rows','Your original FFXI CTRL and ALT macro rows remain together in Decker. Tap the example labels below to explore them; these are fictional examples, NOT your actual macros.'},
    {'Selecting versus executing','A selection highlight is not an execution. Decker executes only on your actual approved mouse/keyboard input outside this guide. Tap Flash or Cure to move the example highlight safely.'},
    {'Hold and Toggle','Hold shows the macro HUD while the modifier is pressed. Toggle locks its visibility until switched off or auto-hide. Try the two demonstration modes; your real preference does not change.'},
    {'Books, sets and StateBar','The Macro set selector moves across sets 1-10, and Book across books 1-20 when connected. StateBar provides separate state/utility slots; Aegis modes use saved profile state and manual highlights toggle on press.'},
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
-- Keyboard overrides remain opt-in. Ashita IsInputOpen() protects chat.
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
    if not state.statebarEnabled or not state.statebarHotkeysEnabled or not state.profileReady then return false; end
    if not state.classic75 then
        local commandsOnly=#state.statebarSlots>0;
        for _,b in ipairs(state.statebarSlots) do
            if b.source~='command' or not valid_command(b.command) then commandsOnly=false; break; end
        end
        if commandsOnly then return true; end
    end
    return state.allowAllClicks and state.phase>=4 and #state.names==20;
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
local function nav_scan() return NAV_KEYS[state.navModifier] or 54; end
local function other_modifier_down()
    for _,key in ipairs({29,157,56,184,42,54}) do
        if key~=nav_scan() and key~=(ROW_KEYS[state.rowSwitchKey] or 207) and state.held[key] then return true; end
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
local function row_key() local key=ROW_KEYS[state.rowSwitchKey] or 207; return key~=nav_scan() and key or -1; end
local NAV_ACTIONS={ [200]=true,[208]=true,[203]=true,[205]=true,[57]=true,[28]=true,[156]=true };
local NAV_ARROWS={ [200]=true,[208]=true,[203]=true,[205]=true };
local function game_input_open()
    local ok,flag=pcall(function() return AshitaCore:GetChatManager():IsInputOpen(); end)
    -- Chat input is safety-critical; unknown state must fail closed.
    return not ok or flag==nil or (flag~=false and flag~=0)
end
local function yield_chat_input()
    if inputDiag.enabled and (state.navToggleActive or state.navModifierHeld
        or next(state.suppressed) or next(state.navCaptured)) then
        trace_input('chat','release-captured-state',-1,'state',false,true,false,state.navModifierHeld)
    end
    -- Port the v1.50.34 chat-state reset onto the newer native-target handoff.
    -- Never suppress a physical key while the game owns chat input.
    state.navToggleActive=false;state.navModifierHeld=false
    state.navQueue={};state.deferredNav={};state.navCaptured={}
    state.navRepeatAt={};state.navPhysicalKeys={}
    state.suppressed={};state.held={};state.nativeNavHeld={}
end
state.targetHandoffUntil=0;state.targetGraceUntil=0
function selector.end_explicit()
    selector.explicitUntil=nil;
    state.targetHandoffUntil=0; state.targetGraceUntil=0;
    selector.macroPrompt=false;
end
function selector.begin_handoff(subtargetBefore,expectsTarget)
    -- Short grace, applied to navigation arrows/Enter only. Do not gate direct
    -- ability keys or StateBar gear commands during engaged combat.
    state.targetHandoffUntil=os.clock()+5;state.targetGraceUntil=os.clock()+0.35
    selector.subtargetBefore=subtargetBefore;
    selector.macroPrompt=false;
    selector.explicitUntil=expectsTarget and (os.clock()+30) or nil;
    -- Keep the user's toggle and the owner of any key still held.
    state.navQueue={};state.deferredNav={};
    state.navRepeatAt={};
end
function selector.handoff_active()
    local now=os.clock();
    if selector.explicitUntil and now<selector.explicitUntil then return true; end
    local prompt=selector.active();
    -- When the host exposes both flags, protect actual native targeting even
    -- when launched outside Decker. Bare subtarget flags may stay set in combat,
    -- so do not allow them to hijack navigation forever.
    if prompt and selector.actionSupported then return true; end
    if not selector.subtargetActive then selector.macroPrompt=false; end
    if selector.macroPrompt then return true; end
    if now>=(state.targetHandoffUntil or 0) then return false; end
    if selector.subtargetActive and selector.subtargetBefore==false then
        selector.macroPrompt=true;
        return true;
    end
    if prompt then return true; end
    return now<(state.targetGraceUntil or 0);
end
function selector.read_subtarget()
    local ok,flag=pcall(function()
        return AshitaCore:GetMemoryManager():GetTarget():GetIsSubTargetActive();
    end);
    if not ok or (type(flag)~='boolean' and type(flag)~='number') then return nil; end
    return flag==true or (type(flag)=='number' and flag>0);
end
function selector.active()
    local subActive=selector.read_subtarget();
    local actionOk,action=pcall(function()
        return AshitaCore:GetMemoryManager():GetTarget():GetActionTargetActive();
    end);
    selector.supported=subActive~=nil;
    selector.subtargetActive=subActive;
    selector.actionSupported=actionOk and (type(action)=='boolean' or type(action)=='number');
    if not selector.supported then return false; end
    if selector.actionSupported then
        return subActive and (action==true or (type(action)=='number' and action>0));
    end
    return subActive;
end
function selector.yield_navigation()
    state.navQueue={}; state.deferredNav={};
    state.navRepeatAt={}; state.navPhysicalKeys={};
end
function selector.validate_queue()
    if #state.navQueue>0 or (state.deferredNav and #state.deferredNav>0) then
        if game_input_open() then yield_chat_input();
        elseif selector.handoff_active() then selector.yield_navigation(); end
    end
end
local NAV_REPEAT_DELAY=.35;
local NAV_REPEAT_INTERVAL=.08;
state.navRepeatAt={};
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
    state.navRepeatAt={};
    state.navPhysicalDown=false;
    state.navPhysicalKeys={}; state.navQueue={}; state.deferredNav={}; state.navSetVerifyFrames=0; state.navSetExpectedFingerprint=nil;
end
-- Navigation is queued and run from the UI frame. Set changes are deferred
-- a few frames so native input state can settle before calling set_page.
local function nav_command(key, repeating)
    if state.guideOpen then return; end -- No real set/page actions during a tutorial.
    state.hudLastActivity=os.clock();
    if key==200 or key==208 then
        state.deferredNav=state.deferredNav or {};
        state.deferredNav[#state.deferredNav+1]={key=key,frames=4,repeating=repeating};
    elseif key==57 or key==row_key() then
        state.navSlot=state.navSlot or 1;
        local row=state.navRow or 'CTRL';
        state.navRow=(row=='CTRL') and 'ALT' or 'CTRL';
        state.navSource='Decker navigation';
    elseif key==203 or key==205 then
        state.navSlot=((state.navSlot or 1)-1+(key==203 and -1 or 1))%10+1;
        state.navSource='Decker navigation';
    elseif key==28 or key==156 then
        execute_slot(state.navRow or 'CTRL',state.navSlot or 1,'navigation');
        -- Native target-selection handoff begins on successful macro execution.
    end
end
-- key_data only suppresses input. Physical key edges are processed from
-- key_state once, preventing inconsistent arrow events on VanaCore.
ashita.events.register('key_data','decker_custom_set_navigation',function(e)
    if game_input_open() then
        trace_input('navigation','yield-chat',e.key,e.down and 'down' or 'up',false,true,false,false)
        yield_chat_input();return
    end
    if not state.navKeysEnabled then return; end
    if e.key==1 and not e.down then
        selector.end_explicit();
    end
    if e.key==nav_scan() then
        if selector.handoff_active() then
            trace_input('navigation','yield-target',e.key,e.down and 'down' or 'up',false,false,true,false)
            return
        end
        e.blocked=true
        trace_input('navigation','capture-modifier',e.key,e.down and 'down' or 'up',true,false,false,true)
        return
    end
    if not NAV_ACTIONS[e.key] and e.key~=row_key() then return; end
    state.nativeNavHeld=state.nativeNavHeld or {};
    if selector.handoff_active() or state.nativeNavHeld[e.key] then
        trace_input('navigation','yield-native-target',e.key,e.down and 'down' or 'up',false,false,true,false)
        selector.yield_navigation();
        if state.navCaptured[e.key] then
            e.blocked=true;
            if not e.down then state.navCaptured[e.key]=nil; end
        else
            if not e.down and state.nativeNavHeld[e.key] and (e.key==28 or e.key==156) and selector.explicitUntil then
                selector.end_explicit();
            end
            state.nativeNavHeld[e.key]=e.down and true or nil;
        end
        return;
    end
    if nav_is_active() or state.navCaptured[e.key] then
        e.blocked=true
        trace_input('navigation','capture-navigation',e.key,e.down and 'down' or 'up',true,false,false,true)
        -- Some clients deliver the first arrow press through key_data before
        -- key_state has populated its physical-edge cache. Capture that edge
        -- here so navigation works before clicking any macro or focusing HUD.
        if e.down and not state.navCaptured[e.key] then
            state.navCaptured[e.key]=true;
            if NAV_ARROWS[e.key] then state.navRepeatAt[e.key]=os.clock()+NAV_REPEAT_DELAY; end
            state.navQueue[#state.navQueue+1]=e.key;
            state.hudLastActivity=os.clock();
        elseif not e.down then
            state.navCaptured[e.key]=nil;
            state.navPhysicalKeys[e.key]=false;
            state.navRepeatAt[e.key]=nil;
        end
    end
end);
ashita.events.register('key_state','decker_custom_set_state',function(e)
    if not e.data_raw or (type(e.size)=='number' and e.size<256) then return; end
    local ptr=ffi.cast('uint8_t*',e.data_raw);
    local modifier=nav_scan();
    local physicalDown=ptr[modifier]~=0;
    for _,key in ipairs({29,157,56,184,42,54}) do
        if ptr[key]==0 then state.held[key]=nil; end
    end
    if game_input_open() then
        if physicalDown~=state.navPhysicalDown then
            trace_input('modifier','physical-edge-during-chat',modifier,physicalDown and 'down' or 'up',false,true,false,physicalDown)
        end
        state.navPhysicalDown=physicalDown
        yield_chat_input()
        return
    end
    local targeting=state.navKeysEnabled and selector.handoff_active();
    if physicalDown~=state.navPhysicalDown then
        trace_input('modifier',targeting and 'yield-target' or 'physical-edge',
            modifier,physicalDown and 'down' or 'up',
            state.navKeysEnabled and not targeting,false,targeting,physicalDown)
    end
    if state.navKeysEnabled and not targeting and state.stickyNavigation
            and physicalDown and not state.navPhysicalDown and not other_modifier_down() then
        state.navToggleActive=not state.navToggleActive; state.hudLastActivity=os.clock(); state.hudForceReveal=true;
        if state.echoLock then
            local word=state.navToggleActive and 'locked' or 'unlocked';
            if state.navToggleActive and type(chat.color1)=='function' then local ok,coloured=pcall(chat.color1,76,word); if ok then word=coloured; end end
            print(chat.header(addon.name)..'Macros '..word);
        end
    end
    if state.navKeysEnabled and not targeting and physicalDown and not state.navPhysicalDown then
        -- Establish a visible navigation cursor without requiring a macro click.
        state.navSlot=state.navSlot or 1;
        state.navRow=state.navRow or 'CTRL';
        state.navSource='Decker navigation';
        -- A modifier press must always be able to wake the HUD, even before macro pointers connect.
        state.hudLastActivity=os.clock(); state.hudHasInteracted=true; state.hudForceReveal=true;
    end
    state.navPhysicalDown=physicalDown;
    state.navModifierHeld=physicalDown;
    local active=state.navKeysEnabled
        and (state.stickyNavigation and state.navToggleActive or
             (not state.stickyNavigation and physicalDown))
        and not other_modifier_down();
    if state.navKeysEnabled and not targeting then ptr[modifier]=0; end
    if targeting then selector.yield_navigation(); end
    state.nativeNavHeld=state.nativeNavHeld or {};
    local activeKeys={}; for key,_ in pairs(NAV_ACTIONS) do activeKeys[key]=true; end;
    local rowKey=row_key();
    if rowKey>=0 then activeKeys[rowKey]=true; end
    for key,_ in pairs(activeKeys) do
        local wasDown=state.navPhysicalKeys[key] or false;
        local nowDown=ptr[key]~=0;
        if targeting or state.nativeNavHeld[key] then
            if state.navCaptured[key] then
                if nowDown then ptr[key]=0; else state.navCaptured[key]=nil; end
            else
                if not nowDown and state.nativeNavHeld[key] and (key==28 or key==156) and selector.explicitUntil then
                    selector.end_explicit();
                end
                state.nativeNavHeld[key]=nowDown and true or nil;
            end
        else
            -- Captured keys remain blocked until physically released.
            if active and nowDown and not wasDown and not state.navCaptured[key] then
                state.navCaptured[key]=true;
                if NAV_ARROWS[key] then state.navRepeatAt[key]=os.clock()+NAV_REPEAT_DELAY; end
                state.navQueue[#state.navQueue+1]=key; state.hudLastActivity=os.clock();
            end
            -- Only arrows repeat. Physical polling owns cadence; OS key-repeat
            -- notifications cannot double-step, and missed frames never burst.
            if NAV_ARROWS[key] then
                if active and nowDown and state.navCaptured[key] and not state.guideOpen then
                    local due=state.navRepeatAt[key];
                    if due and os.clock()>=due then
                        state.navQueue[#state.navQueue+1]={key=key,repeating=true};
                        state.navRepeatAt[key]=os.clock()+NAV_REPEAT_INTERVAL;
                    elseif not due then
                        state.navRepeatAt[key]=os.clock()+NAV_REPEAT_DELAY;
                    end
                else
                    state.navRepeatAt[key]=nil;
                end
            end
            state.navPhysicalKeys[key]=nowDown;
            if not nowDown then state.navCaptured[key]=nil; state.navPressed[key]=nil; end
            if (active or state.navCaptured[key]) and nowDown then ptr[key]=0; end
        end
    end
end);
-- Use native ALT/CTRL + up/down for set selection, refresh the on-screen names
-- after the game's own input handler has processed the press. No arrow blocking.
ashita.events.register('key_data','decker_native_arrow_watch',function(e)
    if game_input_open() then
        -- Chat must never repopulate the held modifiers just cleared by yield_chat_input.
        state.held[29]=nil;state.held[157]=nil;state.held[56]=nil;state.held[184]=nil;
        state.held[42]=nil;state.held[54]=nil;return;
    end
    if e.key==29 or e.key==157 or e.key==56 or e.key==184 or e.key==42 or e.key==54 then
        state.held[e.key]=e.down and true or nil;
    end
    if not game_input_open() and not selector.handoff_active() and not e.blocked and (e.key==200 or e.key==208) and e.down and modifier_down() and not (state.navKeysEnabled and (state.navModifierHeld or state.navToggleActive))
        and state.phase>=4 and #state.names==20 and not selector.active() then
        state.pendingRefreshFrames=3;
        state.awaitingPageFingerprint=state.previousFingerprint;
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
    if not game_input_open() and not selector.handoff_active() and e.down and modifier_down() and state.phase>=4 and not selector.active()
        and not (state.navKeysEnabled and (state.navModifierHeld or state.navToggleActive)) then
        state.navSlot=nil;
        state.navRow=nil;
        state.navSource='Native selection unverified';
    end
end);
-- StateBar has its own explicit keyboard switch; native connection is still required.
-- Only active main shortcuts and enabled navigation reserve keys against it.
local function statebar_hotkey_slot(code,slots,keys,job,level)
    if game_input_open() then
        trace_input('statebar','yield-chat',code,'down',false,true,false,false);return nil
    end
    if not statebar_input_ready() then
        trace_input('statebar','not-ready',code,'down',false,false,false,false);return nil
    end
    if modifier_down() then
        trace_input('statebar','other-modifier-held',code,'down',false,false,false,true);return nil
    end
    if shortcuts_active() and mapped_key(code) then
        trace_input('statebar','macro-key-conflict',code,'down',false,false,false,false);return nil
    end
    if state.navKeysEnabled and (code==nav_scan() or code==row_key() or NAV_ACTIONS[code]) then
        trace_input('statebar','navigation-key-conflict',code,'down',false,false,false,false);return nil
    end
    if not keys then slots,keys,job,level=classic.slots(); end
    local found=nil;
    for i,b in ipairs(slots) do
        if keys[i]==code and code~=0 and (not state.classic75 or classic.available(b,job,level)) then
            if found then
                trace_input('statebar','duplicate-hotkey',code,'down',false,false,false,false)
                return nil
            end
            found=i;
        end
    end
    return found;
end
ashita.events.register('key_data','decker_statebar_key_press',function(e)
    local i=statebar_hotkey_slot(e.key);
    if not i then return end
    if e.blocked then
        trace_input('statebar','blocked-upstream',e.key,e.down and 'down' or 'up',true,false,false,false)
        return
    end
    if state.suppressed[e.key] then
        e.blocked=true
        trace_input('statebar','captured-repeat-or-release',e.key,e.down and 'down' or 'up',true,false,false,false)
        if not e.down then state.suppressed[e.key]=nil; state.held[e.key]=nil; end
        return;
    end
    if e.down then
        e.blocked=true
        if not state.held[e.key] then
            state.held[e.key]=true; state.suppressed[e.key]=true;
            trace_input('statebar','invoke',e.key,'down',true,false,false,false)
            request_statebar(i);
        end
    end
end);
ashita.events.register('key_data','decker_exclusive_key_press',function(e)
    if game_input_open() then
        trace_input('direct','yield-chat',e.key,e.down and 'down' or 'up',false,true,false,false)
        yield_chat_input();return
    end
    -- Native target handoff must not disable independent combat action hotkeys.
    local row,slot=mapped_key(e.key);
    if not row and not state.suppressed[e.key] then return; end
    -- Always finish suppressing a key-release corresponding to a captured press.
    if state.suppressed[e.key] then
        e.blocked=true
        trace_input('direct','captured-repeat-or-release',e.key,e.down and 'down' or 'up',true,false,false,false)
        if not e.down then
            state.suppressed[e.key]=nil;
            state.held[e.key]=nil;
        end
        return;
    end
    if not row then return end
    if not shortcuts_active() then
        trace_input('direct','shortcut-not-ready',e.key,e.down and 'down' or 'up',false,false,false,false);return
    end
    if e.blocked then
        trace_input('direct','blocked-upstream',e.key,e.down and 'down' or 'up',true,false,false,false);return
    end
    if modifier_down() then
        trace_input('direct','other-modifier-held',e.key,e.down and 'down' or 'up',false,false,false,true);return
    end
    if e.down then
        if not state.held[e.key] then
            state.held[e.key]=true;
            state.suppressed[e.key]=true;
            e.blocked=true
            trace_input('direct','invoke',e.key,'down',true,false,false,false)
            execute_slot(row,slot,'direct');
        else
            e.blocked=true
            trace_input('direct','repeat-held',e.key,'down',true,false,false,false)
        end
    end
end);
-- Ashita separates initial DirectInput press (key_data) and held state
-- (key_state). Both must be suppressed to avoid native double execution.
ashita.events.register('key_state','decker_exclusive_key_state',function(e)
    if not e.data_raw then return; end
    if game_input_open() then yield_chat_input();return end
    -- A native subtarget prompt only owns navigation arrows/Enter, not every macro key.
    if not shortcuts_active() and not statebar_input_ready() and next(state.suppressed)==nil then return; end
    local ptr=ffi.cast('uint8_t*',e.data_raw);
    local size=type(e.size)=='number' and e.size or 256;
    local keys={};
    if state.mappingMode=='split' or state.mappingMode=='custom' then
        for _,code in ipairs(state.directKeys) do if code>0 then keys[code]=true; end end
    else
        for i=1,10 do keys[state.mappingMode=='numbers' and (i==10 and 11 or i+1) or 58+i]=true; end
    end
    local slots,hotkeys,job,level=classic.slots();
    if state.statebarEnabled and state.statebarHotkeysEnabled then
        for _,code in pairs(hotkeys) do if code>0 then keys[code]=true; end end
    end
    for code,_ in pairs(state.suppressed) do keys[code]=true; end
    for code,_ in pairs(keys) do
        -- If key_data misses a release, the physical state is authoritative.
        -- Clear captured direct keys as well as StateBar keys before suppression.
        if code<size and state.suppressed[code] and ptr[code]==0 then
            trace_input('physical','missed-release',code,'up',false,false,false,false)
            state.suppressed[code]=nil; state.held[code]=nil;
        end
        local hotkey=code<size and statebar_hotkey_slot(code,slots,hotkeys,job,level);
        if hotkey then
            local down=ptr[code]~=0;
            if down and not state.held[code] then
                state.held[code]=true; state.suppressed[code]=true;
                request_statebar(hotkey);
            elseif not down then
                state.held[code]=nil; state.suppressed[code]=nil;
            end
        end
        if code<size and (state.suppressed[code] or hotkey or (shortcuts_active() and not modifier_down() and mapped_key(code)~=nil)) then ptr[code]=0; end
    end
end);
ashita.events.register('load','decker_load',function() load_glass_fonts(); say('Decker v'..addon.version..' loaded',false); end);
-- Observe book/set commands when Ashita exposes them; do not block native execution.
local function observe_native_macro_command(args)
    if type(args)~='table' or type(args[1])~='string' or args[1]:lower()~='/macro' then return false; end
    local kind=type(args[2])=='string' and args[2]:lower() or '';
    local value=args[3];
    if type(value)~='string' or not value:match('^%d+$') then return false; end
    local n=tonumber(value);
    if kind=='book' and n>=1 and n<=BOOK_COUNT then
        if state.manualBook~=n then
            state.awaitingPageFingerprint=state.previousFingerprint;
            state.manualBook=n;
            state.trackedSource='macro book command (unverified)';
            state.pendingRefreshFrames=3;
            save_display();
        end
        return true;
    end
    if kind=='set' and n>=1 and n<=10 then
        if state.trackedSet~=n then
            state.awaitingPageFingerprint=state.previousFingerprint;
            state.trackedSet=n;
            state.trackedSource='macro set command (unverified)';
            state.pendingRefreshFrames=3;
            save_display();
        end
        return true;
    end
    return false;
end
ashita.events.register('command','decker_cmd',function(e)
    local a=e.command:args();
    if not a[1] then return; end
    if a[1]:lower()~='/decker' then
        if not e.blocked then observe_native_macro_command(a); end
        return;
    end
    e.blocked=true;
    local cmd=(a[2] or 'show'):lower();
    if cmd=='session' then
        local sub=(a[3] or ''):lower();
        if sub=='start' then
            local kind=(a[4] or ''):lower();local label=table.concat(a,' ',5);
            local ok,msg=analytics.start(kind,label);say(msg,true);
        elseif sub=='stop' then local ok,msg=analytics.stop();say(msg,true);
        elseif sub=='report' then for _,line in ipairs(analytics.report()) do say(line,true);end
        else say('Usage: /decker session start hnm|exp|practice NAME | stop | report',true);end
    elseif cmd=='stormbar' then
        state.classic75=false; state.statebarEnabled=true; state.statebarHotkeysEnabled=true;
        state.statebarVisibility='always'; state.statebarAlways=true;
        state.statebarSlots={}; state.statebarHotkeys={65,66,67,68}; state.statebarSelected=0;
        for i,item in ipairs({{'PDT','pdt'},{'MDT','mdt'},{'Accuracy','accuracy'},{'Auto','auto'}}) do
            state.statebarSlots[i]={row='CTRL',slot=i,label=item[1],source='command',
                command='/lac fwd tank '..item[2],kind='state',trackDefence='auto'};
        end
        save_display(); say('Storm StateBar saved: F7 PDT / F8 MDT / F9 Accuracy / F10 Auto. Commands require a tank LAC profile.');
    elseif cmd=='inputtrace' then
        local option=(a[3] or 'status'):lower()
        if option=='on' then
            inputDiag.clear(); inputDiag.enabled=true
            say('Input trace enabled locally in memory for this session; no files or macro contents recorded.',true)
        elseif option=='off' then
            inputDiag.enabled=false
            say('Input trace stopped; use /decker inputtrace report to inspect retained events.',true)
        elseif option=='clear' then
            inputDiag.clear();say('Input trace history cleared.',true)
        elseif option=='report' then
            local lines=inputDiag.report(tonumber(a[4]) or 20)
            say(('Input trace: %d recorded events; showing %d.'):format(#inputDiag.records,#lines),true)
            for _,line in ipairs(lines) do say(line,true) end
        else
            say(('Input trace %s, %d buffered events. on|off|report [1-80]|clear'):format(
                inputDiag.enabled and 'ON' or 'OFF',#inputDiag.records),true)
        end
    elseif cmd=='debug' then
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
    elseif cmd=='savelayout' then
        if state.profileReady then
            save_display();
            say('Saved Decker positions for '..tostring(state.profileId)..'.',true);
        else
            say('Cannot save positions until a character is logged in.',true);
        end
    elseif cmd=='resetbook' then reset_native_book()
    elseif cmd=='switchbook' then select_native_book(tonumber(a[3]))
    elseif cmd=='navon' then state.navKeysEnabled=true; state.savedNavEnabled=true; save_display(); say('Custom set navigation enabled.',true)
    elseif cmd=='navoff' then state.navKeysEnabled=false; state.savedNavEnabled=false; nav_clear(); save_display(); say('Custom set navigation disabled.',true)
    elseif cmd=='cooldown' then
        if (a[3] or ''):lower()=='on' then
            state.cooldownEnabled=true;save_display();say('Recast clocks enabled.',true);
        elseif (a[3] or ''):lower()=='off' then
            state.cooldownEnabled=false;save_display();say('Recast clocks disabled.',true);
        elseif (a[3] or ''):lower()=='status' then
            local page,fp=cooldown.page();local total=0;
            if page then for slot=1,20 do if cooldown.binding(page,fp,slot) then total=total+1;end end end
            say('Cooldowns '..(state.cooldownEnabled and 'ON' or 'OFF')..' | mapped '..total..'/20 | current book/set '..(page or 'not verified'),true);
            if total==0 then say('Clock requires at least one mapped action. Set /decker cooldown ctrl 1 spell SPELL_INDEX (or map an ability timer).',true); end
        else
        local row=(a[3] or ''):lower(); local slot=tonumber(a[4]);
        local kind=(a[5] or ''):lower(); local id=tonumber(a[6]);
        if (row=='ctrl' or row=='alt') and slot and slot>=1 and slot<=10 and slot==math.floor(slot) then
            local index=(row=='alt' and 10 or 0)+slot;
            local page,fingerprint=cooldown.page();
            if not page then
                say('Cooldown mapping needs a refreshed macro page. Verify the book and set in FFXI first.',true);
            elseif kind=='clear' then
                state.cooldownBindings[page..index]=nil; save_display(); say('Cooldown mapping cleared for this page.',true);
            elseif (kind=='spell' or kind=='ability') and id and id>=0 and id==math.floor(id) then
                local signature=cooldown.macro_signature(index,fingerprint);
                state.cooldownBindings[page..index]={kind=kind,id=id,fingerprint=signature};
                save_display(); say('Cooldown mapping saved for this macro; it follows its commands when its label changes.',true);
            elseif kind=='action' then
                local action=cooldown.resolve_action(table.concat(a,' ',6));
                if action then
                    local signature=cooldown.macro_signature(index,fingerprint);
                    state.cooldownBindings[page..index]={kind=action.kind,id=action.id,fingerprint=signature};
                    save_display(); say('Cooldown mapped to '..action.name..' for this macro.',true);
                else say('Action not found. Enter the exact spell or ability name.',true); end
            else say('Usage: /decker cooldown ctrl 1 spell ID | ability TIMER_ID | action "Spell or Ability" | clear',true); end
        else say('Usage: /decker cooldown on|off|status | ctrl|alt SLOT spell ID | ability TIMER_ID | action "Name"',true); end
        end
    elseif cmd=='guide' then open_guide()
    elseif cmd=='settings' then state.showTests=true
    elseif cmd=='closesettings' then state.showTests=false
    elseif cmd=='help' then
        say('/decker settings - open Settings | /decker closesettings - close Settings | /decker guide - simulated tutorial',true);
        say('/decker show | hide | toggle - macro HUD visibility | /decker connect - connect native macros',true);
        say('/decker keysoff - disable main and StateBar hotkeys | /decker navoff - disable navigation',true);
        say('/decker session start hnm|exp|practice NAME | stop | report - local session statistics',true);
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
        local k,v=line:match('^([%w.]+)=(.+)$'); if not k or m[k] then return nil; end; m[k]=v;
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
    save_display();
    if updater.job and update_kernel then update_kernel.TerminateProcess(updater.job.handle,1); update_kernel.CloseHandle(updater.job.handle); updater.job=nil; end
end);

local drawDeps = {
    BOOK_COUNT = BOOK_COUNT,
    DIRECT_KEY_OPTIONS = DIRECT_KEY_OPTIONS,
    DIRECT_NAMES = DIRECT_NAMES,
    NAV_ACTIONS = NAV_ACTIONS,
    NAV_KEY_OPTIONS = NAV_KEY_OPTIONS,
    analytics = analytics,
    apply_macro_layout = apply_macro_layout,
    begin_macro_layout = begin_macro_layout,
    book_label = book_label,
    cancel_macro_layout = cancel_macro_layout,
    cancel_macro_guard = cancel_macro_guard,
    confirm_macro_guard = confirm_macro_guard,
    macro_guarded = macro_guarded,
    macro_guard_key = macro_guard_key,
    toggle_macro_guard = toggle_macro_guard,
    chat = chat,
    classic = classic,
    connect_macros = connect_macros,
    cooldown = cooldown,
    copy_macro_layout = copy_macro_layout,
    default_direct_keys = default_direct_keys,
    direct_conflict = direct_conflict,
    draw_glass_face = draw_glass_face,
    draw_glass_text = draw_glass_text,
    draw_macro_panel = draw_macro_panel,
    draw_row = draw_row,
    glass = glass,
    glass_available = glass_available,
    guide_draw = guide_draw,
    identity_macro_layout = identity_macro_layout,
    imgui = imgui,
    inputDiag = inputDiag,
    macro_layout_key = macro_layout_key,
    mapped_key = mapped_key,
    maybe_auto_refresh = maybe_auto_refresh,
    nav_clear = nav_clear,
    nav_command = nav_command,
    nav_is_active = nav_is_active,
    nav_scan = nav_scan,
    navigate_once = navigate_once,
    open_guide = open_guide,
    pair = pair,
    pin_window = pin_window,
    pop_glass_background = pop_glass_background,
    push_glass_background = push_glass_background,
    read_all_names = read_all_names,
    refresh_book_titles = refresh_book_titles,
    refresh_profile = refresh_profile,
    remember_window = remember_window,
    request_statebar = request_statebar,
    restore_section = restore_section,
    row_key = row_key,
    save_display = save_display,
    say = say,
    scan = scan,
    scrollbar_flags = scrollbar_flags,
    select_native_book = select_native_book,
    select_page = select_page,
    selector = selector,
    shortcuts_active = shortcuts_active,
    size_window = size_window,
    state = state,
    statebar_input_ready = statebar_input_ready,
    update_exists = update_exists,
    update_newer = update_newer,
    update_poll = update_poll,
    update_rollback = update_rollback,
    update_start = update_start,
    updater = updater,
    updater_dir = updater_dir,
    valid_command = valid_command,
    validaddr = validaddr,
};

ashita.events.register('d3d_present','decker_draw',function()
    drawDeps.update_poll();
    if os.clock()-drawDeps.state.lastProfileCheck>1 then drawDeps.state.lastProfileCheck=os.clock(); drawDeps.refresh_profile(); end
    -- The addon remains loaded at character select, but every Decker window stays hidden until a character profile is detected.
    if not drawDeps.state.profileReady then return; end
    if drawDeps.state.layoutEditing and drawDeps.state.layoutDraftKey~=drawDeps.macro_layout_key() then drawDeps.cancel_macro_layout(); end
    local pendingGuard=drawDeps.state.pendingMacroConfirm;
    if pendingGuard and (os.clock()>=pendingGuard.expires or pendingGuard.book~=(drawDeps.state.manualBook or 1)
        or pendingGuard.set~=(drawDeps.state.trackedSet or 1) or pendingGuard.fingerprint~=drawDeps.state.previousFingerprint) then
        drawDeps.cancel_macro_guard('Protected macro confirmation expired or page changed; nothing was executed.');
    end
    if drawDeps.state.profileReady and drawDeps.state.autoConnectPending and not drawDeps.state.autoConnectAttempted and os.clock()>=drawDeps.state.autoConnectAt then
        drawDeps.state.autoConnectAttempted=true; drawDeps.state.autoConnectPending=false;
        if drawDeps.state.phase<4 then drawDeps.connect_macros(); end
    end
    if drawDeps.state.profileReady and os.clock()-(drawDeps.state.lastBookTitleCheck or 0)>5 then drawDeps.state.lastBookTitleCheck=os.clock(); drawDeps.refresh_book_titles(); end
    if drawDeps.state.layoutDirtyAt and os.clock()-drawDeps.state.layoutDirtyAt>=.5 then drawDeps.save_display(); end
    drawDeps.selector.validate_queue();
    if #drawDeps.state.navQueue>0 then
        -- Consume input transitions once per frame, in order.  Limit queued
        -- set changes while a native request is unresolved; never advance
        -- trackedSet repeatedly against an unverified game state.
        local queue=drawDeps.state.navQueue; drawDeps.state.navQueue={};
        for _,entry in ipairs(queue) do
            local key=type(entry)=='table' and entry.key or entry;
            local repeating=type(entry)=='table' and entry.repeating;
            -- A release, disabled navigation or tutorial cancels pending repeats.
            if not repeating or (drawDeps.nav_is_active() and drawDeps.state.navPhysicalKeys[key] and not drawDeps.state.guideOpen) then
                if key==200 or key==208 then
                    if not drawDeps.state.deferredNav or #drawDeps.state.deferredNav==0 then
                        drawDeps.nav_command(key,repeating);
                    elseif drawDeps.state.debugLog then
                        drawDeps.say('TRACE navigation: extra set request ignored while prior request is pending');
                    end
                else
                    drawDeps.nav_command(key,repeating);
                    if (key==28 or key==156) and drawDeps.selector.handoff_active() then break; end
                end
            end
        end
    end
    -- Execute navigation on a later UI frame, after input handling has settled.
    if drawDeps.state.deferredNav and #drawDeps.state.deferredNav>0 then
        local item=drawDeps.state.deferredNav[1]; item.frames=item.frames-1;
        if item.frames<=0 then
            table.remove(drawDeps.state.deferredNav,1);
            if not drawDeps.state.navKeysEnabled or drawDeps.state.phase<4 or (item.repeating and (not drawDeps.nav_is_active() or not drawDeps.state.navPhysicalKeys[item.key] or drawDeps.state.guideOpen)) then
                if drawDeps.state.debugLog then drawDeps.say('TRACE navigation: queued set request cancelled; navigation unavailable'); end
            else
                drawDeps.navigate_once(item.key);
            end
            -- Refresh repeatedly over the next frames because native macro data
            -- may not be ready on the same frame as a set-page request.
            drawDeps.state.navSetVerifyFrames=18;
        end
    end
    if drawDeps.state.navSetVerifyFrames and drawDeps.state.navSetVerifyFrames>0 then
        drawDeps.state.navSetVerifyFrames=drawDeps.state.navSetVerifyFrames-1;
        if drawDeps.state.tracePending then drawDeps.state.tracePending.frames=18-drawDeps.state.navSetVerifyFrames; end;
        if drawDeps.state.navSetVerifyFrames==17 or drawDeps.state.navSetVerifyFrames==15 or drawDeps.state.navSetVerifyFrames==1 then
            if drawDeps.state.phase>=4 and #drawDeps.state.names==20 then
                drawDeps.state.confirmAll=true; drawDeps.read_all_names();
            end
        end
    end
    -- Keeps scans out of the rendering loop; auto mode is enabled only by user.
    if drawDeps.state.pendingRefreshFrames>0 then
        drawDeps.state.pendingRefreshFrames=drawDeps.state.pendingRefreshFrames-1;
        if drawDeps.state.pendingRefreshFrames==0 and drawDeps.state.phase>=4 and #drawDeps.state.names==20 then
            drawDeps.state.confirmAll=true;
            drawDeps.read_all_names();
        end
    end
    drawDeps.maybe_auto_refresh();
    if drawDeps.state.statebarEnabled and (drawDeps.state.statebarVisibility=='always' or (drawDeps.state.statebarVisibility=='navigation' and (drawDeps.state.navToggleActive or drawDeps.state.navModifierHeld)) or (drawDeps.state.statebarVisibility=='manual' and drawDeps.state.statebarAlways) or drawDeps.state.showTests) then
        local flags=drawDeps.state.statebarLocked and (ImGuiWindowFlags_NoMove or 4) or 0;
        local slots,hotkeys,job,level=drawDeps.classic.slots();
        local saved=drawDeps.classic.saved_modes();
        if not drawDeps.state.classic75 then job=drawDeps.classic.identity(); end
        local colours={{.34,.84,.49,1},{.29,.63,1,1},{.76,.49,.95,1},{.76,.79,.83,1}};
        local accent=colours[drawDeps.state.statebarTheme] or colours[1];
        local count=#slots;
        if count>0 then
            local sw=math.floor(100*drawDeps.state.statebarScale);
            local width=drawDeps.state.statebarVertical and (sw+32) or (count*sw+math.max(0,count-1)*8+32);
            local sh=math.floor(40*drawDeps.state.statebarScale);
            if not drawDeps.glass_available() then sh=math.max(sh,(drawDeps.imgui.GetTextLineHeight and drawDeps.imgui.GetTextLineHeight() or 20)*2+8); end
            local footer=drawDeps.state.showTests and 50 or 16;
            local height=drawDeps.state.statebarVertical and (count*(sh+4)+footer) or (sh+footer);
            drawDeps.size_window('statebar',width,height);
            drawDeps.pin_window('statebar',drawDeps.state.statebarLocked);
            local barColours,barVars=drawDeps.push_glass_background(drawDeps.state.statebarOpacity);
            if drawDeps.imgui.Begin('###DeckerStateBar',{true},flags+(ImGuiWindowFlags_NoTitleBar or 1)+drawDeps.scrollbar_flags()) then
                drawDeps.remember_window('statebar',drawDeps.state.statebarLocked);
                for i,b in ipairs(slots) do
                    local idx=(b.row=='ALT' and 10 or 0)+b.slot;
                    local name=b.label and b.label~='' and b.label or b.source=='command' and (b.command or 'Configure command') or (drawDeps.state.names[idx] or 'Unassigned');
                    local key=drawDeps.DIRECT_NAMES[hotkeys[i] or 0];
                    local caption=name..(key and key~='None' and ('\n'..key) or '');
                    if i>1 and not drawDeps.state.statebarVertical then drawDeps.imgui.SameLine(); end
                    -- StateBar selection is independent from the main macro HUD's press highlight.
                    -- Keep the actual macro name legible; never prefix it with SELECTED.
                    local unavailable=drawDeps.state.classic75 and not drawDeps.classic.available(b,job,level);
                    local sbSelected,sbSource=drawDeps.classic.highlight(b,i,saved,job,unavailable);
                    local opacity=drawDeps.state.buttonOpacity;
                    local sbAccent=sbSource=='pending' and {.94,.63,.18,1} or accent;
                    local base=sbSelected and {sbAccent[1]*.30,sbAccent[2]*.36,sbAccent[3]*.43,opacity} or {.012,.015,.021,opacity};
                    local sbColours=type(drawDeps.imgui.PushStyleColor)=='function' and type(drawDeps.imgui.PopStyleColor)=='function' and type(ImGuiCol_Button)=='number' and type(ImGuiCol_ButtonHovered)=='number' and type(ImGuiCol_ButtonActive)=='number';
                    if unavailable and drawDeps.imgui.BeginDisabled and drawDeps.imgui.EndDisabled then drawDeps.imgui.BeginDisabled(); end
                    if sbColours then
                        drawDeps.imgui.PushStyleColor(ImGuiCol_Button,base);
                        drawDeps.imgui.PushStyleColor(ImGuiCol_ButtonHovered,{base[1]+.035,base[2]+.035,base[3]+.035,opacity});
                        drawDeps.imgui.PushStyleColor(ImGuiCol_ButtonActive,{base[1]+.07,base[2]+.07,base[3]+.07,opacity});
                    end
                    local custom=drawDeps.glass_available(); local x,y;
                    if custom then x,y=drawDeps.pair(drawDeps.imgui.GetCursorScreenPos()); custom=x~=nil; end
                    local sbPressed=drawDeps.imgui.Button((custom and '' or caption)..'##statebar'..i,{sw,sh});
                    if custom then
                        local ok,err=pcall(function()
                            local dl=drawDeps.imgui.GetWindowDrawList();
                            drawDeps.draw_glass_face(dl,x,y,sw,sh,opacity,sbSelected and sbAccent or nil);
                            drawDeps.draw_glass_text(dl,name,x,y,sw,sh,key~='None' and key or '',false,true);
                        end);
                        if not ok then drawDeps.glass.custom=false; drawDeps.glass.diagnostic='StateBar draw fallback: '..tostring(err); end
                    end
                    if drawDeps.imgui.IsItemHovered and drawDeps.imgui.SetTooltip and drawDeps.imgui.IsItemHovered() then
                        local action=b.source=='command' and (b.command or '') or ('Current book/set: '..b.row..' '..tostring(b.slot==10 and 0 or b.slot));
                        local behaviour=b.kind=='utility' and 'Utility: one-off action.' or 'Manual highlight: press again to clear.';
                        if drawDeps.state.classic75 or drawDeps.classic.tracked_mode(b) then
                            action=unavailable and 'Unavailable for this job or level' or action;
                            behaviour=sbSource=='pending' and 'Mode requested; awaiting Aegis readback (amber, not confirmed).'
                                or saved and ('Saved Aegis mode: '..(not saved.enabled and 'disabled' or sbSelected and 'active' or 'inactive')..(saved.locked and ', gear swaps locked' or '')..'.')
                                or 'Aegis saved mode unreadable; active status unknown.';
                        end
                        drawDeps.imgui.SetTooltip(name..'\n'..action..'\nKey: '..(key or 'None')..'\n'..behaviour);
                    end
                    if sbColours then drawDeps.imgui.PopStyleColor(3); end
                    if unavailable and drawDeps.imgui.BeginDisabled and drawDeps.imgui.EndDisabled then drawDeps.imgui.EndDisabled(); end
                    if sbPressed and not unavailable then
                        drawDeps.request_statebar(i);
                    end
                end
                if drawDeps.state.showTests and drawDeps.imgui.Button('Settings##statebarconfig') then drawDeps.state.settingsTab='StateBar'; end
            end
            drawDeps.imgui.End();
            drawDeps.pop_glass_background(barColours,barVars);
        end
    end
    local activeNav=drawDeps.state.navKeysEnabled and (drawDeps.state.stickyNavigation and drawDeps.state.navToggleActive or (not drawDeps.state.stickyNavigation and drawDeps.state.navModifierHeld));
    -- Explicit wake requests must not be consumed by the 0s mode before interaction.
    if drawDeps.state.hudForceReveal then drawDeps.state.hudImmediateHide=false; end
    -- With 0s selected, release of active Toggle navigation is an end-of-activity event.
    if drawDeps.state.hudWasActive and not activeNav and drawDeps.state.autoHide and drawDeps.state.autoHideDelay==0 then
        drawDeps.state.hudImmediateHide=true;
    end
    if activeNav and not drawDeps.state.hudWasActive then drawDeps.state.hudLastActivity=os.clock(); end
    drawDeps.state.hudWasActive=activeNav;
    -- Timed options keep the existing startup grace and idle behaviour.
    -- 0s is event-based: do not hide on startup or before the first usable action.
    if not drawDeps.state.hudReadySince then drawDeps.state.hudReadySince=os.clock(); end
    -- Hold visibility follows the physical key immediately; timers belong to Toggle.
    local holdMode=drawDeps.state.navKeysEnabled and not drawDeps.state.stickyNavigation;
    local holdHidden=holdMode and not drawDeps.state.navModifierHeld;
    local timedHide=drawDeps.state.autoHideDelay>0 and (os.clock()-drawDeps.state.hudLastActivity)>=drawDeps.state.autoHideDelay and (os.clock()-drawDeps.state.hudReadySince)>=10;
    local instantHide=drawDeps.state.autoHideDelay==0 and drawDeps.state.hudImmediateHide;
    local idleHidden=not holdMode and drawDeps.state.autoHide and not drawDeps.state.hudForceReveal and not activeNav and not drawDeps.state.showTests and (instantHide or timedHide);
    drawDeps.state.hudForceReveal=false;
    -- /decker settings and /decker show recover the HUD without a permanent window.
    if drawDeps.state.visible and idleHidden and drawDeps.state.autoHideMode=='collapse' then
        drawDeps.size_window('collapsed',88,40);
        drawDeps.pin_window('collapsed',drawDeps.state.positionLocked);
        if drawDeps.imgui.Begin('###DeckerCollapsed',{true},(ImGuiWindowFlags_NoTitleBar or 1)+(drawDeps.state.positionLocked and (ImGuiWindowFlags_NoMove or 4) or 0)+drawDeps.scrollbar_flags()) then
            drawDeps.remember_window('collapsed',drawDeps.state.positionLocked);
            if drawDeps.imgui.Button('Decker##recovery') then drawDeps.state.showTests=true; end
        end
        drawDeps.imgui.End();
    end
    if drawDeps.state.visible and not holdHidden and not idleHidden then
    local hudw=math.floor(10*drawDeps.state.hudWidth*drawDeps.state.scale+9*8+32);
    drawDeps.size_window('hud',hudw,math.floor(2*drawDeps.state.hudHeight*drawDeps.state.scale+90+(drawDeps.state.layoutEditing and 52 or 0)));
    drawDeps.pin_window('hud',drawDeps.state.positionLocked);
    -- Explicit open-state table keeps flags in the host binding's three-argument Begin overload.
    -- Hidden IDs preserve window identity; the single content heading is drawn below.
    -- Apply to the HUD only; Settings stays fully opaque.
    local hudColours,hudVars=drawDeps.push_glass_background(drawDeps.state.outerOpacity);
    if drawDeps.imgui.Begin('###DeckerMain',{true},(ImGuiWindowFlags_NoTitleBar or 1)+(drawDeps.state.positionLocked and (ImGuiWindowFlags_NoMove or 4) or 0)+drawDeps.scrollbar_flags()) then
        drawDeps.remember_window('hud',drawDeps.state.positionLocked);
        -- VanaCore ImGui positions may be math-backed vectors, not Lua arrays.
        -- Avoid numeric indexing of GetWindowPos results until its ABI is verified.

        -- Fixed header columns keep status length from moving the key details.
        local book=drawDeps.state.manualBook or 1;
        local title=drawDeps.state.bookAliases[book] or drawDeps.state.bookNames[book] or '';
        if #title>15 then title=title:sub(1,15)..'...'; end
        local header=('DECKER | Book %d%s (#%d)'):format(book,title~='' and (' - '..title) or '',drawDeps.state.trackedSet or 1);
        -- A dark backing keeps the white book/status text and gold page badge readable over bright game scenes.
        if drawDeps.imgui.GetCursorScreenPos and drawDeps.imgui.GetContentRegionAvail
            and drawDeps.imgui.GetWindowDrawList and drawDeps.imgui.GetColorU32 then
            pcall(function()
                local x,y=drawDeps.pair(drawDeps.imgui.GetCursorScreenPos());
                local width=drawDeps.pair(drawDeps.imgui.GetContentRegionAvail());
                if not x or not width then return; end
                local h=type(drawDeps.imgui.GetTextLineHeight)=='function' and drawDeps.imgui.GetTextLineHeight() or 16;
                local dl=drawDeps.imgui.GetWindowDrawList();
                dl:AddRectFilled({x-6,y-3},{x+width-4,y+h+3},drawDeps.imgui.GetColorU32({.025,.035,.055,.94}),4);
                dl:AddRect({x-6,y-3},{x+width-4,y+h+3},drawDeps.imgui.GetColorU32({.34,.42,.54,.88}),4);
            end);
        end
        local function header_width(text)
            if drawDeps.imgui.CalcTextSize then local ok,a,b=pcall(drawDeps.imgui.CalcTextSize,text); if ok then local w=drawDeps.pair(a,b); if w then return w; end end end
            return #text*8;
        end
        local origin=8;
        if drawDeps.imgui.GetCursorPos then local ok,a,b=pcall(drawDeps.imgui.GetCursorPos); if ok then origin=drawDeps.pair(a,b) or origin; end end
        local statusX=origin+header_width('DECKER | Book 20 - WWWWWWWWWWWWWWWWWW (#10)')+14*drawDeps.state.scale;
        local keysX=statusX+header_width('UNLOCKED')+48*drawDeps.state.scale;
        local active=drawDeps.state.navKeysEnabled and (drawDeps.state.stickyNavigation and drawDeps.state.navToggleActive or (not drawDeps.state.stickyNavigation and drawDeps.state.navModifierHeld));
        local status=active and (drawDeps.state.stickyNavigation and 'LOCKED' or 'HELD') or 'UNLOCKED';
        drawDeps.imgui.Text(header);
        if drawDeps.imgui.IsItemHovered and drawDeps.imgui.SetTooltip and drawDeps.imgui.IsItemHovered() then drawDeps.imgui.SetTooltip(drawDeps.book_label(drawDeps.state.manualBook or 1)..(drawDeps.state.trackedSource=='unverified (same names)' and '\nSet selection unverified: native macro names did not change.' or '')); end
        drawDeps.imgui.SameLine(statusX,0);
        local colourStatus=drawDeps.imgui.PushStyleColor and drawDeps.imgui.PopStyleColor and type(ImGuiCol_Text)=='number';
        if colourStatus then drawDeps.imgui.PushStyleColor(ImGuiCol_Text,active and {1,.25,.25,1} or {1,1,1,1}); end
        if drawDeps.imgui.GetCursorScreenPos and drawDeps.imgui.GetWindowDrawList and drawDeps.imgui.GetColorU32 then
            pcall(function()
                local x,y=drawDeps.pair(drawDeps.imgui.GetCursorScreenPos());
                if not x then return; end
                local h=type(drawDeps.imgui.GetTextLineHeight)=='function' and drawDeps.imgui.GetTextLineHeight() or 16;
                local dl=drawDeps.imgui.GetWindowDrawList();
                dl:AddRectFilled({x-5,y-2},{x+header_width('UNLOCKED')+5,y+h+2},drawDeps.imgui.GetColorU32(active and {.55,.04,.04,.85} or {.08,.22,.12,.85}),3);
                dl:AddRect({x-5,y-2},{x+header_width('UNLOCKED')+5,y+h+2},drawDeps.imgui.GetColorU32(active and {1,.35,.35,1} or {.4,.8,.5,1}),3);
            end);
        end
        drawDeps.imgui.Text(status);
        if colourStatus then drawDeps.imgui.PopStyleColor(); end
        drawDeps.imgui.SameLine(keysX,0);
        drawDeps.imgui.Text('Active row: '..(drawDeps.state.navRow=='ALT' and 'Lower' or 'Upper'));
        -- Dedicated high-contrast macro page indicator distinct from the book name.
        local bookX=keysX+header_width('Active row: Lower')+28*drawDeps.state.scale;
        drawDeps.imgui.SameLine(bookX,0);
        local bookIndicator=('PAGE %02d'):format(drawDeps.state.trackedSet or 1);
        local bookColor=drawDeps.imgui.PushStyleColor and drawDeps.imgui.PopStyleColor and type(ImGuiCol_Text)=='number';
        if bookColor then drawDeps.imgui.PushStyleColor(ImGuiCol_Text,{1,.86,.38,1}); end
        if drawDeps.imgui.GetCursorScreenPos and drawDeps.imgui.GetWindowDrawList and drawDeps.imgui.GetColorU32 then
            pcall(function()
                local x,y=drawDeps.pair(drawDeps.imgui.GetCursorScreenPos());
                if not x then return; end
                local h=type(drawDeps.imgui.GetTextLineHeight)=='function' and drawDeps.imgui.GetTextLineHeight() or 16;
                local width=header_width('PAGE 10')+18*drawDeps.state.scale;
                local dl=drawDeps.imgui.GetWindowDrawList();
                dl:AddRectFilled({x-8,y-3},{x+width,y+h+3},drawDeps.imgui.GetColorU32({.24,.19,.07,.95}),4);
                dl:AddRect({x-8,y-3},{x+width,y+h+3},drawDeps.imgui.GetColorU32({.85,.65,.22,1}),4);
            end);
        end
        drawDeps.imgui.Text(bookIndicator);
        if bookColor then drawDeps.imgui.PopStyleColor(); end
        if drawDeps.state.layoutEditing then
            drawDeps.imgui.TextWrapped('LAYOUT EDITOR: click one macro, then another to swap. Apply & Save keeps this order for this book and set.');
            if drawDeps.imgui.Button('APPLY & SAVE LAYOUT##applymacro_top') then
                local key=drawDeps.macro_layout_key();
                local previous=drawDeps.state.macroLayouts[key] and drawDeps.copy_macro_layout(drawDeps.state.macroLayouts[key]) or nil;
                if drawDeps.apply_macro_layout() then
                    if drawDeps.save_display() then
                        drawDeps.state.layoutStatus=('Saved layout for Book %d, Set %d.'):format(drawDeps.state.manualBook or 1,drawDeps.state.trackedSet or 1);
                        drawDeps.say(drawDeps.state.layoutStatus,true);
                    else
                        drawDeps.state.macroLayouts[key]=previous;
                        drawDeps.state.layoutStatus='Save failed: profile or layout storage could not be written.';
                        drawDeps.say(drawDeps.state.layoutStatus,true);
                    end
                else
                    drawDeps.state.layoutStatus='Apply did not run: the book/set changed or the draft was invalid.';
                    drawDeps.say(drawDeps.state.layoutStatus,true);
                end
            end
            drawDeps.imgui.SameLine();
            if drawDeps.imgui.Button('Cancel##cancelmacro_top') then
                drawDeps.cancel_macro_layout();
                drawDeps.state.layoutStatus='Edit cancelled; saved layout unchanged.';
            end
            drawDeps.imgui.SameLine();
            if drawDeps.imgui.Button('Reset order##resetmacro_top') then
                drawDeps.state.layoutDraft=drawDeps.identity_macro_layout();
                drawDeps.state.layoutSelected=nil;
                drawDeps.state.layoutStatus='Reset is a draft. Press Apply & Save to keep it.';
            end
            if drawDeps.state.layoutStatus then drawDeps.imgui.TextWrapped(drawDeps.state.layoutStatus); end
            drawDeps.imgui.Separator();
        end
        if #drawDeps.state.names==20 then
            drawDeps.draw_macro_panel();
            drawDeps.draw_row('CTRL',0);
            drawDeps.draw_row('ALT',10);
            if drawDeps.state.pendingMacroConfirm then
                local armed=drawDeps.state.pendingMacroConfirm;
                drawDeps.imgui.TextWrapped('2-HOUR ARMED: '..armed.name..' has not run. Confirm separately within 8 seconds.');
                if drawDeps.imgui.Button('CONFIRM 2-HOUR##guardconfirm') then drawDeps.confirm_macro_guard(); end
                drawDeps.imgui.SameLine();
                if drawDeps.imgui.Button('Cancel##guardcancel') then drawDeps.cancel_macro_guard('Protected macro cancelled; nothing was executed.'); end
            end
            if not drawDeps.state.layoutEditing and drawDeps.imgui.Button('Arrange macros##arrangemacro') then
                if not drawDeps.begin_macro_layout() then drawDeps.say('Connect to in-game macros before arranging the current book/set.',true); end
            end
            if drawDeps.state.guardEditing then
                drawDeps.imgui.Separator();
                drawDeps.imgui.TextWrapped('2-HOUR GUARD SETUP: click macro buttons to toggle protection for this book/set. Protected buttons show GUARDED.');
                if drawDeps.imgui.Button('Done##guarddone') then drawDeps.state.guardEditing=false; end
            elseif not drawDeps.state.layoutEditing then
                drawDeps.imgui.Separator();
                if drawDeps.imgui.Button('Protect 2-hour macros##guardstart') then
                    drawDeps.state.pendingMacroConfirm=nil; drawDeps.state.guardEditing=true; drawDeps.state.visible=true;
                end
            end
            if drawDeps.state.allowSwitch then
                if drawDeps.imgui.Button('<##deckprev') then drawDeps.select_page(((drawDeps.state.trackedSet or 1)+8)%10+1); end
                drawDeps.imgui.SameLine(); drawDeps.imgui.Text(('Macro set %d/10'):format(drawDeps.state.trackedSet or 1));
                drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('>##decknext') then drawDeps.select_page((drawDeps.state.trackedSet or 1)%10+1); end
                drawDeps.imgui.SameLine();
                if drawDeps.validaddr(drawDeps.state.addresses.set_book) then
                    if drawDeps.imgui.Button('<##bookprev') then drawDeps.select_native_book(((drawDeps.state.manualBook or 1)+drawDeps.BOOK_COUNT-2)%drawDeps.BOOK_COUNT+1); end
                    drawDeps.imgui.SameLine();
                    local sized=drawDeps.imgui.PushItemWidth and drawDeps.imgui.PopItemWidth;
                    if sized then drawDeps.imgui.PushItemWidth(130*drawDeps.state.scale); end
                    if drawDeps.imgui.BeginCombo('##hudbook',('Book %d/%d'):format(drawDeps.state.manualBook or 1,drawDeps.BOOK_COUNT)) then
                        for number=1,drawDeps.BOOK_COUNT do
                            if drawDeps.imgui.Selectable(drawDeps.book_label(number)..'##hudbookchoice'..number,drawDeps.state.manualBook==number) then drawDeps.select_native_book(number); end
                        end
                        drawDeps.imgui.EndCombo();
                    end
                    if sized then drawDeps.imgui.PopItemWidth(); end
                    drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('>##booknext') then drawDeps.select_native_book((drawDeps.state.manualBook or 1)%drawDeps.BOOK_COUNT+1); end
                    drawDeps.imgui.SameLine();
                end
            end
            if drawDeps.imgui.Button(drawDeps.state.positionLocked and 'Unlock position' or 'Lock position') then drawDeps.state.positionLocked=not drawDeps.state.positionLocked; drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Settings') then drawDeps.state.showTests=not drawDeps.state.showTests; drawDeps.state.hudLastActivity=os.clock(); end
        else
            drawDeps.imgui.Text('Decker is not connected to native macros.');
            if drawDeps.imgui.Button('Connect to in-game macros') then drawDeps.connect_macros(); end
            drawDeps.imgui.SameLine();
            if drawDeps.imgui.Button(drawDeps.state.positionLocked and 'Unlock position' or 'Lock position') then drawDeps.state.positionLocked=not drawDeps.state.positionLocked; drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Settings') then drawDeps.state.showTests=not drawDeps.state.showTests; drawDeps.state.hudLastActivity=os.clock(); end
            drawDeps.imgui.TextWrapped('Connect invokes native FFXI reading functions. As with earlier builds, incompatible clients may crash.');
            if drawDeps.state.phase~=0 then drawDeps.imgui.TextWrapped(drawDeps.state.nameSummary..' / '..state.pointerSummary); end
        end
        if drawDeps.imgui.TextDisabled then drawDeps.imgui.TextDisabled('By Mutant X'); else drawDeps.imgui.Text('By Mutant X'); end
    end
    drawDeps.imgui.End();
    drawDeps.pop_glass_background(hudColours,hudVars);
    end -- visible macro HUD; Settings is independent
    if not drawDeps.state.showTests or drawDeps.state.settingsTab~='StateBar' then drawDeps.state.statebarDrag=nil; end
    if drawDeps.state.showTests then
        drawDeps.imgui.SetNextWindowSize({490,370},ImGuiCond_FirstUseEver);
        local thinScroll=type(ImGuiStyleVar_ScrollbarSize)=='number' and drawDeps.imgui.PushStyleVar and drawDeps.imgui.PopStyleVar;
        if thinScroll then drawDeps.imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize,7); end
        local settingsOpen={drawDeps.state.showTests};
        if drawDeps.imgui.Begin('Decker v'..addon.version..' - Settings',settingsOpen,drawDeps.scrollbar_flags()) then
            if drawDeps.imgui.Button('X  Close Settings') then drawDeps.state.showTests=false; end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Show macros##settings') then drawDeps.state.visible=true; drawDeps.state.hudLastActivity=os.clock(); drawDeps.state.hudForceReveal=true; end
            drawDeps.imgui.Text('Decker v'..addon.version);
            drawDeps.imgui.Separator();
            -- Four user-facing sections; technical pages live under More.
            local currentTab=drawDeps.state.settingsTab;
            local moreActive=(currentTab=='General' or currentTab=='Profiles' or currentTab=='Updates');
            for i,tab in ipairs({{'Quick Setup','Controls'},{'Appearance','Appearance'},{'StateBar','StateBar'},{'More','General'}}) do
                if i>1 then drawDeps.imgui.SameLine(); end
                local active=(tab[2]=='General' and moreActive) or currentTab==tab[2];
                if drawDeps.imgui.Button((active and '['..tab[1]..']' or tab[1])..'##tab'..tab[2]) then drawDeps.state.settingsTab=tab[2]; end
            end
            drawDeps.imgui.Separator();
            if moreActive then
                drawDeps.imgui.Text('More options:');
                for i,tab in ipairs({{'Book & Set','General'},{'Profiles','Profiles'},{'Updates','Updates'}}) do
                    if i>1 then drawDeps.imgui.SameLine(); end
                    if drawDeps.imgui.Button((drawDeps.state.settingsTab==tab[2] and '['..tab[1]..']' or tab[1])..'##more'..tab[2]) then drawDeps.state.settingsTab=tab[2]; end
                end
                drawDeps.imgui.Separator();
            end
            if drawDeps.state.settingsTab=='Profiles' then
                local profileName=drawDeps.state.profileId and drawDeps.state.profileId:match('^[^_]+_(.*)$') or nil;
                drawDeps.imgui.Text('Character: '..(profileName or 'Waiting for login'));
                drawDeps.imgui.Text('Settings are kept separately for each character.');
                if drawDeps.state.showAdvanced then
                    drawDeps.imgui.TextWrapped('Detection: '..state.profileDiagnostic);
                    drawDeps.imgui.TextWrapped('Profile file: '..(drawDeps.state.profileId and ('decker_profile_'..state.profileId..'.cfg') or '(none; saves disabled)'));
                end
            elseif drawDeps.state.settingsTab=='Updates' then
                drawDeps.imgui.Text('Installed: v'..addon.version);
                drawDeps.imgui.TextWrapped('Stable and Development channels are available. Choose one, check for updates, then install and reload.');
                if not drawDeps.updater.job and not drawDeps.updater.installed then
                    if drawDeps.imgui.BeginCombo('Update channel',drawDeps.updater.channel) then
                        for _,channel in ipairs({'development','stable'}) do
                            if drawDeps.imgui.Selectable(channel,drawDeps.updater.channel==channel) then drawDeps.updater.channel=channel; drawDeps.updater.manifest=nil; drawDeps.updater.status='Channel changed; check for updates.'; end
                        end
                        drawDeps.imgui.EndCombo();
                    end
                    if drawDeps.imgui.Button('Check for updates') then drawDeps.update_start('Check'); end
                    if drawDeps.updater.manifest and drawDeps.update_newer(drawDeps.updater.manifest.version,addon.version) then
                        if drawDeps.imgui.Button('Install update and reload Decker') then drawDeps.update_start('Download'); end
                    end
                    local directory=drawDeps.updater_dir();
                    if directory and (drawDeps.updater.backupCheckedAt or 0)~=os.time() then drawDeps.updater.backupCheckedAt=os.time(); drawDeps.updater.backupAvailable=drawDeps.update_exists(directory..'decker.lua.bak'); end
                    if drawDeps.updater.backupAvailable and drawDeps.imgui.Button('Roll back previous version') then drawDeps.updater.confirmRollback=true; end
                    if drawDeps.updater.confirmRollback then
                        drawDeps.imgui.Text('Restore the previous Decker source and reload?');
                        if drawDeps.imgui.Button('Confirm rollback') then drawDeps.updater.confirmRollback=false; drawDeps.update_rollback(); end
                        drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Cancel rollback') then drawDeps.updater.confirmRollback=false; end
                    end
                end
                drawDeps.imgui.TextWrapped(drawDeps.updater.status);
                drawDeps.imgui.TextWrapped('Requires Windows PowerShell. Decker is backed up before reload; reconnect macros afterward.');
            elseif drawDeps.state.settingsTab=='StateBar' then
                local preset={drawDeps.state.classic75};
                if drawDeps.imgui.Checkbox('Classic 75 job presets',preset) then drawDeps.state.classic75=preset[1]; drawDeps.state.statebarDrag=nil; drawDeps.save_display(); end
                if drawDeps.state.classic75 then drawDeps.imgui.TextWrapped('Presets follow your current job. Your preset order is shared across jobs on this character.'); end
                drawDeps.classic.draw_order_editor();
                drawDeps.imgui.Separator();
                local enabled={drawDeps.state.statebarEnabled};
                if drawDeps.imgui.Checkbox('Enable StateBar',enabled) then drawDeps.state.statebarEnabled=enabled[1]; drawDeps.save_display(); end
                local vert={drawDeps.state.statebarVertical};
                if drawDeps.imgui.Checkbox('Vertical arrangement',vert) then drawDeps.state.statebarVertical=vert[1]; drawDeps.save_display(); end
                local locked={drawDeps.state.statebarLocked};
                if drawDeps.imgui.Checkbox('Lock StateBar position',locked) then drawDeps.state.statebarLocked=locked[1]; drawDeps.save_display(); end
                local always={drawDeps.state.statebarAlways};
                if drawDeps.imgui.Checkbox('Visible in manual mode',always) then drawDeps.state.statebarAlways=always[1]; drawDeps.save_display(); end
                drawDeps.imgui.Text('Visibility (independent of macro HUD):');
                for _,mode in ipairs({'always','navigation','manual'}) do
                    if drawDeps.imgui.Button((drawDeps.state.statebarVisibility==mode and '[X] ' or '')..mode..'##sbvis') then drawDeps.state.statebarVisibility=mode; drawDeps.save_display(); end
                    drawDeps.imgui.SameLine();
                end
                drawDeps.imgui.NewLine();
                drawDeps.imgui.Text(('StateBar opacity: %d%%'):format(math.floor(drawDeps.state.statebarOpacity*100+0.5)));
                if drawDeps.imgui.Button('Less opaque##sb') then drawDeps.state.statebarOpacity=math.max(0,drawDeps.state.statebarOpacity-.05); drawDeps.save_display(); end
                drawDeps.imgui.SameLine();
                if drawDeps.imgui.Button('More opaque##sb') then drawDeps.state.statebarOpacity=math.min(1,drawDeps.state.statebarOpacity+.05); drawDeps.save_display(); end
                drawDeps.imgui.Text('Selected State highlight colour:');
                for i,name in ipairs({'Green','Blue','Purple','Grey'}) do
                    if drawDeps.imgui.Button((drawDeps.state.statebarTheme==i and '[X] ' or '')..name..'##sbtheme') then drawDeps.state.statebarTheme=i; drawDeps.save_display(); end
                    if i<4 then drawDeps.imgui.SameLine(); end
                end
                if drawDeps.imgui.Button('StateBar smaller') then drawDeps.state.statebarScale=math.max(.7,drawDeps.state.statebarScale-.1); drawDeps.save_display(); end
                drawDeps.imgui.SameLine(); drawDeps.imgui.Text(('%.0f%%'):format(drawDeps.state.statebarScale*100)); drawDeps.imgui.SameLine();
                if drawDeps.imgui.Button('StateBar larger') then drawDeps.state.statebarScale=math.min(1.5,drawDeps.state.statebarScale+.1); drawDeps.save_display(); end
                drawDeps.classic.draw_font_controls();
                drawDeps.imgui.TextWrapped('Aegis modes highlight while active; manual states toggle. Utility slots run once.');
                drawDeps.imgui.Separator();
                drawDeps.imgui.TextWrapped('Each slot has an action and optional hotkey. Hotkeys reserve their keys; turn them off before typing.');
                local sbhot={drawDeps.state.statebarHotkeysEnabled};
                if drawDeps.imgui.Checkbox('Enable StateBar hotkeys',sbhot) then drawDeps.state.statebarHotkeysEnabled=sbhot[1]; drawDeps.save_display(); end
                drawDeps.imgui.Text('StateBar keyboard: '..(not drawDeps.state.statebarHotkeysEnabled and 'OFF' or not drawDeps.state.statebarEnabled and 'Enable StateBar first' or drawDeps.statebar_input_ready() and 'READY' or 'WAITING - Connect to in-game macros'));
                if not drawDeps.state.allowAllClicks and drawDeps.imgui.Button('Connect to in-game macros##statebarconnect') then drawDeps.connect_macros(); end
                drawDeps.imgui.TextWrapped(drawDeps.state.clickSummary);
                if drawDeps.state.classic75 then drawDeps.imgui.TextWrapped('Turn off Classic 75 job presets to edit your custom slots.'); end
                if not drawDeps.state.classic75 then
                for i,b in ipairs(drawDeps.state.statebarSlots) do
                    drawDeps.imgui.Separator(); drawDeps.imgui.Text('Slot '..i);
                    local label={b.label or ''}; if drawDeps.imgui.InputText('Label (optional)##sblabel'..i,label,25) then b.label=label[1]:gsub('[%c#]',''):sub(1,24); drawDeps.save_display(); end
                    if drawDeps.imgui.BeginCombo('Highlight behaviour##sbtype'..i,b.kind=='utility' and 'Utility: one-off action' or 'State: show mode or manual toggle') then
                        for _,kind in ipairs({'state','utility'}) do if drawDeps.imgui.Selectable(kind=='utility' and 'Utility: food or mount' or 'State: show mode or manual toggle',b.kind==kind or (b.kind==nil and kind=='state')) then b.kind=kind; if kind=='utility' and drawDeps.state.statebarSelected==i then drawDeps.state.statebarSelected=0; end; drawDeps.save_display(); end end
                        drawDeps.imgui.EndCombo();
                    end
                    if drawDeps.imgui.BeginCombo('Action type##sbsource'..i,b.source=='command' and 'Single command' or 'Existing FFXI macro') then
                        for _,source in ipairs({'macro','command'}) do if drawDeps.imgui.Selectable(source=='command' and 'Single command' or 'Existing FFXI macro',b.source==source or (b.source==nil and source=='macro')) then b.source=source; if drawDeps.state.statebarSelected==i then drawDeps.state.statebarSelected=0; end; drawDeps.save_display(); end end
                        drawDeps.imgui.EndCombo();
                    end
                    if b.source=='command' then
                        local text={b.command or ''};
                        if drawDeps.imgui.InputText('Command##sbcmd'..i,text,241) then b.command=text[1]; if drawDeps.valid_command(b.command) then drawDeps.save_display(); end end
                        if not drawDeps.valid_command(b.command) then drawDeps.imgui.TextWrapped('Command not allowed. Use an approved /lac, /equipset, /item, /ma, /ja or /mount command.'); end
                    end
                    if b.source~='command' then
                    if b.kind~='utility' and drawDeps.imgui.BeginCombo('Highlight source##sbtrack'..i,
                        b.trackDefence and ('Aegis '..b.trackDefence:upper()) or 'Manual toggle') then
                        for _,choice in ipairs({'auto','pdt','mdt'}) do
                            local label=choice=='auto' and 'Manual toggle' or ('Aegis '..choice:upper());
                            if drawDeps.imgui.Selectable(label,(b.trackDefence or 'auto')==choice) then
                                b.trackDefence=choice~='auto' and choice or nil;
                                if drawDeps.state.statebarSelected==i then drawDeps.state.statebarSelected=0; end
                                drawDeps.save_display();
                            end
                        end
                        drawDeps.imgui.EndCombo();
                    end
                    
                    if drawDeps.imgui.BeginCombo('Macro to run##bar'..i,(b.row=='CTRL' and 'Upper row (CTRL) ' or 'Lower row (ALT) ')..tostring(b.slot==10 and 0 or b.slot)) then
                        for _,row in ipairs({'CTRL','ALT'}) do
                            for slot=1,10 do
                                if drawDeps.imgui.Selectable((row=='CTRL' and 'Upper (CTRL) ' or 'Lower (ALT) ')..tostring(slot==10 and 0 or slot)..' - '..(drawDeps.state.names[(row=='CTRL' and 0 or 10)+slot] or '')..'##barchoice'..i..row..slot,b.row==row and b.slot==slot) then
                                    b.row=row; b.slot=slot; drawDeps.save_display();
                                end
                            end
                        end
                        drawDeps.imgui.EndCombo();
                    end
                    end -- native macro source
                    drawDeps.imgui.Text('Keyboard trigger (optional):');
                    local current=drawDeps.state.statebarHotkeys[i] or 0;
                    if drawDeps.imgui.BeginCombo('Key to press##statebarhotkey'..i,drawDeps.DIRECT_NAMES[current] or 'None') then
                        for _,option in ipairs(drawDeps.DIRECT_KEY_OPTIONS) do
                            local label,code=option[1],option[2];
                            local clash=(code~=0 and ((drawDeps.shortcuts_active() and drawDeps.mapped_key(code)~=nil) or (drawDeps.state.navKeysEnabled and (code==drawDeps.nav_scan() or code==drawDeps.row_key() or drawDeps.NAV_ACTIONS[code]))));
                            if not clash then
                                for j=1,#drawDeps.state.statebarSlots do if j~=i and drawDeps.state.statebarHotkeys[j]==code and code~=0 then clash=true; end end
                            end
                            if not clash and drawDeps.imgui.Selectable(label..'##statebarhotopt'..i..'_'..code,current==code) then drawDeps.state.statebarHotkeys[i]=code; drawDeps.save_display(); end
                        end
                        drawDeps.imgui.EndCombo();
                    end
                    drawDeps.imgui.SameLine();
                    if drawDeps.imgui.Button('Remove##bar'..i) then
                        table.remove(drawDeps.state.statebarSlots,i);
                        for j=i,#drawDeps.state.statebarSlots do drawDeps.state.statebarHotkeys[j]=drawDeps.state.statebarHotkeys[j+1]; end
                        drawDeps.state.statebarHotkeys[#drawDeps.state.statebarSlots+1]=nil;
                        if drawDeps.state.statebarSelected==i then drawDeps.state.statebarSelected=0
                        elseif drawDeps.state.statebarSelected>i then drawDeps.state.statebarSelected=drawDeps.state.statebarSelected-1; end
                        drawDeps.save_display();
                        break;
                    end
                end
                if #drawDeps.state.statebarSlots<12 and drawDeps.imgui.Button('Add StateBar slot') then table.insert(drawDeps.state.statebarSlots,{row='CTRL',slot=1}); drawDeps.save_display(); end
                drawDeps.imgui.TextWrapped('StateBar uses the current book and set. State slots keep a highlight; Utility slots run once.');
                end
            end
            if drawDeps.state.settingsTab=='Appearance' then
            if drawDeps.imgui.CollapsingHeader('Display',ImGuiTreeNodeFlags_DefaultOpen or 32) then
                        local auto={drawDeps.state.autoHide};
            drawDeps.imgui.TextWrapped('These inactivity settings apply to Toggle mode.');
            if drawDeps.imgui.Button('Unlock HUD for dragging') then drawDeps.state.hudPos=nil; drawDeps.state.positionLocked=false; drawDeps.save_display(); end
            drawDeps.imgui.SameLine();
            if drawDeps.imgui.Button('Save this character layout now') then
                drawDeps.save_display();
                drawDeps.state.layoutSaveNotice=drawDeps.state.profileReady and ('Saved for '..tostring(drawDeps.state.profileId)) or 'Log in to save a character layout';
            end
            if drawDeps.state.layoutSaveNotice then drawDeps.imgui.TextWrapped(drawDeps.state.layoutSaveNotice); end
            if drawDeps.imgui.Checkbox('Auto-hide macro display (Toggle mode)',auto) then drawDeps.state.autoHide=auto[1]; drawDeps.state.hudLastActivity=os.clock(); drawDeps.state.hudHasInteracted=true; drawDeps.state.hudImmediateHide=false; drawDeps.save_display(); end
            drawDeps.imgui.Text('Hide after activity / inactivity:');
            for _,seconds in ipairs({0,2,5,10,15,30}) do
                if seconds~=0 then drawDeps.imgui.SameLine(); end
                local duration=seconds==0 and 'Immediately (0s)' or (seconds..'s');
                if drawDeps.imgui.Button((drawDeps.state.autoHideDelay==seconds and '[' or '')..duration..(drawDeps.state.autoHideDelay==seconds and ']' or '')..'##hide'..seconds) then drawDeps.state.autoHideDelay=seconds; drawDeps.state.hudLastActivity=os.clock(); drawDeps.state.hudHasInteracted=true; drawDeps.state.hudImmediateHide=false; drawDeps.save_display(); end
            end
            drawDeps.imgui.TextWrapped('0s hides after an action; longer choices hide after inactivity.');
            drawDeps.imgui.Text('When the macros auto-hide:');
            if drawDeps.imgui.Button('Hide completely'..(drawDeps.state.autoHideMode=='hide' and ' [selected]' or '')) then drawDeps.state.autoHideMode='hide'; drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Keep small Decker button'..(drawDeps.state.autoHideMode=='collapse' and ' [selected]' or '')) then drawDeps.state.autoHideMode='collapse'; drawDeps.save_display(); end
            drawDeps.imgui.TextWrapped('First-time setup: select Hide completely only after Decker is working and you know how to reopen it with /decker settings or /decker show.');
            drawDeps.imgui.TextWrapped('Reopen Settings with /decker settings or show macros with /decker show.');
            local motion={drawDeps.state.motionEnabled};
            if drawDeps.imgui.Checkbox('Subtle animations (uncheck for reduced motion)',motion) then drawDeps.state.motionEnabled=motion[1]; drawDeps.save_display(); end
            local scroll={drawDeps.state.showScrollbars};
            if drawDeps.imgui.Checkbox('Show scrollbars',scroll) then drawDeps.state.showScrollbars=scroll[1]; drawDeps.save_display(); end
            for _,item in ipairs({{'Outer window','outerOpacity'},{'Inner macro panel','panelOpacity'},{'Macro buttons','buttonOpacity'}}) do
                local key=item[2];
                drawDeps.imgui.Text(('%s opacity: %d%%'):format(item[1],math.floor(drawDeps.state[key]*100+.5)));
                if drawDeps.imgui.Button('Less##'..key) then drawDeps.state[key]=math.max(0,drawDeps.state[key]-.05); drawDeps.save_display(); end
                drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('More##'..key) then drawDeps.state[key]=math.min(1,drawDeps.state[key]+.05); drawDeps.save_display(); end
            end
            if drawDeps.imgui.BeginCombo('Macro font',drawDeps.state.macroFont) then
                for _,name in ipairs({'Arial Bold','Segoe UI Bold','Times New Roman Bold','Default'}) do
                    if drawDeps.imgui.Selectable(name,drawDeps.state.macroFont==name) then drawDeps.state.macroFont=name; drawDeps.save_display(); end
                end
                drawDeps.imgui.EndCombo();
            end
            drawDeps.imgui.Text(drawDeps.glass.diagnostic);
            drawDeps.imgui.Text(drawDeps.state.macroFont=='Default' and 'Using host default font' or drawDeps.glass.fonts[drawDeps.state.macroFont] and ('Using '..state.macroFont) or (drawDeps.state.macroFont..' missing; using host default'));
            drawDeps.imgui.Text(('Macro font size: %d'):format(drawDeps.state.macroFontSize));
            if drawDeps.imgui.Button('Font smaller') then drawDeps.state.macroFontSize=math.max(10,drawDeps.state.macroFontSize-1); drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Font larger') then drawDeps.state.macroFontSize=math.min(28,drawDeps.state.macroFontSize+1); drawDeps.save_display(); end
            drawDeps.imgui.Text('Last-used macro highlight colour:');
            if drawDeps.imgui.Button('Classic') then drawDeps.state.theme=1; drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Blue') then drawDeps.state.theme=2; drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Purple') then drawDeps.state.theme=3; drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Minimal') then drawDeps.state.theme=4; drawDeps.save_display(); end
            if drawDeps.imgui.Button('Display smaller') then drawDeps.state.scale=math.max(.7,drawDeps.state.scale-.1); drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); drawDeps.imgui.Text(('Scale %.0f%%'):format(drawDeps.state.scale*100)); drawDeps.imgui.SameLine();
            if drawDeps.imgui.Button('Display larger') then drawDeps.state.scale=math.min(1.5,drawDeps.state.scale+.1); drawDeps.save_display(); end
            drawDeps.imgui.Text(('Macro button width: %d (before display scaling)'):format(drawDeps.state.hudWidth));
            if drawDeps.imgui.Button('Narrower buttons') then drawDeps.state.hudWidth=math.max(80,drawDeps.state.hudWidth-8); drawDeps.save_display(); end
            drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Wider buttons') then drawDeps.state.hudWidth=math.min(140,drawDeps.state.hudWidth+8); drawDeps.save_display(); end
            local ck={drawDeps.state.compactKeys};
            if drawDeps.imgui.Checkbox('Short key labels (F1 instead of CTRL 1 | F1)',ck) then drawDeps.state.compactKeys=ck[1]; drawDeps.save_display(); end
            drawDeps.imgui.Separator();
            end
            end -- General / Appearance tab
            if drawDeps.state.settingsTab=='Controls' then
                drawDeps.imgui.Text('KEYS AND MACRO CONTROLS');
                if drawDeps.imgui.Button('Connect to in-game macros##quick') then drawDeps.connect_macros(); end
            local automatic={drawDeps.state.autoConnect};
            if drawDeps.imgui.Checkbox('Auto-connect macros after login',automatic) then
                drawDeps.state.autoConnect=automatic[1]; drawDeps.state.autoConnectPending=false; drawDeps.save_display();
            end
                if drawDeps.state.allowAllClicks and drawDeps.state.phase>=4 and #drawDeps.state.names==20 then
                    local assigned={drawDeps.state.savedKeybinds};
                    if drawDeps.imgui.Checkbox('Use my assigned keys',assigned) then
                        drawDeps.state.keybinds=assigned[1]; drawDeps.state.savedKeybinds=assigned[1];
                        drawDeps.state.acknowledgeKeys=assigned[1]; drawDeps.state.savedAck=assigned[1];
                        if assigned[1] then drawDeps.state.savedNavEnabled=true; drawDeps.state.navKeysEnabled=true; end
                        drawDeps.state.held={}; drawDeps.nav_clear(); drawDeps.save_display();
                    end
                    drawDeps.imgui.TextWrapped(drawDeps.state.savedKeybinds and 'Saved ON.' or 'Saved OFF.');
                else
                    drawDeps.imgui.TextWrapped(drawDeps.state.savedKeybinds and 'Assigned keys saved ON; connect to activate.' or 'Assigned keys saved OFF. Connect to change.');
                end
                local nav={drawDeps.state.savedNavEnabled};
                if drawDeps.imgui.Checkbox('Enable navigation hotkeys',nav) then
                    drawDeps.state.savedNavEnabled=nav[1]; drawDeps.state.navKeysEnabled=nav[1];
                    drawDeps.nav_clear(); drawDeps.save_display();
                end
                drawDeps.imgui.TextWrapped('Uses the mod key, row switch and arrows. Assigned keys also enables this.');
                if drawDeps.shortcuts_active() then
                    local layout=({numbers='Both rows: 1-0',functions='Both rows: F1-F10',split='F1-F10 / 1-0',custom='Custom keys in use'})[drawDeps.state.mappingMode];
                    drawDeps.imgui.Text('Key layout: '..(layout or 'Both rows: 1-0'));
                    if not drawDeps.state.keyAssignmentPage then
                        for _,mode in ipairs({{'numbers','Both rows: 1-0'},{'functions','Both rows: F1-F10'},{'split','F1-F10 / 1-0'},{'custom','Custom keys (saved slots)'}}) do
                            if drawDeps.imgui.Button((drawDeps.state.mappingMode==mode[1] and '[X] ' or '')..mode[2]) then
                                drawDeps.state.mappingMode=mode[1];
                                if mode[1]=='split' then drawDeps.state.directKeys=drawDeps.default_direct_keys(); end
                                drawDeps.state.held={}; drawDeps.save_display();
                            end
                        end
                        if drawDeps.imgui.Button('Customise keys for both rows') then drawDeps.state.keyAssignmentPage=true; end
                        if drawDeps.state.mappingMode=='numbers' or drawDeps.state.mappingMode=='functions' then
                            drawDeps.imgui.TextWrapped('Press the mod key, then the row key to switch rows.');
                            drawDeps.imgui.Text('Active row: '..(drawDeps.state.navRow=='ALT' and 'LOWER' or 'UPPER')..' | Mod key: '..state.navModifier..' | Switch row: '..state.rowSwitchKey);
                        end
                        if drawDeps.imgui.CollapsingHeader('Advanced keys') then
                            drawDeps.imgui.Text('Navigator');
                            if drawDeps.imgui.BeginCombo('Macro visibility mod key',drawDeps.state.navModifier) then
                                for _,choice in ipairs(drawDeps.NAV_KEY_OPTIONS) do
                                    if drawDeps.imgui.Selectable(choice,drawDeps.state.navModifier==choice) then
                                        if choice==drawDeps.state.rowSwitchKey then drawDeps.state.rowSwitchKey=drawDeps.state.navModifier; end
                                        drawDeps.state.navModifier=choice; drawDeps.state.navKeysEnabled=false; drawDeps.state.savedNavEnabled=false; drawDeps.nav_clear(); drawDeps.save_display();
                                    end
                                end
                                drawDeps.imgui.EndCombo();
                            end
                            drawDeps.imgui.TextWrapped('Shows the HUD and enables navigation. Default: Right Shift.');
                            if (drawDeps.state.navModifier=='RSHIFT' or drawDeps.state.navModifier=='LSHIFT') and drawDeps.imgui.CollapsingHeader('Windows Shift shortcut help') then
                                drawDeps.imgui.TextWrapped('Five Shift presses can open Windows Sticky Keys. In Windows Settings, search Sticky keys and turn off its keyboard shortcut. You can also choose HOME as your Decker mod key.');
                            end
                            if drawDeps.imgui.BeginCombo('Switch row key',drawDeps.state.rowSwitchKey) then
                                for _,choice in ipairs(drawDeps.NAV_KEY_OPTIONS) do
                                    if drawDeps.imgui.Selectable(choice,drawDeps.state.rowSwitchKey==choice) then if choice==drawDeps.state.navModifier then drawDeps.state.navModifier=drawDeps.state.rowSwitchKey; end; drawDeps.state.rowSwitchKey=choice; drawDeps.nav_clear(); drawDeps.save_display(); end
                                end
                                drawDeps.imgui.EndCombo();
                            end
                            drawDeps.imgui.TextWrapped('Switches rows while navigation is active. Choose NUMPAD1 for a laptop End key.');
                            if drawDeps.imgui.BeginCombo('Macro mod behaviour',drawDeps.state.stickyNavigation and 'Press key once (Toggle)' or 'Hold key pressed down') then
                                if drawDeps.imgui.Selectable('Press key once (Toggle)',drawDeps.state.stickyNavigation) then drawDeps.state.stickyNavigation=true; drawDeps.nav_clear(); drawDeps.save_display(); end
                                if drawDeps.imgui.Selectable('Hold key pressed down',not drawDeps.state.stickyNavigation) then drawDeps.state.stickyNavigation=false; drawDeps.nav_clear(); drawDeps.save_display(); end
                                drawDeps.imgui.EndCombo();
                            end
                            drawDeps.imgui.TextWrapped(drawDeps.state.stickyNavigation and 'Tap to show; tap again to hide.' or 'Hold to show; release to hide.');
                            local echo={drawDeps.state.echoLock};
                            if drawDeps.imgui.Checkbox('Echo macro visibility on/off to chat',echo) then drawDeps.state.echoLock=echo[1]; drawDeps.save_display(); end
                        end
                    end
                    if not drawDeps.state.keyAssignmentPage and drawDeps.imgui.CollapsingHeader('Cooldown action mapping') then
            drawDeps.imgui.Text('Recast clocks and countdowns');
            local cool={drawDeps.state.cooldownEnabled};
            if drawDeps.imgui.Checkbox('Show clocks and cooldown countdowns',cool) then drawDeps.state.cooldownEnabled=cool[1]; drawDeps.save_display(); end
            local auto={drawDeps.state.cooldownAutoNames};
            if drawDeps.imgui.Checkbox('Use exact-label guess only when macro commands are unavailable',auto) then drawDeps.state.cooldownAutoNames=auto[1]; drawDeps.save_display(); end
            drawDeps.imgui.TextWrapped('Decker reads macro commands first. A manual action overrides detection and stays with those commands if you rename the macro.');
            local page,fingerprint=drawDeps.cooldown.page();
            local mapped=0;
            if page then for n=1,20 do if drawDeps.cooldown.binding(page,fingerprint,n) then mapped=mapped+1; end end end
            drawDeps.imgui.Text(('Manual overrides on current page: %d / 20'):format(mapped));
            if not drawDeps.state.cooldownEnabled then drawDeps.imgui.TextWrapped('Clocks are OFF. Tick Show clocks and cooldown countdowns above.'); end
            for i=1,20 do
                local b=drawDeps.cooldown.binding(page,fingerprint,i);
                local label=(i<=10 and 'CTRL ' or 'ALT ')..tostring((i-1)%10+1);
                drawDeps.imgui.Text(label..': '..(b and (b.kind..' '..b.id) or 'unmapped'));
                drawDeps.imgui.SameLine();
                if b and drawDeps.imgui.Button('Clear##cool'..i) then drawDeps.state.cooldownBindings[page..i]=nil; drawDeps.save_display(); end
            end
            local selected=math.max(1,math.min(20,tonumber(drawDeps.state.cooldownDrafts.selected) or 1));
            local selectedLabel=(selected<=10 and 'CTRL ' or 'ALT ')..tostring((selected-1)%10+1);
            if drawDeps.imgui.BeginCombo('Macro slot',selectedLabel) then
                for i=1,20 do
                    local item=(i<=10 and 'CTRL ' or 'ALT ')..tostring((i-1)%10+1);
                    if drawDeps.imgui.Selectable(item,selected==i) then drawDeps.state.cooldownDrafts.selected=i; selected=i; end
                end
                drawDeps.imgui.EndCombo();
            end
            local manual=drawDeps.cooldown.binding(page,fingerprint,selected);
            local detected,reason,candidates=drawDeps.cooldown.infer_macro(selected);
            if not detected and reason=='unavailable' then detected=drawDeps.cooldown.infer(drawDeps.state.names[selected]); end
            drawDeps.imgui.Text('Detected: '..(detected and (detected.name or (detected.kind..' '..detected.id)) or reason=='ambiguous' and ('multiple actions ('..#candidates..')') or 'no trackable action'));
            drawDeps.imgui.Text('Manual: '..(manual and (manual.name or (manual.kind..' '..manual.id)) or 'automatic'));
            local draft={drawDeps.state.cooldownDrafts.text or ''};
            if drawDeps.imgui.InputText('Spell or ability name',draft,65) then drawDeps.state.cooldownDrafts.text=draft[1]; end
            if drawDeps.imgui.Button('Map action') then
                local action=drawDeps.cooldown.resolve_action(drawDeps.state.cooldownDrafts.text or '');
                if page and action then
                    local signature=drawDeps.cooldown.macro_signature(selected,fingerprint);
                    drawDeps.state.cooldownBindings[page..selected]={kind=action.kind,id=action.id,name=action.name,fingerprint=signature};
                    drawDeps.state.cooldownDrafts.text=''; drawDeps.state.cooldownStatus=nil; drawDeps.save_display();
                else drawDeps.state.cooldownStatus=page and 'Enter an exact spell or ability name.' or 'Refresh the current macro page first.'; end
            end
            drawDeps.imgui.SameLine();
            if drawDeps.imgui.Button('Use automatic') and page then drawDeps.state.cooldownBindings[page..selected]=nil; drawDeps.state.cooldownStatus=nil; drawDeps.save_display(); end
            if drawDeps.state.cooldownStatus then drawDeps.imgui.TextWrapped(drawDeps.state.cooldownStatus); end
            if drawDeps.imgui.CollapsingHeader('Manual mapping help') then drawDeps.imgui.TextWrapped('Enter the actual spell or ability name, for example Mage\'s Ballad or Shield Bash. Advanced: /decker cooldown ctrl 1 spell ID or ability TIMER_ID.'); end
                        drawDeps.imgui.Separator();
                    end -- cooldown options
                    if drawDeps.state.keyAssignmentPage then
                        if drawDeps.imgui.Button('Back to key layouts') then drawDeps.state.keyAssignmentPage=false; end
                        drawDeps.imgui.Text('Custom keys for both rows');
            drawDeps.imgui.Text('Upper row - CTRL macros (slots 1-10)');
            drawDeps.imgui.TextWrapped('Choose a key for each slot. None leaves it unassigned.');
            for i=1,20 do
                if i==11 then drawDeps.imgui.Separator(); drawDeps.imgui.Text('Lower row - ALT macros (slots 1-10)'); end
                local slot=(i-1)%10+1;
                local code=drawDeps.state.directKeys[i] or 0;
                local name=drawDeps.DIRECT_NAMES[code] or 'None';
                if drawDeps.imgui.BeginCombo(('Slot %d##direct%d'):format(slot,i),name) then
                    for _,choice in ipairs(drawDeps.DIRECT_KEY_OPTIONS) do
                        local candidate=choice[2];
                        if drawDeps.imgui.Selectable(choice[1]..'##directchoice'..i..'_'..candidate,code==candidate) then
                            local statebarClash=false;
                            for _,key in pairs(drawDeps.state.statebarHotkeys) do if candidate~=0 and key==candidate then statebarClash=true; end end
                            if not drawDeps.direct_conflict(candidate,i) and not statebarClash then
                                drawDeps.state.directKeys[i]=candidate; drawDeps.state.mappingMode='custom'; drawDeps.state.keySummary='Custom keys in use'; drawDeps.state.held={}; drawDeps.save_display();
                            else
                                drawDeps.state.keySummary='Binding conflict: key already used or reserved by navigation';
                            end
                        end
                    end
                    drawDeps.imgui.EndCombo();
                end
            end
            drawDeps.imgui.TextWrapped(drawDeps.state.keySummary);
            if drawDeps.imgui.Button('Reset to F1-F10 / 1-0 layout') then
                drawDeps.state.directKeys=drawDeps.default_direct_keys(); drawDeps.state.mappingMode='split'; drawDeps.state.keySummary='F1-F10 / 1-0 layout';
                drawDeps.state.held={}; drawDeps.save_display();
            end
                    end -- custom key page
                else
                    drawDeps.imgui.TextWrapped('Connect to macros and enable assigned keys to edit layouts.');
                end -- key controls enabled
            end -- Controls tab
            if drawDeps.state.settingsTab=='General' and drawDeps.imgui.CollapsingHeader('Book and Set controls') then
                if drawDeps.state.allowSwitch and drawDeps.validaddr(drawDeps.state.addresses.set_book) then
                    if drawDeps.imgui.BeginCombo('In-game macro book',drawDeps.book_label(drawDeps.state.manualBook or 1)) then
                        for book=1,drawDeps.BOOK_COUNT do if drawDeps.imgui.Selectable(drawDeps.book_label(book)..'##nativebook'..book,drawDeps.state.manualBook==book) then drawDeps.select_native_book(book); end end
                        drawDeps.imgui.EndCombo();
                    end
                else drawDeps.imgui.TextWrapped('Connect to in-game macros to switch books.'); end
                local book=drawDeps.state.manualBook or 1;
                local alias={drawDeps.state.bookAliases[book] or ''};
                if drawDeps.imgui.InputText('Decker name for this book',alias,33) then drawDeps.state.bookAliases[book]=alias[1]~='' and alias[1]:gsub('[%c#]',''):sub(1,32) or nil; drawDeps.save_display(); end
                if drawDeps.imgui.CollapsingHeader('Import saved in-game book names') then
                    local folder={drawDeps.state.bookPath};
                    if drawDeps.imgui.InputText('This character macro folder',folder,1025) then drawDeps.state.bookPath=folder[1]; drawDeps.save_display(); end
                    drawDeps.imgui.TextWrapped('Choose this character’s FFXI USER folder, then refresh after renaming books in game.');
                    if drawDeps.imgui.Button('Read or refresh book names') then drawDeps.refresh_book_titles(); end
                    drawDeps.imgui.TextWrapped(drawDeps.state.bookNameStatus);
                end
                drawDeps.imgui.TextWrapped(drawDeps.state.switchSummary);
                if drawDeps.state.allowSwitch then
                    drawDeps.imgui.Text('Jump to macro set:');
                    for i=1,10 do
                        if i>1 then drawDeps.imgui.SameLine(); end
                        if drawDeps.imgui.Button(tostring(i)..'##more_set'..i,{30,24}) then drawDeps.select_page(i); end
                    end
                else
                    drawDeps.imgui.TextWrapped('Macro set switching is unavailable until native macros connect.');
                end
            end
            if drawDeps.state.settingsTab=='General' and drawDeps.state.showAdvanced and drawDeps.imgui.CollapsingHeader('Combat Alerts') then
                drawDeps.imgui.TextWrapped('Recast ready alerts only; a new recast does NOT prove a spell succeeded. No enemy-action automation.');
                for _,alert in ipairs(drawDeps.cooldown.alerts()) do drawDeps.imgui.TextWrapped(alert.kind..': '..alert.name); end
            end
            if drawDeps.state.settingsTab=='General' and drawDeps.state.showAdvanced and drawDeps.imgui.CollapsingHeader('Combat Analytics') then
                drawDeps.imgui.TextWrapped('Records macro button attempts and native requests; cannot prove a spell actually cast. Never moves buttons.');
                local a=drawDeps.analytics.active;
                drawDeps.imgui.TextWrapped(a and ('Recording '..a.kind:upper()..': '..a.label) or 'No active session');
                if not a then
                    if drawDeps.imgui.Button('Start HNM session') then drawDeps.analytics.start('hnm','HNM');end
                    drawDeps.imgui.SameLine();if drawDeps.imgui.Button('Start EXP session') then drawDeps.analytics.start('exp','EXP');end
                else
                    if drawDeps.imgui.Button('Stop recording') then drawDeps.analytics.stop();end
                end
                if drawDeps.imgui.Button('Print top 10 in chat') then for _,line in ipairs(drawDeps.analytics.report()) do drawDeps.say(line,true);end end
                drawDeps.imgui.TextWrapped('Named session: /decker session start hnm Tiamat (or exp Camp). Stop: /decker session stop. Report: /decker session report. Statistics are memory-only and reset on character change or client exit.');
            end
            if drawDeps.state.settingsTab=='General' and drawDeps.state.showAdvanced and drawDeps.imgui.CollapsingHeader('Quick Start Guide') then
                drawDeps.imgui.TextWrapped('Decker - Enhanced In-Game Macro Interface for FFXI')
                drawDeps.imgui.TextWrapped('1. Open FFXI and load Decker in Ashita.')
                drawDeps.imgui.TextWrapped('2. Open Settings. Select Refresh macro names to load your current Ctrl/Alt macro labels.')
                drawDeps.imgui.TextWrapped('3. Open Settings > Controls. Choose your Macro visibility mod key (default Right Shift).')
                drawDeps.imgui.TextWrapped('IMPORTANT: Avoid Ctrl and Alt for Decker navigation. Keep them for FFXI original macros.')
                drawDeps.imgui.TextWrapped('4. Choose Hold to navigate or Toggle / Lock, whichever feels best.')
                drawDeps.imgui.TextWrapped('5. Enable custom navigation, then close Settings.')
                drawDeps.imgui.TextWrapped('6. Hold or tap your chosen modifier. Left/Right selects slots; End switches Ctrl/Alt rows.')
                drawDeps.imgui.TextWrapped('7. Up/Down changes sets; Enter runs the selected macro.')
                drawDeps.imgui.TextWrapped('8. Release or tap the modifier again to exit navigation. Ready!')
                drawDeps.imgui.Separator()
                drawDeps.imgui.TextWrapped('If macro names are missing or outdated, use Refresh macro names again. Your original FFXI macros remain unchanged.')
            end
            drawDeps.imgui.Separator();
            if drawDeps.state.settingsTab=='General' and drawDeps.imgui.Button(drawDeps.state.showAdvanced and 'Hide developer tools' or 'Developer tools') then drawDeps.state.showAdvanced=not drawDeps.state.showAdvanced; end
            if drawDeps.state.settingsTab=='General' and drawDeps.state.showAdvanced then
                if drawDeps.imgui.Button('Interactive guide') then drawDeps.open_guide(); end
                local logging={drawDeps.state.debugLog};
                if drawDeps.imgui.Checkbox('Developer chat logging',logging) then drawDeps.state.debugLog=logging[1]; end
                local inputLogging={drawDeps.inputDiag.enabled};
                if drawDeps.imgui.Checkbox('Input diagnostics (memory only)',inputLogging) then
                    drawDeps.inputDiag.enabled=inputLogging[1]
                    if drawDeps.inputDiag.enabled then drawDeps.inputDiag.clear() end
                end
                drawDeps.imgui.TextWrapped(('Input diagnostic events: %d / %d. Use /decker inputtrace report 20 in chat.'):format(#drawDeps.inputDiag.records,drawDeps.inputDiag.limit))
                drawDeps.imgui.TextWrapped('No chat text or macro bodies captured. Disable after reproducing a fault.');
                drawDeps.imgui.TextWrapped('Native book/set getters remain unverified. Native arrow selection is not highlighted until a reliable getter exists.');
                drawDeps.imgui.TextWrapped('Read status: '..state.nameSummary);
                drawDeps.imgui.TextWrapped('Pointers: '..state.pointerSummary);
                drawDeps.imgui.TextWrapped('Signatures: '..state.summary);
                drawDeps.imgui.TextWrapped('Native set/book numbers are not independently detected.');
                drawDeps.imgui.TextWrapped('Decker does not modify the original FFXI HUD.');
                if drawDeps.imgui.Button('Reconnect (native calls)') then drawDeps.connect_macros(); end
                drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Rescan only') then drawDeps.scan(); end
                if drawDeps.imgui.Button('Show/hide signature details') then drawDeps.state.details=not drawDeps.state.details; end
                if drawDeps.state.details then for _,p in ipairs(drawDeps.state.signatures) do drawDeps.imgui.TextWrapped(p[1]..': '..p[2]); end end
            end
            if (drawDeps.state.settingsTab=='General' or drawDeps.state.settingsTab=='Controls') and drawDeps.state.phase>=4 and drawDeps.imgui.Button('Refresh macro names') then drawDeps.state.confirmAll=true; drawDeps.read_all_names(); end
            drawDeps.imgui.Separator(); drawDeps.imgui.Text('Decker v'..addon.version..'  |  by Mutant X')
            if drawDeps.state.showAdvanced then drawDeps.imgui.TextWrapped('CatseyeXI: T1 Sanctioned - approved 19 October 2026.'); end
            local section=moreActive and 'General' or drawDeps.state.settingsTab;
            if drawDeps.imgui.Button('Restore section defaults') then drawDeps.state.resetSection=section; end
            if drawDeps.state.resetSection==section then
                drawDeps.imgui.Text('Restore only this section?');
                if drawDeps.imgui.Button('Confirm restore') then drawDeps.restore_section(section); drawDeps.state.resetSection=nil; end
                drawDeps.imgui.SameLine(); if drawDeps.imgui.Button('Cancel restore') then drawDeps.state.resetSection=nil; end
            end
            if drawDeps.imgui.Button('Close settings') then drawDeps.state.showTests=false; end
        end
        drawDeps.imgui.End();
        if thinScroll then drawDeps.imgui.PopStyleVar(); end
        if not settingsOpen[1] then drawDeps.state.showTests=false; end
    end
    drawDeps.guide_draw(); -- Independent of Settings and HUD visibility; preview never invokes native calls.
end);

