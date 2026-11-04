-- StormTarget v0.4-dev: opt-in configurable selection/engage, focus recall and temporary return.
-- Experimental Ashita v4 addon. No packet injection, automatic attacks or gear changes.
addon.name='StormTarget';
addon.author='Storm XI';
addon.version='0.4.0-dev';
addon.desc='Opt-in two-key monster targeting, native engage, focus and temporary return.';
require('common');
local chat=require('chat');
local ffi=require('ffi');
local bit=require('bit');
local MAX_RANGE=30;
local KEYS={TAB=15,GRAVE=41,ENTER=28,F11=87,F12=88,HOME=199,ENDKEY=207,INSERT=210,DELETE=211,PAGEUP=201,PAGEDOWN=209,Q=16,E=18,R=19,T=20,G=34,V=47,B=48,N=49,M=50};
local hotkey={cycle=15,context=41};
local key_name={cycle='TAB',context='GRAVE'};
local context_mode='engage'; -- engage, resume, claim, focusback, return
local last_selected,last_engage=nil,nil;
local temporary_origin=nil; -- Captured at start of a selection excursion; not an action observer.
local captured={};
local saved, focus, last_zone=nil,nil,nil;
local tab_enabled=false;
local context_enabled=false;
local filter_text=nil;
local filter_exact=false;


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
        saved=nil; focus=nil; last_selected=nil; last_engage=nil; temporary_origin=nil;
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
        local lowered=string.lower(name);
        if filter_exact then
            if lowered~=filter_text then return false; end
        elseif not string.find(lowered,filter_text,1,true) then return false; end
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
    return identity and identity.index and identity.index>0 and entity:GetServerId(identity.index)==identity.id;
end
local function set_selected(entity,target,choice,quiet)
    if not still_valid(entity,choice) then return false,'Candidate despawned'; end
    local old=current_identity(entity,target);
    if old and old.index~=choice.index then
        saved=old;
        -- Anchor the original selection only once, so cycling among adds doesn't
        -- continually replace the target to which a user can return.
        if not temporary_origin then temporary_origin={index=old.index,id=old.id}; end
    end
    target:SetTarget(choice.index,false);
    last_selected={index=choice.index,id=choice.id};
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
        if mode=='focusback' then temporary_origin=nil; end
        last_selected={index=choice.index,id=choice.id};
        if not quiet then say('Selected saved target'); end
        return true;
    end
    if mode=='return' then
        local choice=temporary_origin;
        if not still_valid(entity,choice) then
            temporary_origin=nil;
            return false,'No valid temporary-target origin';
        end
        -- Return is selection only: never attack, never infer successful spell.
        target:SetTarget(choice.index,false);
        last_selected={index=choice.index,id=choice.id};
        temporary_origin=nil;
        if not quiet then say('Returned to original selected target (no engage)'); end
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
-- Engagement must be explicitly requested by the user, never inferred from Sleep, Flash or selection.
-- The command queue means request accepted, not that the server confirmed the switch.
local function engage_identity(identity,quiet)
    local entity,target,party=managers();
    zone_guard(party);
    if is_busy(target) then return false,'Chat/menu/subtarget active'; end
    local selected=identity or current_identity(entity,target);
    if not still_valid(entity,selected) or not alive_monster(entity,selected.index) then
        return false,'No live monster to engage';
    end
    local current=current_identity(entity,target);
    if not current or current.id~=selected.id then
        local ok,err=set_selected(entity,target,selected,true);
        if not ok then return false,err; end
    end
    local result=AshitaCore:GetChatManager():QueueCommand(-1,'/attack on');
    if result==false then return false,'Game command queue rejected /attack on'; end
    last_engage={index=selected.index,id=selected.id};
    if not quiet then say('Requested engage; verify battle-target switch in game'); end
    return true;
end
local function context_action(mode,quiet)
    if mode=='claim' then return select_mode('claim',quiet); end
    if mode=='focusback' or mode=='return' then return select_mode(mode,quiet); end
    if mode=='engage' then return engage_identity(nil,quiet); end
    local entity,target,party=managers();
    zone_guard(party);
    if is_busy(target) then return false,'Chat/menu/subtarget active'; end
    if last_engage and still_valid(entity,last_engage) and alive_monster(entity,last_engage.index) then
        return engage_identity(last_engage,quiet);
    end
    if last_selected and still_valid(entity,last_selected) and alive_monster(entity,last_selected.index) then
        return set_selected(entity,target,last_selected,quiet);
    end
    return false,'No remembered live enemy';
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
    local fn=(mode=='resume' or mode=='engage' or mode=='focusback' or mode=='return') and context_action or select_mode;
    local ok,success,err=pcall(fn,mode,true);
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
local function role_for_key(key)
    if tab_enabled and key==hotkey.cycle then return 'cycle'; end
    if context_enabled and key==hotkey.context then return 'context'; end
    return nil;
