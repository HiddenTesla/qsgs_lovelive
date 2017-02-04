-- Qsanguosha extension package: LoveLove!
-- Skill designer:  醉花夢月 (from Baidu Tieba)
-- Code developer:  Erwin (chen90071@163.com, chen9007@gmail.com)
-- Text editor:     Notepad++, because vim does not support Lua nor Chinese well
-- This file is open source and freely distributable
 
module("extensions.lovelive", package.seeall)
extension = sgs.Package("lovelive")

maki = sgs.General(extension, 
                   "maki", -- name of the general
                   "wei",  -- kingdom
                   3,      -- maxhp
                   false  -- gender
                   )
                   
nico = sgs.General(extension, 
                   "nico", -- name of the general
                   "shu",  -- kingdom
                   3,      -- maxhp
                   false  -- gender
                   )
				   
umi = sgs.General(extension, "umi", "wei", "3", false)


function findMaxHandcardNum(room)
    local max_ = 0
    for _, p in sgs.qlist(room:getAllPlayers() ) do
        local cur = p:getHandcardNum()
        if cur > max_ then
            max_ = cur
        end
    end
    return max_
end

qianjin = sgs.CreateTriggerSkill
{
    name = "qianjin",
    events = {sgs.EventPhaseStart},
    frequency = sgs.Skill_Frequent,
    on_trigger = function(self, event, player, data)
        local room = player:getRoom()
        local phase = player:getPhase()
        if phase == sgs.Player_Start or phase == sgs.Player_Finish then
            if not room:askForSkillInvoke(player, self:objectName(), data) then
                return false
            end
            local max_ = findMaxHandcardNum(room)
            local diff = max_ - player:getHandcardNum()
            if diff < 1 then
                diff = 1
            end
            player:drawCards(diff)
        end
    end
}

bieniu = sgs.CreateTriggerSkill 
{
    name = "bieniu",
    events = {sgs.CardUsed},
    frequency = sgs.Skill_Compulsory,

    on_trigger = function(self, event, player, data)
        local room = player:getRoom()
        local card = data:toCardUse().card
        -- Need a judgement, otherwise you will be set limit when using a peach
        -- outside your turn
        if (player:getPhase() ~= sgs.Player_Play) 
            or (player:getPhase() == sgs.Player_NotActive)then
            return false
        end
        
        -- if setPlayerCardLimitation uses "true" as the 4th argument,
        -- then you should add "$1" when removePlayerCardLimitation
        -- if not, use "$0"
        -- without these, you will not be able to correctly unlock it!
        if card:isRed() then
            room:setPlayerCardLimitation(player, "use", ".|red|.", true)
            room:removePlayerCardLimitation(player, "use", ".|black|.$1")
        else
            room:setPlayerCardLimitation(player, "use", ".|black|.", true)
            room:removePlayerCardLimitation(player, "use", ".|red|.$1")
        end
    end
}

function suitToInt(suit)
    if suit == sgs.Card_Club then
        return 1
    elseif suit == sgs.Card_Diamond then
        return 2
    elseif suit == sgs.Card_Heart then
        return 3
    elseif suit == sgs.Card_Spade then
        return 4
    else
        return -1
    end
end

function isOfDifferentSuits(card_ids)
    local suitTable = {}
    for _, card_id in sgs.qlist(card_ids) do
        local card = sgs.Sanguosha:getCard(card_id)
        local suitId = suitToInt(card:getSuit())
        
        if suitTable[suitId] == nil then
            suitTable[suitId] = 1
        else
            return false
        end        
    end
    return true
end

function isOfSameColor(card_ids)
    if card_ids:length() <= 1 then
        return true
    end
    
    local firstCardRed = nil
    for _, card_id in sgs.qlist(card_ids) do

        local card = sgs.Sanguosha:getCard(card_id)
        if firstCardRed == nil then -- this is the 1st card traversed
            firstCardRed = card:isRed()
        else
            if card:isRed() ~= firstCardRed then
                return false
            end
        end
    end
    return true    
end

