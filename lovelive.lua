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
            print("The richest player has ", max_, " handcards")
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
            print("A red card is being used in my play phase. Lock red and unlock black")
            room:setPlayerCardLimitation(player, "use", ".|red|.", true)
            room:removePlayerCardLimitation(player, "use", ".|black|.$1")
        else
            print("A black card is being used in my play phase. Lock black and unlock red")
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

puzou = sgs.CreateTriggerSkill{
	name = "puzou",
	frequency = sgs.Skill_NotFrequent,
	events = {sgs.CardsMoveOneTime},
	on_trigger = function(self, event, player, data)
		local room = player:getRoom()
		local maki = room:findPlayerBySkillName(self:objectName())
		local current = room:getCurrent()
		local move = data:toMoveOneTime()
		local source = move.from
        -- Refer to Zhangzhao's skill: guzhengOther
        -- Return in advance to reduce levels of indentation
        if not source then 
            return false
        end        
        if player:objectName() ~= source:objectName() then
            return false
        end
        if current:getPhase() ~= sgs.Player_Discard then
            return false
        end
        -- verbose: if reason of move is not discard, then cannot trigger skill
        if (bit32.band(move.reason.m_reason, sgs.CardMoveReason_S_MASK_BASIC_REASON) 
                        ~= sgs.CardMoveReason_S_REASON_DISCARD) then
            return false
        end
        if move.card_ids:length() < 3 then
            return false
        end        
        if not isOfDifferentSuits(move.card_ids) and not isOfSameColor(move.card_ids) then 
            return false
        end
        
        -- This is pretty easy. Just refer to 神周瑜's skill 琴音
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
        return true       
		
	end,
	can_trigger = function(self, target)
		return target
	end
}

maki:addSkill(qianjin)
maki:addSkill(bieniu)
maki:addSkill(puzou)

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
    [":bieniu"] = "<b>锁定技，</b>出牌阶段，你不能使用与你于此阶段内容使用的上一张牌颜色相同的牌。",
    
    ["puzou"] = "谱奏",
    [":puzou"] = "一名角色的弃牌阶段结束时，若于此回合进入弃牌堆的牌（至少三张）花色均不相同或颜色均相同，你可以令所有角色各回复1点体力或者各失去1点体力。",
    ["puzou_lose"] = "所有角色各失去1点体力",
    ["puzou_renerate"] = "所有角色各回复1点体力",
}
