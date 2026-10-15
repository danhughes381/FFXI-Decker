-- Decker 1.30: native macro read proof-of-concept for VanaCore/Ashita 4.
-- Native macro calls and opt-in DirectInput keyboard hooks; no original HUD patches.
-- CAUTION: Opt-in native FFI call may crash the FFXI process if signatures/API differ.
addon.name = 'Decker';
addon.author = 'Mutant X';
addon.version = '1.48-dev';
addon.desc = 'FFXI-inspired dual-row macro HUD; validated mouse execution and opt-in keyboard controls.';
require('common');
local chat = require('chat');
local imgui = require('imgui');
local ffi = require('ffi');
ffi.cdef[[typedef const char* (__thiscall* Decker_FsMacroContainer_getName_f)(uint32_t, uint32_t); typedef int32_t (__thiscall* Decker_FsMacroContainer_setPage_f)(uint32_t, uint32_t); typedef int32_t (__thiscall* Decker_FsMacroContainer_setBook_f)(uint32_t, uint32_t); typedef void (__thiscall* Decker_FsMacroContainer_runMacro_f)(uint32_t, uint8_t, uint8_t);]];
local state = { visible=true, signatures={}, addresses={}, summary='Not scanned', pointerSummary='Not checked', nameSummary='Not attempted', phase=0, confirm=false, confirmAll=false, scanning=false, names={}, setHint='Current in-game set (not independently detected)', nameCount=0, allowSwitch=false, selectedPage=nil, previousFingerprint=nil, changeSummary='Not checked', switchSummary='Not attempted', autoRefresh=false, refreshAt=0, refreshInterval=3, compact=true, details=false, showTests=false, clickConsent=false, clickSummary='Not attempted', scale=1.0, refreshErrorCount=0, hudWidth=92, hudHeight=43, allowAllClicks=false, nativeHudStudy=false, theme=1, compactKeys=true, keybinds=false, acknowledgeKeys=false, held={}, keySummary='Exclusive bindings OFF by default', preserveNativeArrows=true, pendingRefreshFrames=0, manualBook=1, trackedSet=1, trackedSource='default (unverified)', suppressed={}, nativeArrowRefreshes=0, showAdvanced=false, debugLog=false, flashRow=nil, flashSlot=nil, flashUntil=0, navSlot=nil, navRow=nil, navSource='unverified', navHeld={}, navModifier='RSHIFT', navKeysEnabled=false, navModifierHeld=false, navCaptured={}, navUpHeld=false, navDownHeld=false, stickyNavigation=true, navToggleActive=false, navPressed={}, navPhysicalDown=false, navHeldKeys={}, navPhysicalKeys={}, navQueue={}, navRow='CTRL', navSlot=1, navSource='default', savedNavEnabled=false, savedKeybinds=false, savedAck=false, activeRowKeys=false, rowSwitchKey='END', hudOpacity=1.0, echoLock=true, autoHide=true, autoHideDelay=10, autoHideMode='hide', hudLastActivity=os.clock(), hudWasActive=false, hudReadySince=nil, hudHasInteracted=false, hudForceReveal=false };
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
local function direct_conflict(code,index)
    if code==0 then return false; end
    for i,k in ipairs(state.directKeys) do if i~=index and k==code then return true; end end
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
    return directory and (directory..'decker_display.cfg') or nil;
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
    local path=settings_path(); if not path then return; end
    local ok,f=pcall(io.open,path,'w'); if not ok or not f then return; end
    f:write('theme=',state.theme,'\nscale=',state.scale,'\nwidth=',state.hudWidth,'\nheight=',state.hudHeight,'\ncompact=',state.compactKeys and '1' or '0','\nbook=',state.manualBook or 1,'\nset=',state.trackedSet or 1,'\nopacity=',state.hudOpacity,'\nautohide=',state.autoHide and '1' or '0','\nautohidedelay=',state.autoHideDelay,'\nautohidemode=',state.autoHideMode,'\necholock=',state.echoLock and '1' or '0','\nrowswitchkey=',state.rowSwitchKey,'\nnavmodifier=',state.navModifier,'\nnavmode=',state.stickyNavigation and 'toggle' or 'hold','\nnavenabled=',state.navKeysEnabled and '1' or '0','\nactiverowkeys=',state.activeRowKeys and '1' or '0','\nkeybinds=',state.keybinds and '1' or '0','\nackkeys=',state.acknowledgeKeys and '1' or '0','\n');
    f:write('cooldownenabled=',state.cooldownEnabled and '1' or '0','\n');
    for i=1,20 do local b=state.cooldownBindings[i]; if b then f:write('cooldown',i,'=',b.kind,':',b.id,'\n'); end end
    for i=1,20 do f:write('direct',i,'=',state.directKeys[i] or 0,'\n'); end
    f:close();