puzou = sgs.CreateTriggerSkill
{
	name = "puzou",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.CardsMoveOneTime, sgs.EventPhaseStart, sgs.EventPhaseEnd, sgs.Death },
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local maki = room:findPlayerBySkillName(self:objectName())
		local current = room:getCurrent()
        
        if event == sgs.Death then
            local death = data:toDeath()
            if death.who:objectName() == maki:objectName() then
                room:removeTag("puzou_toDiscard")
            end
        elseif event == sgs.EventPhaseStart then
            local phase = player:getPhase()
            if phase == sgs.Player_RoundStart then
                local toDiscard = ""
                room:setTag("puzou_toDiscard", sgs.QVariant(toDiscard))
            elseif phase == sgs.Player_NotActive then
                local toDiscard = room:getTag("puzou_toDiscard")
                room:removeTag("puzou_toDiscard")
            end
        elseif event == sgs.EventPhaseEnd then
            if player:getPhase() == sgs.Player_Discard then
                local toDiscard = ""
                local tag = room:getTag("puzou_toDiscard")
                if tag then
                    toDiscard = tag:toString()
                end
                if toDiscard == "" then return false end

                local cardTable = toDiscard:split("+")
                if #cardTable < 3 then return false end

                local card_ids = sgs.IntList()
                for i = 1, #cardTable, 1 do
                    local cardData = cardTable[i]
                    if cardData == nil or cardData == "" then break end
                    local cardId = tonumber(cardData)
                    card_ids:append(cardId)
                end

                if not isOfSameColor(card_ids) and not isOfDifferentSuits(card_ids) then
                    return false
                end
            
                local choices = {"puzou_lose+puzou_renerate+cancel"}
                local result = room:askForChoice(maki, self:objectName(), table.concat(choices, "+"))
                local all_players = room:getAllPlayers()
                if result == "cancel" then
                    return false
                elseif result == "puzou_lose" then
                    for _, target in sgs.qlist(all_players) do
                        room:loseHp(target, 1)
                    end
                    return true
                elseif result == "puzou_renerate" then
                    for _, target in sgs.qlist(all_players) do
                        room:recover(target, sgs.RecoverStruct(maki))
                    end
                    return true
                end
                return false
            end
        elseif event == sgs.CardsMoveOneTime then
            local move = data:toMoveOneTime()
            local source = move.from
            if not source or source:objectName() ~= player:objectName() then 
                return false
            end        
            if  move.to_place ~= sgs.Player_DiscardPile then
                return false
            end
            for _, id in sgs.qlist(move.card_ids) do
                local oldList = room:getTag("puzou_toDiscard"):toString()
                if not oldList then return false end
                if oldList == "" then
                    newList = tostring(id)
                else
                    newList = oldList .. "+" .. tostring(id)
                end
                room:setTag("puzou_toDiscard", sgs.QVariant(newList))
            end
        end
		
	end,
	can_trigger = function(self, target)
		return target
	end
}

chengneng = sgs.CreateTriggerSkill 
{
    name = "chengneng",
    events = {sgs.EventPhaseStart, sgs.EventPhaseEnd, sgs.GameStart},
    frequency = sgs.Skill_Compulsory,

    on_trigger = function(self, event, player, data)
        local room = player:getRoom()
        local _CHENGNENG_FRONT = 1
        local _CHENGNENG_BACK = 0
        -- Marks need additional files in "image" direction, so I use tag instead
        -- XXX: Limitation: Unexpected bahavior if multiple players have this skill
        if event == sgs.GameStart then
            room:setTag("chengneng_status", sgs.QVariant(_CHENGNENG_FRONT))
        end
        
        if event == sgs.EventPhaseEnd then
            if player:getPhase() == sgs.Player_Play then
                local chengneng_status = 
                    room:getTag("chengneng_status"):toInt()
                if chengneng_status == _CHENGNENG_BACK then
                    room:setTag("chengneng_status", sgs.QVariant(_CHENGNENG_FRONT))
                else
                    room:setTag("chengneng_status", sgs.QVariant(_CHENGNENG_BACK))
                end
            end
        end
        
        if event == sgs.EventPhaseStart then
            if player:getPhase() == sgs.Player_Play then
                local msg = sgs.LogMessage()
                msg.type = "#chengneng_ban"
                msg.from = player
                local chengneng_status = 
                    room:getTag("chengneng_status"):toInt()
                if chengneng_status == _CHENGNENG_BACK then
                    room:setPlayerCardLimitation(player, "use", ".|black|.", true)
                    room:removePlayerCardLimitation(player, "use", ".|red|.$1")
                    msg.arg = "black"
                else
                    room:setPlayerCardLimitation(player, "use", ".|red|.", true)
                    room:removePlayerCardLimitation(player, "use", ".|black|.$1")
                    msg.arg = "red"
                end
                room:sendLog(msg)
            end
        end

    end
}

