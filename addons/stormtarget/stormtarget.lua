-- StormTarget v0.1: manual-only Ashita v4 targeting prototype.
-- Does not intercept keyboard events, cast, attack or change gear.
addon.name='StormTarget';
addon.author='Storm XI';
addon.version='0.1.0-dev';
addon.desc='Manual monster target selection; unverified live client behavior.';
require('common');
local chat=require('chat');
local saved=nil;
local MAX_RANGE=30;

local function say(msg) print(chat.header(addon.name)..msg); end
local function getmanagers()
    local m=AshitaCore:GetMemoryManager();
    return m:GetEntity(),m:GetTarget(),m:GetParty();
end
local function blocked(target)
    return target:GetIsSubTargetActive()~=0 or target:GetIsMenuOpen()~=0;
end
local function valid(entity,index)
    if not index or index<=0 then return false; end
    local id=entity:GetServerId(index);
    if not id or id==0 then return false; end
    local flags=entity:GetSpawnFlags(index) or 0;
    if flags%4<2 then return false; end -- NPC/monster; may include friendly NPCs.
    if not entity:GetActorPointer(index) or entity:GetActorPointer(index)==0 then return false; end
    return (entity:GetHPPercent(index) or 0)>0;
end
local function range(entity,me,index)
    local x=entity:GetLocalPositionX(me)-entity:GetLocalPositionX(index);
    local y=entity:GetLocalPositionY(me)-entity:GetLocalPositionY(index);
    local z=entity:GetLocalPositionZ(me)-entity:GetLocalPositionZ(index);
    return math.sqrt(x*x+y*y+z*z);
end
local function getcandidates(entity,party,claimonly)
    local me=party:GetMemberTargetIndex(0);
    if not valid(entity,me) and (not me or me<=0 or entity:GetServerId(me)==0) then return nil,'Player entity unavailable'; end
    local size=entity:GetEntityMapSize();
    if not size or size<1 then return nil,'Entity map unavailable'; end
    local list={};
    for i=1,math.min(size-1,2303) do
        if valid(entity,i) then
            local d=range(entity,me,i);
            local claim=(entity:GetClaimStatus(i) or 0)%65536;
            if d<=MAX_RANGE and (not claimonly or claim==0) then
                list[#list+1]={index=i,id=entity:GetServerId(i),distance=d};
            end
        end
    end
    table.sort(list,function(a,b)
        return a.distance==b.distance and a.index<b.index or a.distance<b.distance;
    end);
    return list;
end
local function select(entity,target,choice)
    if blocked(target) then say('Subtarget or menu active; cancelled.'); return; end
    if entity:GetServerId(choice.index)~=choice.id then say('Target changed; retry.'); return; end
    local old=target:GetTargetIndex(0);
    if old and old>0 and old~=choice.index and entity:GetServerId(old)~=0 then
        saved={index=old,id=entity:GetServerId(old)};
    end
    target:SetTarget(choice.index,false);
    say(('Selected %s (%.1f yalms).'):format(entity:GetName(choice.index) or '?',choice.distance or 0));
end
local function perform(mode)
    local entity,target,party=getmanagers();
    if blocked(target) then say('Complete or cancel native target selection first.'); return; end
    if mode=='back' then
        if not saved or entity:GetServerId(saved.index)~=saved.id then
            say('Previous target unavailable.'); return;
        end
        local old=target:GetTargetIndex(0);
        local restore=saved;
        target:SetTarget(restore.index,false);
        saved=(old and old>0 and entity:GetServerId(old)~=0) and {index=old,id=entity:GetServerId(old)} or nil;
        say('Restored '..(entity:GetName(restore.index) or '?'));
        return;
    end
    local list,err=getcandidates(entity,party,mode=='claim');
    if not list then say(err); return; end
    if #list==0 then say('No eligible loaded targets within 30 yalms.'); return; end
    local pos=nil;
    local old=target:GetTargetIndex(0);
    for k,item in ipairs(list) do if item.index==old then pos=k; break; end end
    local nextidx=1;
    if mode=='next' then nextidx=pos and (pos%#list+1) or 1; end
    if mode=='prev' then nextidx=pos and ((pos-2)%#list+1) or #list; end
    select(entity,target,list[nextidx]);
end
ashita.events.register('command','stormtarget_cmd',function(e)
    local a=e.command:args();
    if not a[1] or a[1]:lower()~='/stormtarget' then return; end
    e.blocked=true;
    local mode=(a[2] or 'help'):lower();
    if mode=='nearest' or mode=='claim' or mode=='next' or mode=='prev' or mode=='back' then
        local ok,err=pcall(perform,mode);
        if not ok then say('Targeting API failure: '..tostring(err)); end
    else
        say('/stormtarget nearest | claim | next | prev | back');
        say('Manual selection only; no combat actions or keyboard capture.');
    end
end);
ashita.events.register('unload','stormtarget_unload',function() saved=nil; end);
