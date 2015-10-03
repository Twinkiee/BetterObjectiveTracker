-----------------------------------------------------------------------------------------------
-- Client Lua Script for MovableObjectiveTracker
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "GameLib"

local knButtonArtPadding = 14

local MovableObjectiveTracker = {}

function MovableObjectiveTracker:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	
	o.nOpacity 							 = 0.33
	o.nOpacityMouseOver 			 = 0.66
	o.bShowButtonsOnMouseOver = false
	o.tAddons = {}

	return o
end

function MovableObjectiveTracker:Init()
    Apollo.RegisterAddon(self)
end

function MovableObjectiveTracker:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("MovableObjectiveTracker.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function MovableObjectiveTracker:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	return
	{
		nOpacity				= self.nOpacity,
		nOpacityMouseOver	= self.nOpacityMouseOver,
		bShowButtonsOnMouseOver			= self.bShowButtonsOnMouseOver,
	}
end

function MovableObjectiveTracker:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then
		return
	end

	if tSavedData.nOpacity ~= nil then
		self.nOpacity = tSavedData.nOpacity
	end
	
	if tSavedData.nOpacityMouseOver ~= nil then
		self.nOpacityMouseOver = tSavedData.nOpacityMouseOver
	end
	
	if tSavedData.bShowButtonsOnMouseOver ~= nil then
		self.bShowButtonsOnMouseOver = tSavedData.bShowButtonsOnMouseOver
	end
end


function MovableObjectiveTracker:OnDocumentReady()
	if self.xmlDoc == nil or not self.xmlDoc:IsLoaded() then return end
	
	Apollo.RegisterEventHandler("ObjectiveTracker_RequestParent", 	"OnRequestParent", self)
	Apollo.RegisterEventHandler("ObjectiveTracker_NewAddOn", 		"OnAddonNew", self)
	Apollo.RegisterEventHandler("ObjectiveTracker_UpdateAddOn", 	"OnAddonUpdate", self)
	Apollo.RegisterEventHandler("ObjectiveTracker_RemoveAddOn", 	"OnAddonRemoved", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 			"OnWindowManagementReady", self)
	Apollo.RegisterEventHandler("WindowManagementUpdate", 			"OnWindowManagementUpdate", self)
	Apollo.RegisterEventHandler("OptionsUpdated_QuestTracker", 		"OnOptionsUpdated", self)
	
	Apollo.RegisterEventHandler("ObjectiveTracker_ExternalRequestRedraw", 	"OnResizeAll", self)

    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MovableObjectiveTrackerForm", "FixedHudStratumLow", self)
	self.wndMain:SetSizingMinimum(325, 120)
	self.bMoveable = self.wndMain:IsStyleOn("Moveable")
	
	self.wndObjectiveTrackerScroll = self.wndMain:FindChild("ObjectiveTrackerScroll")
	self.wndObjectiveTrackerScroll:SetBGOpacity(self.nOpacity)
	
	self.wndButtonContainer = self.wndMain:FindChild("ButtonContainer")
	self.wndButtonContainer:Show(not self.bShowButtonsOnMouseOver)
	self.wndSettingsButton = Apollo.LoadForm(self.xmlDoc, "SettingsButton", self.wndButtonContainer:FindChild("Buttons"), self)
	
	self.wndButtonArt = self.wndButtonContainer:FindChild("Art")
	self.wndButtonArt:SetBGOpacity(self.nOpacity)
	self.wndButtonArtWidth = self.wndButtonArt:GetWidth()
	
	self:OnOptionsUpdated()
	self:OnRequestParent()
	
	self.timerResizeThrottle = ApolloTimer.Create(0.1, false, "OnResizeAll", self)
	self.timerResizeThrottle:Stop()
	
	self.timerObjectiveTrackerUpdate = ApolloTimer.Create(1.0, true, "OnRedrawTimer", self)
	self.wndButtonContainer:FindChild("ShortcutBtn"):AttachWindow(self.wndButtonContainer:FindChild("ContextMenu"))
	self.wndButtonContainer:FindChild("ShortcutBtn"):SetCheck(false)
	self.wndContextMenu = self.wndButtonContainer:FindChild("ContextMenu")
end

function MovableObjectiveTracker:OnRedrawTimer()
	--If your addon is attached to the objective tracker and you need a one second timer, use this event instead of creating an additional timer!
	Event_FireGenericEvent("ObjectiveTrackerUpdated", true)
end

function MovableObjectiveTracker:OnRequestParent()
	Event_FireGenericEvent("ObjectiveTrackerLoaded", self.wndObjectiveTrackerScroll)
end

function MovableObjectiveTracker:OnWindowManagementReady()
    Event_FireGenericEvent("WindowManagementRegister", {wnd = self.wndMain, strName = Apollo.GetString("CRB_ObjectiveTracker"), nSaveVersion = 1})
	Event_FireGenericEvent("WindowManagementAdd", { wnd = self.wndMain, strName = Apollo.GetString("CRB_ObjectiveTracker"), nSaveVersion = 1 })
end

function MovableObjectiveTracker:OnWindowManagementUpdate(tSettings)
	local bOldHasMoved = self.bHasMoved
	local bOldMoveable = self.bMoveable

	if tSettings and tSettings.wnd and tSettings.wnd == self.wndMain then
		self.bMoveable = self.wndMain:IsStyleOn("Moveable")
		self.bHasMoved = tSettings.bHasMoved

		self.wndMain:FindChild("Background"):SetSprite(self.bMoveable and "BK3:UI_BK3_Holo_InsetFlyout" or "")
		self.wndMain:SetStyle("Sizable", self.bMoveable and self.bHasMoved)
		self.wndMain:SetStyle("IgnoreMouse", not self.bMoveable)
		
		for _, wndBtn in pairs(self.wndButtonContainer:FindChild("Buttons"):GetChildren()) do
			if wndBtn ~= self.wndSettingsButton then
				self:HelperConstructDataBtnAdded(wndBtn)
			end
		end
	end
end

function MovableObjectiveTracker:HelperConstructDataBtnAdded(wndButton)
	if not wndButton then
		return
	end

	--If xml changes, these must be updated.
	local wndIcon = wndButton:FindChild("Icon")
	local wndBtns = wndButton:GetParent()
	local wndBtnContainer = wndBtns:GetParent()
	local wndOTForm = wndBtnContainer:GetParent()

	local nIconWidth = wndIcon:GetWidth()
	local nIconHeight = wndIcon:GetHeight() / 2
	local nObjBtnLeft, nObjBtnTop, nObjBtnRight, nObjBtnBottom= wndButton:GetRect()
	local nBtnsLeft, nBtnsTop, nBtnsRight, nBtnsBottom= wndBtns:GetRect()
	local nBtnContainerLeft, nBtnContainerTop, nBtnContainerRight, nBtnContainerBottom= wndBtnContainer:GetRect()
	local nOTFormLeft, nOTFormTop, nOTFormRight, nOTFormBottom = wndOTForm:GetRect()
	
	local nLeft = nOTFormLeft + nBtnContainerLeft + nBtnsLeft + nObjBtnLeft - nIconWidth
	local nTop = nOTFormTop + nBtnContainerTop + nBtnsTop + nObjBtnTop + nIconHeight
	local nRight = nOTFormRight + nBtnContainerRight + nBtnsRight + nObjBtnRight - nIconWidth
	local nBottom = nOTFormBottom - nBtnsBottom + nObjBtnBottom + nIconHeight

	local tData = {strAddon = wndButton:GetData(), tRect = {l = nLeft, t = nTop, r =nRight, b = nBottom}}
	Event_FireGenericEvent("ObjectiveTracker_ButtonAdded", tData)	
end

function MovableObjectiveTracker:OnBackgroundMouse(wndHandler, wndControl)
	local bHasMouse = wndHandler:ContainsMouse()
	
	self.wndObjectiveTrackerScroll:SetBGOpacity(bHasMouse and self.nOpacityMouseOver or self.nOpacity)
	self.wndButtonArt:SetBGOpacity(bHasMouse and self.nOpacityMouseOver or self.nOpacity)
	
	if self.bShowButtonsOnMouseOver then
		self.wndButtonContainer:Show(bHasMouse)
	else
		self.wndButtonContainer:Show(true)
	end
end

function MovableObjectiveTracker:OnOptionsUpdated()
	if g_InterfaceOptions and g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom ~= nil then
		self.bQuestTrackerAlignBottom = g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom
	else
		self.bQuestTrackerAlignBottom = true
	end
	
	self:OnResizeAll()
end

function MovableObjectiveTracker:OnAddonNew(tAddonSettings)
	if not tAddonSettings or not tAddonSettings.strAddon or self.tAddons[tAddonSettings.strAddon] then
		return
	end
	
	local strKey = tAddonSettings.strAddon
	self.tAddons[strKey] = tAddonSettings
	
	if not tAddonSettings.bNoTrackerBtn then
		local wndButton = Apollo.LoadForm(self.xmlDoc, "TrackerButton", self.wndButtonContainer:FindChild("Buttons"), self)
		wndButton:SetData(strKey)
		wndButton:SetTooltip(strKey)
		
		if tAddonSettings.strIcon ~= "" then
			wndButton:FindChild("Icon"):SetSprite(tAddonSettings.strIcon)
		else 
			wndButton:FindChild("Icon"):SetText(string.sub(strKey, 1, 1))
		end
	end
	
	local bShow = true
	if tAddonSettings.bShow ~= nil then
		bShow = tAddonSettings.bShow
	end
	
	if wndButton then
		wndButton:Show(bShow)
	end
	
	local function SortTrackerScroll(a, b)
		if a:GetData() == nil or b:GetData() == nil then return false end
		
		return self.tAddons[a:GetData()].strDefaultSort < self.tAddons[b:GetData()].strDefaultSort
	end
	
	self.wndButtonContainer:FindChild("Buttons"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.RightOrBottom, SortTrackerScroll)
end

function MovableObjectiveTracker:OnAddonRemoved(tAddonSettings)
	if not tAddonSettings or not tAddonSettings.strAddon or not self.tAddons[tAddonSettings.strAddon] then
		return
	end
	
	local strKey = tAddonSettings.strAddon	
	local wndButton = self.wndButtonContainer:FindChildByUserData(strKey)
	
	if wndButton and wndButton:IsValid() then
		wndButton:Destroy()
	end
	
	self.tAddons[strKey] = nil
	
	self:OnResizeAll()
end

function MovableObjectiveTracker:OnAddonUpdate(tAddonSettings)
	if not tAddonSettings or not tAddonSettings.strAddon then
		return
	end
	
	local wndButton = self.wndButtonContainer:FindChildByUserData(tAddonSettings.strAddon)
	if not wndButton or not wndButton:IsValid() then
		return
	end
	
	local bShow = true
	if tAddonSettings.bShow ~= nil then
		bShow = tAddonSettings.bShow
	end
	
	local nOpacity = tAddonSettings.bChecked and 1 or 0.3
	wndButton:FindChild("Icon"):SetOpacity(nOpacity)
	wndButton:FindChild("Number"):SetOpacity(nOpacity)
	wndButton:FindChild("Number"):SetText(tAddonSettings.strText or "")
	wndButton:Show(bShow)
	
	for k, v in pairs(tAddonSettings) do
		self.tAddons[tAddonSettings.strAddon][k] = v
	end

	wndButton:FindChild("ShortcutBtn"):SetData(tAddonSettings.strAddon)
	
	
	if self.timerResizeThrottle then
		self.timerResizeThrottle:Stop()
		self.timerResizeThrottle:Start()
	end
end

function MovableObjectiveTracker:OnResizeAll()
	self.wndObjectiveTrackerScroll:ArrangeChildrenVert(Window.CodeEnumArrangeOrigin.LeftOrTop, function(a,b) return tostring(a:GetData()) < tostring(b:GetData()) end)
	
	local nLeft, nTop, nRight, nBottom = self.wndMain:GetAnchorOffsets()
	local nButtonLeft, nButtonTop, nButtonRight, nButtonBottom = self.wndButtonContainer:GetAnchorOffsets()
	
	local nNewHeight = 0
	for _, wndCurr in pairs(self.wndObjectiveTrackerScroll:GetChildren()) do
		nNewHeight = wndCurr:IsShown() and nNewHeight + wndCurr:GetHeight() or nNewHeight
	end
	
	local nDelta 		= self.wndMain:GetHeight() - nNewHeight + nButtonTop - self.wndButtonContainer:GetHeight()
	local nNewTop 		= self.bQuestTrackerAlignBottom and math.max(0, nDelta) or 0
	local nNewBottom	= self.bQuestTrackerAlignBottom and -self.wndButtonContainer:GetHeight() or math.min(-self.wndButtonContainer:GetHeight(), -nDelta - self.wndButtonContainer:GetHeight())
	
	self.wndObjectiveTrackerScroll:SetAnchorOffsets(0, nNewTop, 0, nNewBottom)
	
	local nNewWidth = knButtonArtPadding
	for _, wndCurr in pairs(self.wndButtonContainer:FindChild("Buttons"):GetChildren()) do
		nNewWidth = wndCurr:IsShown() and nNewWidth + wndCurr:GetWidth() or nNewWidth
	end
	
	local nArtLeft, nArtTop, nArtRight, nArtBottom = self.wndButtonArt:GetAnchorOffsets()
	local nDelta = math.max(0, self.wndButtonArtWidth - nNewWidth)
	
	self.wndButtonContainer:FindChild("Buttons"):ArrangeChildrenHorz(Window.CodeEnumArrangeOrigin.RightOrBottom, SortTrackerScroll)
	self.wndButtonArt:SetAnchorOffsets(nDelta, nArtTop, nArtRight, nArtBottom)
end

function MovableObjectiveTracker:OnListBtnClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then return end
	
	tAddonSettings = self.tAddons[wndControl:GetData()]
	
	if not tAddonSettings then return end
	
	if eMouseButton == GameLib.CodeEnumInputMouse.Right and tAddonSettings.strEventMouseRight ~= nil then
		Event_FireGenericEvent(tAddonSettings.strEventMouseRight)
	elseif tAddonSettings.strEventMouseLeft ~= nil then
		Event_FireGenericEvent(tAddonSettings.strEventMouseLeft)
	end
end

-----------------------------------------------------------------------------------------------
-- Right Click
-----------------------------------------------------------------------------------------------
function MovableObjectiveTracker:CloseContextMenu() -- From a variety of source
	if self.wndButtonContainer:FindChild("ShortcutBtn"):IsChecked() then
		self.wndButtonContainer:FindChild("ShortcutBtn"):SetCheck(false)
		return true
	end
	
	return false
end

function MovableObjectiveTracker:DrawContextMenu()
	self.wndContextMenu = self.wndSettingsButton:FindChild("ContextMenu")
	self.wndContextMenu:FindChild("QuestTrackerByDistance"):SetCheck(g_InterfaceOptions.Carbine.bQuestTrackerByDistance)
	self.wndContextMenu:FindChild("QuestAlignTop"):SetCheck(not self.bQuestTrackerAlignBottom)
	self.wndContextMenu:FindChild("QuestAlignBottom"):SetCheck(self.bQuestTrackerAlignBottom)
	self.wndContextMenu:FindChild("QuestTrackerShowButtons"):SetCheck(self.bShowButtonsOnMouseOver)
	self.wndContextMenu:FindChild("Opacity"):FindChild("SliderBar"):SetValue(self.nOpacity)
	self.wndContextMenu:FindChild("Opacity"):FindChild("Label"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_QuestOpacity"), self.nOpacity))
	self.wndContextMenu:FindChild("OpacityMouse"):FindChild("SliderBar"):SetValue(self.nOpacityMouseOver)
	self.wndContextMenu:FindChild("OpacityMouse"):FindChild("Label"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_QuestOpacityMouseOver"), self.nOpacityMouseOver))
end

function MovableObjectiveTracker:OnToggleQuestTrackerByDistance(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bQuestTrackerByDistance = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
end

function MovableObjectiveTracker:OnToggleQuestTrackerAlignTop(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom = not wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
end

function MovableObjectiveTracker:OnToggleQuestTrackerAlignBottom(wndHandler, wndControl)
	g_InterfaceOptions.Carbine.bQuestTrackerAlignBottom = wndHandler:IsChecked()
	Event_FireGenericEvent("OptionsUpdated_QuestTracker")
end

function MovableObjectiveTracker:OnToggleQuestShowButtons(wndHandler, wndControl)
	self.bShowButtonsOnMouseOver = wndHandler:IsChecked()
	
	self.wndButtonContainer:Show(not self.bShowButtonsOnMouseOver)
end

function MovableObjectiveTracker:OnOpacitySliderBarChanged(wndHandler, wndControl, fValue, fOldValue)
	self.nOpacity = fValue
	
	self.wndObjectiveTrackerScroll:SetBGOpacity(bHasMouse and self.nOpacityMouseOver or self.nOpacity)
	self.wndButtonArt:SetBGOpacity(bHasMouse and self.nOpacityMouseOver or self.nOpacity)
	self.wndContextMenu:FindChild("Opacity"):FindChild("Label"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_QuestOpacity"), self.nOpacity))
end

function MovableObjectiveTracker:OnOpacityMouseSliderBarChanged(wndHandler, wndControl, fValue, fOldValue)
	self.nOpacityMouseOver = fValue
	
	self.wndObjectiveTrackerScroll:SetBGOpacity(bHasMouse and self.nOpacityMouseOver or self.nOpacity)
	self.wndButtonArt:SetBGOpacity(bHasMouse and self.nOpacityMouseOver or self.nOpacity)
	self.wndContextMenu:FindChild("OpacityMouse"):FindChild("Label"):SetText(String_GetWeaselString(Apollo.GetString("InterfaceOptions_QuestOpacityMouseOver"), self.nOpacityMouseOver))
end

local MovableObjectiveTrackerInst = MovableObjectiveTracker:new()
MovableObjectiveTrackerInst:Init()