xianxu = sgs.CreateTriggerSkill 
{
    name = "xianxu",
    events = {sgs.EventPhaseEnd, sgs.CardsMoveOneTime},
    frequency = sgs.Skill_Compulsory,

    on_trigger = function(self, event, player, data)
        local room = player:getRoom()
        
        -- Use pile to implement "获得弃牌阶段弃置的牌"
        -- XXX: May conflict with 固政 and/or 落英 and/or other skills!
        -- Perhaps Room:setTag(...) is a better solution?
        if event == sgs.CardsMoveOneTime then
         local move = data:toMoveOneTime()
                local source = move.from
                if not source or player:getPhase() ~= sgs.Player_Discard then 
                    return false
                end
                if (bit32.band(move.reason.m_reason, sgs.CardMoveReason_S_MASK_BASIC_REASON) 
                                ~= sgs.CardMoveReason_S_REASON_DISCARD) then
                    return false
                end

                player:addToPile("xianxu_discarded", move.card_ids)

        elseif event == sgs.EventPhaseEnd then
            if player:getPhase() == sgs.Player_Discard then
                -- These verbose statements serve to find the times that you can trigger this skill
                local ntimes = 0
                local maxHandcardNum = 0
                local maxHp = 0
                local maxEquipNum = 0
                local maxAttackRange = 0
                for _, p in sgs.qlist(room:getOtherPlayers(player)) do
                    if p:getHandcardNum() > maxHandcardNum then
                        maxHandcardNum = p:getHandcardNum()
                    end
                    if p:getHp() > maxHp then
                        maxHp = p:getHp()
                    end
                    if p:getEquips():length() > maxEquipNum then
                        maxEquipNum = p:getEquips():length()
                    end
                    if p:getAttackRange() > maxAttackRange then
                        maxAttackRange = p:getAttackRange()                        
                    end
                end
                if player:getHandcardNum() < maxHandcardNum then
                    ntimes = ntimes + 1
                end
                if player:getHp() < maxHp then
                    ntimes = ntimes + 1
                end
                if player:getEquips():length() < maxEquipNum then
                    ntimes = ntimes + 1
                end
                if player:getAttackRange() < maxAttackRange then
                    ntimes = ntimes + 1
                end
                -- We have found out the times of triggering
                
                local discardedPile = player:getPile("xianxu_discarded")
                for i = 1, ntimes do
                    local result
                    if discardedPile:length() > 0 then
                        local choices = {"xianxu_draw+xianxu_obtain"}
                        result = room:askForChoice(player, self:objectName(), table.concat(choices, "+"))
                    else
                        result = "xianxu_draw"
                    end
                    
                    if result == "xianxu_draw" then
                        player:drawCards(1)
                    elseif result == "xianxu_obtain" then
                        room:fillAG(discardedPile, player)
                        local cardId = room:askForAG(player, discardedPile, false, --[[ not refusable ]] 
                            self:objectName() )
                        room:obtainCard(player, cardId, true)
                        discardedPile:removeOne(cardId)
                        room:clearAG()
                    end
                end                

                local reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_REMOVE_FROM_PILE, "", "xianxu", "")
                for _, cardId in sgs.qlist(discardedPile) do
                    room:throwCard(sgs.Sanguosha:getCard(cardId), reason, nil)
                    --I don't know why below does not work, so I use the above complicated one
                    --room:throwCard(cardId, player)
                end
            end
        end

    end
}

