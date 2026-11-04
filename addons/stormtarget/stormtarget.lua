-- StormTarget v0.2-dev: opt-in Tab interception, two hotkeys, manual actions only.
-- Experimental Ashita v4 addon. No packet injection, automatic attacks or gear changes.
addon.name='StormTarget';
addon.author='Storm XI';
addon.version='0.2.0-dev';
addon.desc='Opt-in manual monster targeting and nearest-unclaimed selection.';
require('common');
local chat=require('chat');
local ffi=require('ffi');
local bit=require('bit');
local MAX_RANGE=30;
local DIK_TAB=15;
local DIK_GRAVE=41;
local saved, focus, last_zone=nil,nil,nil;
local tab_enabled=false;
local context_enabled=false;
local filter_text=nil;
local tab_captured=false;
local context_captured=false;

local function say(msg) print(chat.header(addon.name)..msg); end
local function managers()
    local memory=AshitaCore:GetMemoryManager();
    return memory:GetEntity(),memory:GetTarget(),memory:GetParty();
end
local function is_busy(target)
    local ch=AshitaCore:GetChatManager();
    if not ch or ch:IsInputOpen()~=0 then return true; end
    return target:GetIsSubTargetActive()~=0 or target:GetIsMenuOpen()~=0
        or target:GetActionTargetActive()~=0;
end
local function zone_guard(party)
    -- A job/zone transition invalidates stale index/server-ID pairs.
    local zone=party:GetMemberZone(0);
    if zone and last_zone and zone~=last_zone then
        saved=nil; focus=nil;
    end
    last_zone=zone;
end
local function alive_monster(entity,i)
    if not i or i<=0 then return false; end
    local id=entity:GetServerId(i);
    if not id or id==0 then return false; end
    local flags=entity:GetSpawnFlags(i) or 0;
    if bit.band(flags,0x10)==0 then return false; end
    if (entity:GetHPPercent(i) or 0)<=0 then return false; end
    local actor=entity:GetActorPointer(i);
    if not actor or actor==0 then return false; end
    if filter_text then
        local name=entity:GetName(i) or '';
        if not string.find(string.lower(name),filter_text,1,true) then return false; end
    end
    return true;
end
local function dist(entity,me,i)
    local dx=entity:GetLocalPositionX(me)-entity:GetLocalPositionX(i);
    local dy=entity:GetLocalPositionY(me)-entity:GetLocalPositionY(i);
    local dz=entity:GetLocalPositionZ(me)-entity:GetLocalPositionZ(i);
    return math.sqrt(dx*dx+dy*dy+dz*dz);