end
local function load_display()
    local path=settings_path(); if not path then return; end
    local ok,f=pcall(io.open,path,'r'); if not ok or not f then return; end
    for line in f:lines() do
        local key,value=line:match('^(%w+)=([%w.:]+)$');
        local n=tonumber(value);
        if key=='cooldownenabled' then state.cooldownEnabled=value=='1'; end
        local ci=key and tonumber(key:match('^cooldown(%d+)$'));
        if ci and ci>=1 and ci<=20 then local kind,id=value:match('^(spell):(%d+)$'); if not kind then kind,id=value:match('^(ability):(%d+)$'); end; if kind and tonumber(id) then state.cooldownBindings[ci]={kind=kind,id=tonumber(id)}; end end
        local directIndex=key and tonumber(key:match('^direct(%d+)$'));
        if directIndex and directIndex>=1 and directIndex<=20 and n and DIRECT_NAMES[n] then state.directKeys[directIndex]=n; end
        if key=='autohide' and (value=='0' or value=='1') then state.autoHide=value=='1'; end
        if key=='autohidedelay' and (n==2 or n==5 or n==10 or n==15 or n==30) then state.autoHideDelay=n; end
        if key=='autohidemode' and (value=='hide' or value=='collapse') then state.autoHideMode=value; end
        if key=='echolock' and (value=='0' or value=='1') then state.echoLock=value=='1'; end
        if key=='opacity' and n and n>=0.2 and n<=1 then state.hudOpacity=n; end
        if key=='rowswitchkey' and (value=='END' or value=='HOME' or value=='INSERT' or value=='DELETE' or value=='N' or value=='F9' or value=='F10' or value=='F11' or value=='F12') then state.rowSwitchKey=value; end
        if key=='stickynav' and (value=='0' or value=='1') then state.stickyNavigation=value=='1'; end
        if key=='navmode' and (value=='toggle' or value=='hold') then state.stickyNavigation=value=='toggle'; end
        if key=='navenabled' and (value=='0' or value=='1') then state.savedNavEnabled=value=='1'; end
        if key=='activerowkeys' and (value=='0' or value=='1') then state.activeRowKeys=value=='1'; end
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
load_display();
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
-- Rendering uses normal imgui buttons; FFXI's original HUD is not modified.
local palettes = {
    {name='Classic', marker='', color={0.27,0.26,0.36,1}, text={1.0,0.94,0.75,1}},
    {name='Blue', marker='', color={0.15,0.26,0.39,1}, text={0.74,0.91,1,1}},
    {name='Purple', marker='', color={0.31,0.22,0.40,1}, text={0.94,0.80,1,1}},
    {name='Minimal', marker='', color={0.19,0.19,0.20,1}, text={1,1,1,1}},
};
local function draw_row(title,offset)
    local w=math.floor(state.hudWidth*state.scale);
    local h=math.floor(state.hudHeight*state.scale);
    -- Let all ten buttons share resized client area; guard on VanaCore ImGui support.
    if type(imgui.GetContentRegionAvail)=='function' then
        local ok,avail=pcall(imgui.GetContentRegionAvail);
        if ok and type(avail)=='table' and type(avail[1])=='number' then
            w=math.max(42,math.floor((avail[1]-36)/10));
        end
    end
    local theme=palettes[state.theme] or palettes[1];
    for i=1,10 do
        if i>1 then imgui.SameLine(); end
        local name=state.names[offset+i] or '';
        local shortcut;
        if state.keybinds then
            shortcut=DIRECT_NAMES[state.directKeys[(title=='CTRL' and 0 or 10)+i]] or '?';
        else
            shortcut=(title=='CTRL' and 'C' or 'A')..tostring(i==10 and 0 or i);
        end
        -- Only the name and its compact key label belong on the button.
        local label=(name=='' and ' ' or name)..'\n'..shortcut..'##decker_'..title..i;
        local flashing=(state.flashRow==title and state.flashSlot==i and os.clock()<state.flashUntil);
        local executed=state.lastExecuted;
        local remembered=executed and executed.row==title and executed.slot==i
            and executed.set==state.trackedSet and executed.name==name
            and state.trackedSource~='unverified (same names)';
        local selected=(state.navRow==title and state.navSlot==i);
        local themed=type(imgui.PushStyleColor)=='function' and type(imgui.PopStyleColor)=='function'
            and type(ImGuiCol_Button)=='number' and type(ImGuiCol_Text)=='number';
        if themed then
            local base=flashing and {0.64,0.51,0.23,1} or (remembered and {0.49,0.38,0.20,1} or (selected and {0.33,0.34,0.41,1} or theme.color));
            imgui.PushStyleColor(ImGuiCol_Button,base);
            -- Override ImGui's default blue hover/held states while the button is activated.
            -- Hover alone remains subtle; keyboard/mouse activation uses the same amber tone.
            if type(ImGuiCol_ButtonHovered)=='number' and type(ImGuiCol_ButtonActive)=='number' then
                local hover=flashing and {0.77,0.60,0.27,1} or {0.44,0.43,0.52,1};
                local active={0.77,0.60,0.27,1};
                imgui.PushStyleColor(ImGuiCol_ButtonHovered,hover);
                imgui.PushStyleColor(ImGuiCol_ButtonActive,active);
            end
            local binding=state.cooldownBindings[offset+i];
            local cooling=cooldown_recast(binding);
            imgui.PushStyleColor(ImGuiCol_Text,cooling and {1.0,0.25,0.25,1.0} or theme.text);
        end
        local clicked=imgui.Button(label,{w,h});
        if themed then
            imgui.PopStyleColor((type(ImGuiCol_ButtonHovered)=='number' and type(ImGuiCol_ButtonActive)=='number') and 4 or 2);
        end
        if clicked then
            execute_slot(title,i);
        end
    end