zhinian = sgs.CreateTriggerSkill 
{
    name = "zhinian",
    events = {sgs.EventPhaseChanging, sgs.PreHpLost, sgs.PreHpRecover, sgs.DamageInflicted },
    frequency = sgs.Skill_NotFrequent,

    on_trigger = function(self, event, player, data)
        local room = player:getRoom()
        local nico = room:findPlayerBySkillName(self:objectName())        
        if event == sgs.PreHpLost or event == sgs.PreHpRecover or event == sgs.DamageInflicted then
            if nico:objectName() ~= player:objectName() then
                return false
            end

            -- Now we can use "nico" and "player" interchangeably, only within this if branch
            if not room:askForSkillInvoke(player, self:objectName(), data) then
                return false
            end            
            local current = room:getCurrent()
            if current:objectName() == player:objectName() then
                -- Uncomment below if you don't want it to trigger when current player is nico itself
                -- return false
            end
            local _ZHINIAN_DRAW  = 1
            local _ZHINIAN_THROW = 2            
            local myThrow  = room:askForCard(player,  ".|black|.", "zhinian_throw_prompt", data, sgs.Card_MethodNone)
            local myChoice  = _ZHINIAN_DRAW                
            local hisThrow = room:askForCard(current, ".|black|.", "zhinian_throw_prompt", data, sgs.Card_MethodNone) 
            local hisChoice = _ZHINIAN_DRAW
            if myThrow == nil then
                player:drawCards(1)
            else
                room:throwCard(myThrow, player)
                myChoice = _ZHINIAN_THROW
            end                    
            if hisThrow == nil then
                current:drawCards(1)
            else
                room:throwCard(hisThrow, current)
                hisChoice = _ZHINIAN_THROW
            end            
            if myChoice ~= hisChoice then
                print("What a pity! We've made different choices!")
                return false
            end
            
            print("Good! We made the same choice")
            
            local tag = room:getTag("zhinian_extra_count")
            local count = tag:toInt()           
            if tag == nil or count <= 0 then
                room:setTag("zhinian_extra_count", sgs.QVariant(1))
            else
                room:setTag("zhinian_extra_count", sgs.QVariant(count + 1))            
            end

            room:setPlayerFlag(current, "zhinian_donar")
            room:setPlayerFlag(player, "zhinian_acceptor")
            return true            

        elseif event == sgs.EventPhaseChanging then 
            -- if not room:getTag("zhinian_extra") then
            local zhinian_extra = room:getTag("zhinian_extra")
            if zhinian_extra:toInt() == 0 then
                --print("This is a regular turn")
                if data:toPhaseChange().to ~= sgs.Player_NotActive or 
                    not player:hasFlag("zhinian_donar") then
                    return false
                end
                local nico = room:findPlayerBySkillName(self:objectName())
                if nico == nil or not nico:hasFlag("zhinian_acceptor") then
                    return false
                end
                local nExtras = room:getTag("zhinian_extra_count"):toInt()                
                if nExtras <= 0 then return false end               
                
                -- Cannot simply gain another phase of play
                -- Instead, gain an extra turn and skip all phases except play           
                while nExtras > 0 do
                    print("Nico has ", nExtras, " extra phases left")
                    local msg = sgs.LogMessage()
                    msg.type = "#zhinian_play"
                    msg.from = player
                    msg.arg = nExtras
                    room:sendLog(msg)
                    local choice = room:askForChoice(player, self:objectName(), 
                        "zhinian_extra_yes+zhinian_extra_no")                    
                    if choice == "zhinian_extra_no" then
                        room:removeTag("zhinian_extra")
                        break
                    end
                    room:setTag("zhinian_extra", sgs.QVariant(1))
                    nico:gainAnExtraTurn()
                    room:removeTag("zhinian_extra")
                    nExtras = nExtras - 1
                end
                
                room:removeTag("zhinian_extra_count")
            else
                local change = data:toPhaseChange()
                if change.to ~= sgs.Player_Play then
                    player:skip(change.to)                
                end
                
            end
        end
    end,
    
    can_trigger = function(self, target)
		return target
	end
}