end
ashita.events.register('key_data','stormtarget_hotkeys',function(e)
    if e.key==29 or e.key==157 or e.key==56 or e.key==184
        or e.key==42 or e.key==54 or e.key==219 or e.key==220 then
        held[e.key]=e.down and true or nil; return;
    end
    if not e.down then captured[e.key]=nil; return; end
    local role=role_for_key(e.key);
    if not role then return; end
    if captured[e.key] then e.blocked=true; return; end
    if e.blocked or not no_modifier(held) or not can_capture() then return; end
    -- Fail open to native input if no eligible target or selection failed.
    if safe_run(role=='cycle' and 'next' or context_mode) then
        captured[e.key]=true; e.blocked=true;
    end
end);
ashita.events.register('key_state','stormtarget_held_suppression',function(e)
    if not e.data_raw or (type(e.size)=='number' and e.size<256) then return; end
    local keys=ffi.cast('uint8_t*',e.data_raw);
    for role,key in pairs(hotkey) do
        if captured[key] then
            if keys[key]==0 then captured[key]=nil;
            elseif (role=='cycle' and tab_enabled or role=='context' and context_enabled)
                and can_capture() then keys[key]=0; end
        end
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
        if cmd=='tab' then tab_enabled=enabled=='on'; captured[hotkey.cycle]=nil;
        else context_enabled=enabled=='on'; captured[hotkey.context]=nil; end
        say(cmd..' interception '..enabled..' (session only)');
    elseif cmd=='bind' then
        local role=(a[3] or ''):lower();
        local name=(a[4] or ''):upper();
        local key=KEYS[name];
        if role~='cycle' and role~='context' then say('Use: /stormtarget bind cycle|context KEY'); return; end
        if not key then say('Keys: TAB GRAVE ENTER F11 F12 HOME ENDKEY INSERT DELETE PAGEUP PAGEDOWN Q E R T G V B N M'); return; end
        local other=role=='cycle' and 'context' or 'cycle';
        if hotkey[other]==key then say('Already assigned to '..other); return; end
        captured[hotkey[role]]=nil; hotkey[role]=key; key_name[role]=name;
        say('Assigned '..name..' to '..role..' (session only)');
    elseif cmd=='mode' then
        local mode=(a[3] or ''):lower();
        if mode~='resume' and mode~='claim' and mode~='engage' and mode~='focusback' and mode~='return' then
            say('Modes: engage | resume | claim | focusback | return'); return;
        end
        context_mode=mode; say('Context action is '..mode);
    elseif cmd=='filter' or cmd=='exact' then
        local value=(a[3] or ''):lower();
        filter_text=(value~='' and value~='off') and value or nil;
        filter_exact=cmd=='exact' and filter_text~=nil;
        say(filter_text and ('Monster '..(filter_exact and 'exact-name' or 'substring')..' filter: '..filter_text)
            or 'Name filter cleared');
    elseif cmd=='status' then
        say('Cycle '..key_name.cycle..'='..tostring(tab_enabled)
            ..', context '..key_name.context..'='..tostring(context_enabled)
            ..' ('..context_mode..'), filter='..(filter_text or 'off')
            ..', remembered engage='..tostring(last_engage~=nil));
    elseif cmd=='nearest' or cmd=='next' or cmd=='prev' or cmd=='claim'
        or cmd=='back' or cmd=='focus' or cmd=='focusback'
        or cmd=='engage' or cmd=='resume' or cmd=='return' then
        local fn=(cmd=='engage' or cmd=='resume' or cmd=='return') and context_action or select_mode;
        local ok,result,err=pcall(fn,cmd,false);
        if not ok then say('Target API error: '..tostring(result));
        elseif not result then say(err or 'No target found'); end
    else
        say('/stormtarget tab on|off ; context on|off ; status');
        say('/stormtarget bind cycle|context KEY ; mode engage|resume|claim|focusback|return');
        say('/stormtarget next|prev|nearest|claim|back|focus|focusback|return|engage|resume');
        say('/stormtarget exact NAME|off or filter NAME|off (single word, case-insensitive)');
    end
end);
ashita.events.register('unload','stormtarget_unload',function()
    tab_enabled=false; context_enabled=false;
    saved=nil; focus=nil; last_selected=nil; last_engage=nil; temporary_origin=nil; captured={};
end);