end
-- DirectInput scancodes: 1..0 (2..11) and F1..F10 (59..68).
-- Keyboard overrides remain OFF until explicit activation. Native FFXI chat/edit focus
-- cannot yet be identified reliably in VanaCore. Warn in UI before enabling.
local function mapped_key(key)
    if type(key)~='number' then return nil,nil; end
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
local ROW_KEYS={END=207,HOME=199,INSERT=210,DELETE=211,F9=67,F10=68,F11=87,F12=88};
local function row_key() return ROW_KEYS[state.rowSwitchKey] or 207; end
local NAV_ACTIONS={ [200]=true,[208]=true,[203]=true,[205]=true,[57]=true,[28]=true,[156]=true };
local function nav_is_active()
    return state.navKeysEnabled
       and (state.stickyNavigation and state.navToggleActive or
           (not state.stickyNavigation and state.navModifierHeld))
       and not other_modifier_down();
end
local function active_row_slot(key)
    if not state.activeRowKeys or not state.acknowledgeKeys or not state.allowAllClicks or not nav_is_active() then return nil; end
    return (key>=2 and key<=11) and (key==11 and 10 or key-1) or nil;
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
    if not e.data_raw or (type(e.size)=='number' and e.size<209) then return; end
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
ashita.events.register('key_data','decker_exclusive_key_press',function(e)
    local activeSlot=active_row_slot(e.key);
    local row,slot;
    if activeSlot then row,slot=state.navRow or 'CTRL',activeSlot;
    else row,slot=mapped_key(e.key); end
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
    if (not activeSlot and not shortcuts_active()) or e.blocked or modifier_down() then return; end
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
    if not shortcuts_active() and not (state.activeRowKeys and state.acknowledgeKeys and state.allowAllClicks and nav_is_active()) and next(state.suppressed)==nil then return; end
    local ptr=ffi.cast('uint8_t*',e.data_raw);
    local size=type(e.size)=='number' and e.size or 256;
    local keys={};
    for _,code in ipairs(state.directKeys) do if code>0 then keys[code]=true; end end
    if state.activeRowKeys and state.acknowledgeKeys and state.allowAllClicks and nav_is_active() then for code=2,11 do keys[code]=true; end end
    for code,_ in pairs(state.suppressed) do keys[code]=true; end
    for code,_ in pairs(keys) do
        if code<size and (state.suppressed[code] or ((shortcuts_active() and mapped_key(code)~=nil) or active_row_slot(code)~=nil) and not modifier_down()) then ptr[code]=0; end
    end
end);
ashita.events.register('load','decker_load',function() say('Decker v'..addon.version..' loaded',false); end);
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
ashita.events.register('d3d_present','decker_draw',function()
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
    if not state.visible then return; end
    local activeNav=state.navKeysEnabled and (state.stickyNavigation and state.navToggleActive or (not state.stickyNavigation and state.navModifierHeld));
    if activeNav and not state.hudWasActive then state.hudLastActivity=os.clock(); end
    state.hudWasActive=activeNav;
    -- Startup grace allows discovery; afterwards normal auto-hide applies even without clicks.
    -- The configured modifier and /decker show can always reveal the HUD.
    if not state.hudReadySince then state.hudReadySince=os.clock(); end
    local idleHidden=state.autoHide and not state.hudForceReveal and not activeNav and not state.showTests and (os.clock()-state.hudLastActivity)>=state.autoHideDelay and (os.clock()-state.hudReadySince)>=10;
    state.hudForceReveal=false;
    if idleHidden and state.autoHideMode=='hide' then return; end
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
    -- Apply to the HUD only; Settings stays fully opaque.
    local opacityPushed=false;
    if type(imgui.PushStyleVar)=='function' and type(imgui.PopStyleVar)=='function' and ImGuiStyleVar_Alpha then
        imgui.PushStyleVar(ImGuiStyleVar_Alpha,state.hudOpacity); opacityPushed=true;
    end
    if imgui.Begin(('Decker v'..addon.version..' - Book%02d (#%d)%s###DeckerMain'):format(state.manualBook or 1,state.trackedSet or 1,(state.navKeysEnabled and (state.stickyNavigation and (state.navToggleActive and ' [LOCKED]' or ' [UNLOCKED]') or (state.navModifierHeld and ' [HELD]' or ' [RELEASED]')) or '')..(state.trackedSource=='unverified (same names)' and ' [UNVERIFIED]' or '')),nil,0) then
        if #state.names==20 then
            draw_row('CTRL',0);
            draw_row('ALT',10);
            if state.allowSwitch then
                if imgui.Button('<##deckprev') then select_page(((state.trackedSet or 1)+8)%10+1); end
                imgui.SameLine(); imgui.Text(('Set %d/10'):format(state.trackedSet or 1));
                imgui.SameLine(); if imgui.Button('>##decknext') then select_page((state.trackedSet or 1)%10+1); end
                imgui.SameLine();
            end
            if imgui.Button('Settings') then state.showTests=not state.showTests; state.hudLastActivity=os.clock(); end
        else
            imgui.Text('Decker is not connected to native macros.');
            if imgui.Button('Connect macros') then connect_macros(); end
            imgui.SameLine();
            if imgui.Button('Settings') then state.showTests=not state.showTests; state.hudLastActivity=os.clock(); end
            imgui.TextWrapped('Connect invokes native FFXI reading functions. As with earlier builds, incompatible clients may crash.');
            if state.phase~=0 then imgui.TextWrapped(state.nameSummary..' / '..state.pointerSummary); end
        end
        imgui.Text('by Mutant X');
    end
    imgui.End();
    if opacityPushed then imgui.PopStyleVar(); end
    if state.showTests then
        imgui.SetNextWindowSize({490,370},ImGuiCond_FirstUseEver);
        if imgui.Begin('Decker v'..addon.version..' - Settings',nil,0) then
            if imgui.Button('X  Close Settings') then state.showTests=false; end
            imgui.Separator();
            if imgui.CollapsingHeader('Display') then
            if state.allowSwitch then
                imgui.Text('Jump to macro set:');
                for i=1,10 do
                    if i>1 then imgui.SameLine(); end
                    if imgui.Button(tostring(i)..'##settings_set'..i,{30,24}) then select_page(i); end
                end
            end

            local auto={state.autoHide};
            if imgui.Checkbox('Auto-hide macro display',auto) then state.autoHide=auto[1]; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; save_display(); end
            imgui.Text('Hide after inactivity:');
            for _,seconds in ipairs({2,5,10,15,30}) do
                if seconds~=2 then imgui.SameLine(); end
                if imgui.Button((state.autoHideDelay==seconds and '[' or '')..seconds..'s'..(state.autoHideDelay==seconds and ']' or '')..'##hide'..seconds) then state.autoHideDelay=seconds; state.hudLastActivity=os.clock(); state.hudHasInteracted=true; save_display(); end
            end
            if imgui.Button('Hide completely'..(state.autoHideMode=='hide' and ' [selected]' or '')) then state.autoHideMode='hide'; save_display(); end
            imgui.SameLine(); if imgui.Button('Collapse to tab'..(state.autoHideMode=='collapse' and ' [selected]' or '')) then state.autoHideMode='collapse'; save_display(); end
            imgui.TextWrapped('The macro display stays visible while navigation is active. Settings stays visible while open. Keyboard shortcuts keep working when hidden.')
            imgui.Text(('Display opacity: %d%%'):format(math.floor(state.hudOpacity*100+0.5)));
            if imgui.Button('More transparent') then state.hudOpacity=math.max(.2,math.floor(state.hudOpacity*10+0.5)/10-.1); save_display(); end
            imgui.SameLine(); if imgui.Button('Less transparent') then state.hudOpacity=math.min(1,math.floor(state.hudOpacity*10+0.5)/10+.1); save_display(); end
            if imgui.Button('Reset opacity to 100%') then state.hudOpacity=1; save_display(); end
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
            if imgui.CollapsingHeader('Controls') then
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
            imgui.Text('Macro book selector (native GAME book)');
            if imgui.Button('< Previous book') then select_native_book(math.max(1,state.manualBook-1)); end
            imgui.SameLine();
            if imgui.BeginCombo('Book##nativebook',('Book %02d (tracked)'):format(state.manualBook)) then
                for book=1,20 do
                    if imgui.Selectable(('Book %02d##book%d'):format(book,book),state.manualBook==book) then select_native_book(book); end
                end
                imgui.EndCombo();
            end
            imgui.SameLine();
            if imgui.Button('Next book >') then select_native_book(math.min(20,state.manualBook+1)); end
            imgui.TextWrapped('Book numbers are tracked, not read back from the game. Verify the correct macros after switching. Command: /decker switchbook 1-20');
            if imgui.Button('Reset GAME to Book 1 / Set 1 (native call)') then reset_native_book(); end
            imgui.TextWrapped('Reset invokes native game functions. It is not just a label reset; compatibility risks remain.');
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
            imgui.Text('Controls - Direct macro keys')
            imgui.TextWrapped('Active Row Keys: while Decker navigation is active, number keys 1-0 execute the selected row. The Switch Row Key changes which ten macros they run. Disabled by default. These keys may interfere with chat/menu typing; enable only after acknowledging the risk.')
            local ar={state.activeRowKeys};
            if state.acknowledgeKeys and state.allowAllClicks then
                if imgui.Checkbox('Enable Active Row Keys (1-0)',ar) then state.activeRowKeys=ar[1]; state.suppressed={}; state.held={}; save_display(); end
            else
                imgui.TextWrapped('Active Row Keys unavailable until native macros are connected and chat/menu risk is acknowledged below.')
            end
            imgui.TextWrapped('Custom direct macro controls remain OFF by default. Chat and menu safety is unverified under VanaCore.');
            local ack={state.acknowledgeKeys};
            if imgui.Checkbox('I understand the chat/menu risk',ack) then
                state.acknowledgeKeys=ack[1]; state.savedAck=ack[1];
                if not ack[1] then state.keybinds=false; state.savedKeybinds=false; state.activeRowKeys=false; state.held={}; end
                save_display();
            end
            if state.acknowledgeKeys and state.allowAllClicks then
                local enabled={state.keybinds};
                if imgui.Checkbox('Enable experimental keyboard overrides',enabled) then state.keybinds=enabled[1]; state.savedKeybinds=enabled[1]; state.held={}; save_display(); end
            end
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
                state.directKeys=default_direct_keys(); state.held={}; state.suppressed={}; save_display();
            end
            if imgui.Button('Release keyboard overrides') then state.keybinds=false; state.activeRowKeys=false; state.acknowledgeKeys=false; state.savedKeybinds=false; state.savedAck=false; state.held={}; state.suppressed={}; save_display(); end
            imgui.Text('/decker keysoff also disables overrides');
            end
            if imgui.CollapsingHeader('Quick Start Guide') then
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
            if imgui.Button(state.showAdvanced and 'Hide advanced diagnostics' or 'Show advanced diagnostics') then state.showAdvanced=not state.showAdvanced; end
            if state.showAdvanced then
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
            if state.phase>=4 and imgui.Button('Refresh macro names') then state.confirmAll=true; read_all_names(); end
            imgui.Separator(); imgui.Text('Decker v'..addon.version..'  |  by Mutant X')
            if imgui.Button('Close settings') then state.showTests=false; end
        end
        imgui.End();
    end
end);