LuawudaoCard = sgs.CreateSkillCard{
    name = "LuawudaoCard",
    target_fixed = true,
    will_throw = false,
	 
    on_use = function(self, room, source)
        if not source:isKongcheng() then
            local card_id = -1
            local handcards = source:handCards()					
            if handcards:length() == 999 then
                room:getThread():delay(500)
                card_id = handcards:first()
            else
                local cards = room:askForExchange(source, self:objectName(), 1, 1, false, "Luawudao-push")
                local suit = cards:getSuit()
                if suit == sgs.Card_Heart or suit == sgs.Card_Diamond then
                    room:setPlayerFlag(source,"wudaored")
                    --room:loseHp(source)	
                end
                if suit == sgs.Card_Club or suit == sgs.Card_Spade then
                    room:setPlayerFlag(source,"wudaoblack")
                
                end
                card_id = cards:getSubcards():first()
            end
            source:addToPile("wudao", card_id)
        end	
					
    end
}
	
Luawudao_tar = sgs.CreateTargetModSkill {
    name = "#Luawudao",

    distance_limit_func = function(self, from, card)
        if from:hasFlag("wudaored") then
            return 998
        else
            return 0
        end
    end,
    
    residue_func = function(self, from, card)
        if from:hasFlag("wudaoblack") then
            return 1
        else
            return 0
        end
    end
}
	
Luawudao_return = sgs.CreateTriggerSkill {
    name = "#Luawudao_return",
    frequency = sgs.Skill_Compulsory,
    events = {sgs.EventPhaseChanging},

    can_trigger = function(self, target)
        return target
    end,

    on_trigger = function(self, event, player, data)
        local change = data:toPhaseChange()
        local room = player:getRoom()
        if change.to == sgs.Player_NotActive then
            for _, p in sgs.qlist(room:getAllPlayers()) do
                if not p:getPile("wudao"):isEmpty() then
                    local reason = sgs.CardMoveReason(sgs.CardMoveReason_S_REASON_GOTCARD, p:objectName())
                    local move = sgs.CardsMoveStruct(p:getPile("wudao"), p, sgs.Player_PlaceHand, reason)
                    room:moveCardsAtomic(move, false)
                    room:broadcastSkillInvoke("Luawudao")
                end
            end
        end
        return false
    end
}

Luawudao = sgs.CreateViewAsSkill{
    name = "Luawudao", 
    n = 0, 
    view_as = function(self, cards)
        return LuawudaoCard:clone()
    end, 
    enabled_at_play = function(self, player)
        return not player:hasUsed("#LuawudaoCard")
    end

}


Luayanxun = sgs.CreateTriggerSkill{
    name = "Luayanxun",
    frequency = sgs.Skill_NotFrequent, 
    events = {sgs.EventPhaseEnd},
    can_trigger = function(self, target)
        return target
    end,
    on_trigger = function(self, event, player, data)
        local room = player:getRoom()
        local umi = room:findPlayerBySkillName(self:objectName())
        if player:getPhase() == sgs.Player_Draw then
            
            if room:askForSkillInvoke(umi, "Luayanxun", data) then
                if not room:askForCard(player,"..", "@Luayanxun", data) then
                    player:drawCards(2)
                    room:loseMaxHp(player,1)
                    else
                        local currentMaxHp = player:getMaxHp()
                        if currentMaxHp < 5 then
                            room:setPlayerProperty(player, "maxhp", sgs.QVariant(currentMaxHp + 1))                 
                        end
                end
            end
        end
    end,
}

maki:addSkill(qianjin)
maki:addSkill(bieniu)
maki:addSkill(puzou)

nico:addSkill(chengneng)
nico:addSkill(xianxu)
nico:addSkill(zhinian)

umi:addSkill(Luayanxun)
umi:addSkill(Luawudao)
umi:addSkill(Luawudao_return)
umi:addSkill(Luawudao_tar)
extension:insertRelatedSkills("Luawudao", "#Luawudao")