end
local function candidates(entity,party,only_unclaimed)
    local me=party:GetMemberTargetIndex(0);
    if not me or me<=0 or entity:GetServerId(me)==0 then return nil,'Player entity unavailable'; end
    local size=entity:GetEntityMapSize();
    if not size or size<1 then return nil,'Entity map unavailable'; end
    local list={};
    for i=1,math.min(size-1,2303) do
        if alive_monster(entity,i) then
            local claim=bit.band(entity:GetClaimStatus(i) or 0,0xFFFF);
            if not only_unclaimed or claim==0 then
                local d=dist(entity,me,i);
                if d<=MAX_RANGE then
                    list[#list+1]={index=i,id=entity:GetServerId(i),distance=d};
                end
            end
        end
    end
    table.sort(list,function(a,b)
        if a.distance==b.distance then return a.index<b.index; end
        return a.distance<b.distance;
    end);
    return list;
end
local function current_identity(entity,target)
    local index=target:GetTargetIndex(0);
    if index and index>0 then
        local id=entity:GetServerId(index);
        if id and id~=0 then return {index=index,id=id}; end
    end
    return nil;
end
local function still_valid(entity,identity)
    return identity and entity:GetServerId(identity.index)==identity.id;
end
local function set_selected(entity,target,choice,quiet)
    if not still_valid(entity,choice) then return false,'Candidate despawned'; end
    local old=current_identity(entity,target);
    if old and old.index~=choice.index then saved=old; end
    target:SetTarget(choice.index,false);
    if not quiet then
        say(('Selected %s (%.1f yalms)'):format(entity:GetName(choice.index) or '?',choice.distance or 0));
    end
    return true;
end
local function select_mode(mode,quiet)
    local entity,target,party=managers();
    zone_guard(party);
    if is_busy(target) then return false,'Chat, menu or subtarget active'; end
    if mode=='back' or mode=='focusback' then
        local choice=mode=='back' and saved or focus;
        if not still_valid(entity,choice) then return false,'Saved target no longer available'; end
        local old=current_identity(entity,target);
        target:SetTarget(choice.index,false);
        if mode=='back' then saved=old; end
        if not quiet then say('Selected saved target'); end
        return true;
    end
    if mode=='focus' then
        focus=current_identity(entity,target);
        if not focus then return false,'Target a monster before storing focus'; end
        if not quiet then say('Focus stored: '..(entity:GetName(focus.index) or '?')); end
        return true;
    end
    local list,err=candidates(entity,party,mode=='claim');
    if not list then return false,err; end
    if #list==0 then return false,'No eligible monsters found'; end
    local index=1;
    local now=target:GetTargetIndex(0);
    local position=nil;
    for k,v in ipairs(list) do if v.index==now then position=k; break; end end
    if mode=='next' then index=position and (position%#list+1) or 1;
    elseif mode=='prev' then index=position and ((position-2)%#list+1) or #list; end
    return set_selected(entity,target,list[index],quiet);
end
local function can_capture()
    local ok,ready=pcall(function()
        local entity,target,party=managers();
        zone_guard(party);
        return not is_busy(target) and party:GetMemberTargetIndex(0)>0;
    end);
    return ok and ready;
end
local function safe_run(mode)
    local ok,success,err=pcall(select_mode,mode,true);
    if not ok then say('Target API error: '..tostring(success)); return false; end
    if not success then say(err or 'Selection unavailable'); return false; end
    return true;
end
local function no_modifier(held)
    -- Ctrl, Alt, either Shift and Windows keys must preserve their own shortcuts.
    for _,key in ipairs({29,157,56,184,42,54,219,220}) do
        if held[key] then return false; end
    end
    return true;
end
local held={};
-- Initial key events and held-state handling are distinct in Ashita v4.
-- This is explicitly opt-in and is never active in chat, menus or subtargets.
ashita.events.register('key_data','stormtarget_hotkeys',function(e)
    if e.key==29 or e.key==157 or e.key==56 or e.key==184
        or e.key==42 or e.key==54 or e.key==219 or e.key==220 then
        held[e.key]=e.down and true or nil;
        return;
    end
    local is_tab=e.key==DIK_TAB and tab_enabled;
    local is_context=e.key==DIK_GRAVE and context_enabled;
    if not is_tab and not is_context then return; end
    if not e.down then
        if e.key==DIK_TAB then tab_captured=false; else context_captured=false; end
        return;
    end
    if e.blocked or not no_modifier(held) or not can_capture() then return; end
    -- Fail open: if no usable candidate exists, leave the native key untouched.
    -- Do not steal normal Tab/confirm behavior when target selection is unavailable.
    if is_tab and not tab_captured then
        local ok= safe_run('next');
        if ok then e.blocked=true; tab_captured=true; end
    elseif is_context and not context_captured then
        local ok= safe_run('claim');
        if ok then e.blocked=true; context_captured=true; end
    elseif (is_tab and tab_captured) or (is_context and context_captured) then
        e.blocked=true;
    end
end);
ashita.events.register('key_state','stormtarget_held_suppression',function(e)
    if not e.data_raw or (type(e.size)=='number' and e.size<256) then return; end
    local keys=ffi.cast('uint8_t*',e.data_raw);
    if tab_captured then
        if keys[DIK_TAB]==0 then tab_captured=false;
        elseif tab_enabled and can_capture() then keys[DIK_TAB]=0; end
    end
    if context_captured then
        if keys[DIK_GRAVE]==0 then context_captured=false;
        elseif context_enabled and can_capture() then keys[DIK_GRAVE]=0; end
    end
end);
ashita.events.register('command','stormtarget_cmd',function(e)
    local a=e.command:args();
    if not a[1] or a[1]:lower()~='/stormtarget' then return; end
    e.blocked=true;
    local cmd=(a[2] or 'help'):lower();
    if cmd=='tab' or cmd=='context' then
        local enabled=(a[3] or ''):lower();
        if enabled~='on' and enabled~='off' then
            say('Usage: /stormtarget '..cmd..' on|off'); return;
        end
        if cmd=='tab' then tab_enabled=enabled=='on'; tab_captured=false;
        else context_enabled=enabled=='on'; context_captured=false; end
        say(cmd..' interception '..enabled..' (session only)');
    elseif cmd=='filter' then
        local value=(a[3] or ''):lower();
        filter_text=(value~='' and value~='off') and value or nil;
        say(filter_text and ('Monster name filter: '..filter_text) or 'Name filter cleared');
    elseif cmd=='status' then
        say('Tab='..tostring(tab_enabled)..'; grave='..tostring(context_enabled)..
            '; filter='..(filter_text or 'off')..'; no auto-attack/rescue');
    elseif cmd=='nearest' or cmd=='next' or cmd=='prev' or cmd=='claim'
        or cmd=='back' or cmd=='focus' or cmd=='focusback' then
        local ok,result,err=pcall(select_mode,cmd,false);
        if not ok then say('Target API error: '..tostring(result));
        elseif not result then say(err or 'No target found'); end
    else
        say('/stormtarget tab on|off ; context on|off ; status');
        say('/stormtarget next|prev|nearest|claim|back|focus|focusback');
        say('/stormtarget filter NAME|off (single word, case-insensitive)');
    end
end);
ashita.events.register('unload','stormtarget_unload',function()
    tab_enabled=false; context_enabled=false;
    saved=nil; focus=nil;
end);