sgs.LoadTranslationTable 
{
    ["lovelive"] = "LoveLive!",

    ["maki"] = "西木野真姬",
    ["&maki"] = "西木野真姬",
    ["#maki"] = "冷酷的炽热",
    ["designer:maki"] = "醉花夢月",
	
	["qianjin"] = "千金",
	[":qianjin"] = "准备阶段或者结束阶段开始时，你可以摸X张牌（X为你和场上手牌最多的角色的手牌差且至少为1)。",
    ["bieniu"] = "彆扭",
    [":bieniu"] = "<b>锁定技，</b>出牌阶段，你不能使用与你于此阶段内使用的上一张牌颜色相同的牌。",
    
    ["puzou"] = "谱奏",
    [":puzou"] = "一名角色的弃牌阶段结束时，若于此回合进入弃牌堆的牌（至少三张）花色均不相同或颜色均相同，你可以令所有角色各回复1点体力或者各失去1点体力。",
    ["puzou_lose"] = "所有角色各失去1点体力",
    ["puzou_renerate"] = "所有角色各回复1点体力",
    
    ["nico"] = "矢泽妮可",
    ["&nico"] = "矢泽妮可",
    ["#nico"] = "小恶魔",
    ["designer:maki"] = "醉花夢月",
    
    ["chengneng"] = "逞能",
    [":chengneng"] = "<b>锁定技，</b>游戏开始时，你获得逞能标记；出牌阶段，若此标记正面朝上，你不能使用红色牌，否则你不能使用黑色牌；出牌阶段结束时，你将此标记翻面。",
    ["#chengneng_ban"] = "%from此出牌阶段不能使用%arg牌",

    ["xianxu"] = "羡绪",
    [":xianxu"] = "<b>锁定技，</b>弃牌阶段结束时，下列四项（手牌、体力、装备区的牌数、攻击范围）每有一项你不为场上最多或之一，你便选择：摸一张牌或获得一张于此阶段进入弃牌堆的牌。",
    ["xianxu_draw"] = "摸一张牌",
    ["xianxu_obtain"] = "获得一张此于此阶段进入弃牌堆的牌",
    ["xianxu_discarded"] = "此轮弃牌",
    
    ["zhinian"] = "执念",
    [":zhinian"] = "当你的体力变化时，你可令当前回合角色和你同时选择：摸一张牌或弃置一张黑色牌，若两者的选择不同，防止此变化；否则你可于此回合结束时执行一个额外的出牌阶段。",
    ["zhinian_throw_prompt"] = "选择一张要弃置的黑色牌，或选择取消摸一张牌",
    ["zhinian_extra_yes"] = "执行一个额外的出牌阶段",
    ["zhinian_extra_no"]  = "取消",
    ["#zhinian_play"] = "%from还有%arg个额外的出牌阶段",
	
    ["umi"] = "园田海未",
    ["&umi"] = "园田海未",
    ["#umi"] = "古風海色",
    ["designer:umi"] = "醉花夢月",
    ["Luawudao"] = "武道",
    ["luawudao"] = "武道",
    ["wudao"] = "武道",
    ["LuawudaoCard"] = "武道",
    [":Luawudao"] = "出牌阶段限一次，你可以将一张手牌置于武将牌上，若此牌为：红色，你于此阶段使用【杀】无距离限制；黑色，你能于此阶段额外使用一张【杀】。若如此做，此回合结束时，你获得武将牌上的牌。",
    ["Luawudao-push"] = "请将一张手牌置于武将牌上。",
    ["Luayanxun"] = "严训",
    [":Luayanxun"] = "一名角色的摸牌阶段结束时，你可以令其选择一项：1.弃置一张牌，然后加1点体力上限(最多为5)；2.减1点体力上限，然后摸两张牌。",
    ["@Luayanxun"] = "1.弃置一张牌，然后加1点体力上限(最多为5)；2.按取消减1点体力上限，然后摸两张牌。",
    ["designer:umi"] = "醉花夢月",

}
