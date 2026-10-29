-- LidarScanner 2 GUI file

AddCSLuaFile()
AddCSLuaFile("lidarscanner2_language.lua")
if CLIENT then
	local LSL = include("lidarscanner2_language.lua")
	local lgphrase = language.GetPhrase
	local getcvarnum = GetConVarNumber
	local getcvarstr = GetConVarString
	local setcvarnum = RunConsoleCommand
	-- Function to call inside DPanel.PaintOver
	local function panelpaintoverfunc(self,w,h,cvardesc,df)
		if self.parentpanel then
			if not self.parentpanel:HasFocus() then return end
			local cx,cy = self:LocalCursorPos()
			if cx>0 and cy>0 and cx<math.min(w,df or w) and cy<h then
				self.parentpanel.childpaneldesc = cvardesc
				return
			end
		end
		local cx,cy = self:LocalCursorPos()
		if cx>0 and cy>0 and cx<math.min(w,df or w) and cy<h then
			local old = DisableClipping(true)
			surface.SetFont("DermaDefault")
			local textw,texth = surface.GetTextSize(cvardesc)
			draw.RoundedBox(3,cx+10,cy,textw,texth,Color(200,200,200))
			draw.SimpleText(cvardesc,"DermaDefault",cx+10,cy,Color(10,10,10))
			DisableClipping(old)
		end
	end
	-- Creates "Header" text with large text size
	local function headertext(par,x,y,text)
		local label = vgui.Create("DLabel",par)
		label:SetPos(x,y)
		label:SetText(text)
		label:SetFont("HudHintTextLarge")
		label:SizeToContents()
		return label
	end
	-- Creates "Help" text with default text size
	local function helptext(par,x,y,text)
		local label = vgui.Create("DLabel",par)
		label:SetPos(x,y)
		label:SetText(text)
		label:SizeToContents()
		return label
	end
	-- Creates slider
	local function slider(par,x,y,w,text,cvarname,dec,def,min,max,desc,sfunc,val)
		local cvar = nil
		if cvarname then
			cvar = GetConVar(cvarname)
			if not cvar then return end
		end
		local cvardesc = ""
		if cvarname then
			cvardesc = cvar:GetHelpText() .. " (" .. tostring(cvarname) .. ")"
		else
			cvardesc = desc or "*none provided*"
		end
		local slider = nil
		local slider_Btn_Increase = vgui.Create("DButton",par)
		slider_Btn_Increase:SetPos(x+w,y)
		slider_Btn_Increase:SetText("+")
		slider_Btn_Increase:SetSize(15,15)
		slider_Btn_Increase.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		slider_Btn_Increase.DoClick = function()
			slider:SetValue(slider:GetValue()+1)
		end
		local slider_Btn_Decrease = vgui.Create("DButton",par)
		slider_Btn_Decrease:SetPos(x+w+16,y)
		slider_Btn_Decrease:SetText("-")
		slider_Btn_Decrease:SetSize(15,15)
		slider_Btn_Decrease.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		slider_Btn_Decrease.DoClick = function()
			slider:SetValue(slider:GetValue()-1)
		end
		local slider_Btn_DefaultVal = vgui.Create("DButton",par)
		slider_Btn_DefaultVal:SetPos(x+w+32,y)
		slider_Btn_DefaultVal:SetText("DEF")
		slider_Btn_DefaultVal:SetSize(32,15)
		slider_Btn_DefaultVal.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		if cvarname then
			slider_Btn_DefaultVal.DoClick = function()
				slider:SetValue(cvar:GetDefault())
			end
		else
			slider_Btn_DefaultVal.DoClick = function()
				slider:SetValue(def)
			end
		end
		slider = vgui.Create("DNumSlider",par)
		slider:SetPos(x,y)
		slider:SetText(text)
		slider:SetSize(w,15)
		slider:SetDecimals(dec or 0)
		if cvarname then
			slider:SetMin(cvar:GetMin())
			slider:SetMax(cvar:GetMax())
			slider:SetConVar(cvarname)
		else
			slider:SetMin(min)
			slider:SetMax(max)
			slider:SetValue(val)
			slider.OnValueChanged = function(self,value)
				sfunc(value)
			end
		end
		slider.parentpanel = par
		slider.PaintOver = function(self,w,h) panelpaintoverfunc(self,w,h,cvardesc,200) end
		slider.Btn_Increase = slider_Btn_Increase
		slider.Btn_Decrease = slider_Btn_Decrease
		slider.Btn_DefaultVal = slider_Btn_DefaultVal
		slider.OnRemove = function()
			slider.Btn_Increase:Remove()
			slider.Btn_Decrease:Remove()
			slider.Btn_DefaultVal:Remove()
		end
		return slider
	end
	-- Creates checkbox
	local function checkbox(par,x,y,text,cvarname,parentcvarname,val,sfunc,desc)
		local cvar = nil
		if cvarname then
			cvar = GetConVar(cvarname)
			if not cvar then return end
		end
		local cvardesc = ""
		if cvarname then
			cvardesc = cvar:GetHelpText() .. " (" .. tostring(cvarname) .. ")"
		else
			cvardesc = desc or "*none provided*"
		end
		local parentcvar = nil
		if parentcvarname then
			parentcvar = GetConVar(parentcvarname)
			if not parentcvar then return end
		end
		local checkbox = vgui.Create("DCheckBoxLabel",par)
		checkbox:SetPos(x,y)
		checkbox:SetText(text)
		if cvarname then
			checkbox:SetConVar(cvarname)
			checkbox:SetValue(cvar:GetInt() == 1)
		else
			checkbox.OnChange = function(self,value)
				sfunc(value)
			end
			checkbox:SetValue(val)
		end
		checkbox:SizeToContents()
		checkbox.parentpanel = par
		if parentcvar then
			checkbox.PaintOver = function(self,w,h)
				if parentcvar:GetInt() == 1 then
					self:SetDisabled(false)
				else
					self:SetDisabled(true)
				end
				panelpaintoverfunc(self,w,h,cvardesc)
			end
		else
			checkbox.PaintOver = function(self,w,h) panelpaintoverfunc(self,w,h,cvardesc) end
		end
		return checkbox
	end
	-- Creates button
	local function button(par,x,y,w,h,text,func)
		local button = vgui.Create("DButton",par)
		button:SetPos(x,y)
		button:SetText(text)
		button:SetSize(w,h)
		button.Paint = function(self,w,h)
			if self:IsEnabled() then
				draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			else
				draw.RoundedBox(3,0,0,w,h,Color(128,128,128))
			end
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		button.DoClick = func or function() end
		return button
	end
	-- Creates "binding" button
	local function binder(parent,x,y,w,h,bindcmd,bindname)
		local binder = vgui.Create("DBinder",parent)
		binder:SetPos(x,y)
		binder:SetSize(w,h)
		binder:SetText(bindname)
		binder.bind_cmdname = bindcmd
		binder.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		binder.OnChange = function(self,keynumber)
			chat.AddText(Color(255,200,10),lgphrase("#lidarscanner_bindingbutton_help"))
			SetClipboardText('bind "' .. tostring(input.GetKeyName(keynumber)) .. '" "' .. tostring(self.bind_cmdname) .. '"')
		end
	end
	-- Creates combobox
	local function combobox(par,x,y,w,h,initval,func)
		local combobox = vgui.Create("DComboBox",par)
		combobox:SetPos(x,y)
		combobox:SetSize(w,h)
		combobox:SetValue(initval)
		combobox.Paint = function(self,w,h)
			if self:IsEnabled() then
				draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			else
				draw.RoundedBox(3,0,0,w,h,Color(128,128,128))
			end
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
		end
		if func then
			combobox.OnSelect = func
		end
		return combobox
	end
	-- ***** Con-Commands *****
	concommand.Add("lidarscanner_openbindsmenu",function()
		local extlist_curext = nil
		local frame = vgui.Create("DFrame")
		frame:SetSize(256,256)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("LidarScanner " .. lgphrase("#lidarscanner_bindsmenu_title"),"DermaDefault",5,5,Color(200,200,200),0,3)
		end
		binder(frame,5,30,128,64,"lidarscanner_scansize_up",lgphrase("#lidarscanner_bindsmenu_scansize_up"))
		binder(frame,5,94,128,64,"lidarscanner_scansize_down",lgphrase("#lidarscanner_bindsmenu_scansize_down"))
		binder(frame,5,158,128,64,"+lidarscanner_scansize_unlockscroll",lgphrase("#lidarscanner_bindsmenu_unlockscansizescroll"))
	end)
	concommand.Add("lidarscanner_openextmenu",function()
		local extlist_curext = nil
		local frame = vgui.Create("DFrame")
		frame:SetSize(640,480)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("LidarScanner " .. lgphrase("#lidarscanner_extensionsmenu_title"),"DermaLarge",5,-3,Color(200,200,200),0,3)
		end
		frame.PaintOver = function(self,w,h)
			draw.SimpleText(lgphrase("#lidarscanner_extensionsmenu_toggleext_help"),"DermaDefault",405,465,Color(10,10,10))
			if extlist_curext then
				draw.DrawText(extlist_curext.name,"DermaLarge",405,50,Color(10,10,10))
				draw.DrawText(extlist_curext.desc,"DermaDefault",410,80,Color(10,10,10))
			else
				draw.DrawText(lgphrase("#lidarscanner_extensionsmenu_currentext_none"),"DermaLarge",512,200,Color(10,10,10),1)
			end
		end
		local btn_togglecolour = nil
		local btn_toggleextension = nil
		local ext_gui = nil
		local extlist = vgui.Create("DListView",frame)
		extlist:SetPos(0,30)
		extlist:SetSize(400,450)
		extlist:SetMultiSelect(false)
		extlist:AddColumn(lgphrase("#lidarscanner_extensionsmenu_ext_colouron"))
		extlist:AddColumn(lgphrase("#lidarscanner_extensionsmenu_ext_index"))
		extlist:AddColumn(lgphrase("#lidarscanner_extensionsmenu_ext_on"))
		extlist:AddColumn(lgphrase("#lidarscanner_extensionsmenu_ext_name"))
		extlist:AddColumn(lgphrase("#lidarscanner_extensionsmenu_ext_version"))
		extlist:AddColumn(lgphrase("#lidarscanner_extensionsmenu_ext_colourfunc"))
		extlist:AddColumn(lgphrase("#lidarscanner_extensionsmenu_ext_prescanfunc"))
		extlist:AddColumn(lgphrase("#lidarscanner_extensionsmenu_ext_postscanfunc"))
		local function cbform(bool)
			if bool then
				return " +"
			else
				return " -"
			end
		end
		local function rebuildextensionlist()
			for k,v in pairs(extlist:GetLines()) do
				extlist:RemoveLine(k)
			end
			for k,v in pairs(LidarScanner_GetExtensionsList()) do
				extlist:AddLine(cbform((LidarScanner_GetCurrentExtension() and v.name == LidarScanner_GetCurrentExtension()._name)),
					k,cbform(v.enabled),v.name,v.version,
					cbform(type(v.func_colourcalc) == "function"),
					cbform(type(v.func_prescan) == "function"),
					cbform(type(v.func_postscan) == "function"))
			end
		end
		local btn_refreshall = vgui.Create("DButton",frame)
		btn_refreshall:SetPos(404,35)
		btn_refreshall:SetSize(64,16)
		btn_refreshall:SetText(lgphrase("#lidarscanner_extensionsmenu_refresh"))
		btn_refreshall.DoClick = rebuildextensionlist
		local btn_reloadall = vgui.Create("DButton",frame)
		btn_reloadall:SetPos(512,35)
		btn_reloadall:SetSize(64,16)
		btn_reloadall:SetText(lgphrase("#lidarscanner_extensionsmenu_reload"))
		btn_reloadall.DoClick = function() LidarScanner_SaveExtConfigFile() LidarScanner_LoadExtensions() end
		local function toggleextension(ind)
			-- toggle extension
			LidarScanner_GetExtensionsList()[ind].enabled = not LidarScanner_GetExtensionsList()[ind].enabled
			if not LidarScanner_GetExtensionsList()[ind].enabled then
				if LidarScanner_GetCurrentExtension() then
					if LidarScanner_GetCurrentExtension()._name == LidarScanner_GetExtensionsList()[ind].name then
						LidarScanner_SetCurrentExtension(0)
					end
				end
				curclrcalc = function() return Color(255,255,255) end
			end
			rebuildextensionlist()
		end
		extlist.OnRowSelected = function(lst,index,pnl)
			if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
				toggleextension(pnl:GetColumnText(2))
			else
				local pind = pnl:GetColumnText(2)
				local tbl = LidarScanner_GetExtensionsList()[pind]
				extlist_curext = {ind = pind,name = tbl.name,desc = tbl.desc,enabled = tbl.enabled}
				if btn_togglecolour then btn_togglecolour:Remove() end
				if btn_toggleextension then btn_toggleextension:Remove() end
				if ext_gui then
					for k,v in pairs(ext_gui) do
						if v.children_on_frame then
							for i,ch in pairs(v.children_on_frame) do
								ch:Remove()
							end
						end
						v:Remove()
					end
				end
				btn_togglecolour = vgui.Create("DButton",frame)
				btn_togglecolour:SetPos(425,425)
				btn_togglecolour:SetSize(196,32)
				btn_togglecolour:SetText(lgphrase("#lidarscanner_extensionsmenu_currentext_setascolour"))
				btn_togglecolour.DoClick = function()
					LidarScanner_ChangeColourCalc(extlist_curext.ind)
					LidarScanner_SetCurrentExtension(extlist_curext.ind)
					rebuildextensionlist()
				end
				btn_toggleextension = vgui.Create("DButton",frame)
				btn_toggleextension:SetPos(425,393)
				btn_toggleextension:SetSize(196,32)
				btn_toggleextension:SetText(lgphrase("#lidarscanner_extensionsmenu_currentext_toggle"))
				btn_toggleextension.DoClick = function() toggleextension(extlist_curext.ind) rebuildextensionlist() end
				ext_gui = {}
				for k,v in pairs(tbl.gui) do
					local newguielement = nil
					local sffunc = function(val) LidarScanner_GetExtensionsList()[pind].variables[v.variable] = val end
					if v.type == "slider" then
						newguielement = slider(frame,400+v.pos_x,100+v.pos_y,v.size,v.name,nil,v.dec,v.def,v.min,v.max,v.desc,sffunc,LidarScanner_GetExtensionsList()[pind].variables[v.variable])
						newguielement.updatevalues_on_frame = function(self)
							self:SetValue(LidarScanner_GetExtensionsList()[pind].variables[v.variable])
						end
					end
					if v.type == "checkbox" then
						newguielement = checkbox(frame,400+v.pos_x,100+v.pos_y,v.name,nil,nil,LidarScanner_GetExtensionsList()[pind].variables[v.variable],sffunc,v.desc)
						newguielement.updatevalues_on_frame = function(self)
							self:SetValue(LidarScanner_GetExtensionsList()[pind].variables[v.variable])
						end
					end
					if v.type == "header" then
						newguielement = headertext(frame,400+v.pos_x,100+v.pos_y,v.name)
					end
					if v.type == "text" then
						newguielement = helptext(frame,400+v.pos_x,100+v.pos_y,v.name)
						newguielement:SetFont("DebugFixed")
						newguielement:SizeToContents()
					end
					if v.type == "colourchange" then
						newguielement = vgui.Create("DRGBPicker",frame)
						newguielement:SetPos(400+128+v.pos_x,100+v.pos_y)
						newguielement:SetSize(15,128)
						newguielement.colour_cube = vgui.Create("DColorCube",frame)
						newguielement.children_on_frame = {newguielement.colour_cube}
						newguielement.colour_cube:SetPos(400+v.pos_x,100+v.pos_y)
						newguielement.colour_cube:SetSize(128,128)
						local nclr = Color(LidarScanner_GetExtensionsList()[pind].variables[v.variable_r],
							LidarScanner_GetExtensionsList()[pind].variables[v.variable_g],
							LidarScanner_GetExtensionsList()[pind].variables[v.variable_b])
						local nh = ColorToHSV(nclr)
						local nclr = HSVToColor(nh, 1, 1)

						newguielement:SetRGB(nclr)
	
						local _, height = newguielement:GetSize()
						newguielement.LastY = height*(1-(nh/360))

						newguielement.colour_cube:SetColor(nclr)
						newguielement.colour_cube.OnUserChanged = function(self,col)
							LidarScanner_GetExtensionsList()[pind].variables[v.variable_r] = col.r
							LidarScanner_GetExtensionsList()[pind].variables[v.variable_g] = col.g
							LidarScanner_GetExtensionsList()[pind].variables[v.variable_b] = col.b
							for k,v in pairs(ext_gui) do
								if v.updatevalues_on_frame then
									v:updatevalues_on_frame()
								end
							end
						end
						newguielement.OnChange = function(self,col)
							local h = ColorToHSV(col)
							local _, s, v = ColorToHSV(newguielement.colour_cube:GetRGB())
							local col = HSVToColor(h, s, v)
							newguielement.colour_cube:SetColor(col)
							newguielement.colour_cube.OnUserChanged(newguielement.colour_cube,col)
						end
					end
					if newguielement then
						ext_gui[#ext_gui+1] = newguielement
					end
				end
			end
		end
		rebuildextensionlist()
	end)
	concommand.Add("lidarscanner_openscanlinesmenu",function()
		local frame = vgui.Create("DFrame")
		frame:SetSize(640,480)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.btnMaxim:Hide(true)
		frame.btnMinim:Hide(true)
		frame.btnClose.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
			draw.SimpleText("X","DermaLarge",7,-4,Color(10,10,10))
		end
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("LidarScanner " .. lgphrase("#lidarscanner_scanlinesmenu"),"DermaLarge",5,-3,Color(200,200,200),0,3)
		end
		helptext(frame,495,30,lgphrase("#lidarscanner_scanlinesmenu_linescolour"))
		local scanlines_preview_background_image = vgui.Create("DImage",frame)
		scanlines_preview_background_image:SetPos(5,30)
		scanlines_preview_background_image:SetSize(444,444)
		scanlines_preview_background_image:SetImage("lidarscanner2_valve_materials/gui/scanlines_preview_background_image.png")
		local scanlines_preview_foreground_image = vgui.Create("DImage",frame)
		scanlines_preview_foreground_image:SetPos(5,30)
		scanlines_preview_foreground_image:SetSize(444,444)
		scanlines_preview_foreground_image:SetImage("lidarscanner2_valve_materials/gui/scanlines_preview_foreground_image.png")
		local colour_picker = vgui.Create("DRGBPicker",frame)
		colour_picker:SetPos(623,50)
		colour_picker:SetSize(15,128)
		local colour_cube = vgui.Create("DColorCube",frame)
		colour_cube:SetPos(495,50)
		colour_cube:SetSize(128,128)
		colour_cube.OnUserChanged = function(self,col)
			RunConsoleCommand("lidarscanner_scanlines_colour_r",col.r)
			RunConsoleCommand("lidarscanner_scanlines_colour_g",col.g)
			RunConsoleCommand("lidarscanner_scanlines_colour_b",col.b)
			scanlines_preview_foreground_image:SetImageColor(col)
		end
		colour_picker.OnChange = function(self,col)
			local h = ColorToHSV(col)
			local _, s, v = ColorToHSV(colour_cube:GetRGB())
			col = HSVToColor(h, s, v)
			colour_cube:SetColor(col)
			colour_cube.OnUserChanged(colour_cube,col)
		end

		helptext(frame,495,240,lgphrase("#lidarscanner_scanlinesmenu_backgroundcolour"))
		local colour_picker_background = vgui.Create("DRGBPicker",frame)
		colour_picker_background:SetPos(623,256)
		colour_picker_background:SetSize(15,128)
		local colour_cube_background = vgui.Create("DColorCube",frame)
		colour_cube_background:SetPos(495,256)
		colour_cube_background:SetSize(128,128)
		colour_cube_background.OnUserChanged = function(self,col)
			scanlines_preview_background_image:SetImageColor(col)
		end
		colour_cube_background:SetColor(Color(255,255,255))
		colour_picker_background.OnChange = function(self,col)
			local h = ColorToHSV(col)
			local _, s, v = ColorToHSV(colour_cube_background:GetRGB())
			col = HSVToColor(h, s, v)
			colour_cube_background:SetColor(col)
			colour_cube_background.OnUserChanged(colour_cube_background,col)
		end

		local vscanlinecolour = Color(getcvarnum("lidarscanner_scanlines_colour_r"),
			getcvarnum("lidarscanner_scanlines_colour_g"),
			getcvarnum("lidarscanner_scanlines_colour_b"))
		colour_cube:SetColor(vscanlinecolour)
		scanlines_preview_foreground_image:SetImageColor(vscanlinecolour)
		local slider_r = slider(frame,455,180,200,lgphrase("#lidarscanner_scanlinesmenu_scanlines_r"),"lidarscanner_scanlines_colour_r",0)
		local slider_g = slider(frame,455,195,200,lgphrase("#lidarscanner_scanlinesmenu_scanlines_g"),"lidarscanner_scanlines_colour_g",0)
		local slider_b = slider(frame,455,210,200,lgphrase("#lidarscanner_scanlinesmenu_scanlines_b"),"lidarscanner_scanlines_colour_b",0)
		slider_r.OnValueChanged = function(self,val) local col = Color(val,getcvarnum("lidarscanner_scanlines_colour_g"),getcvarnum("lidarscanner_scanlines_colour_b")) scanlines_preview_foreground_image:SetImageColor(col) colour_cube:SetColor(col) end
		slider_g.OnValueChanged = function(self,val) local col = Color(getcvarnum("lidarscanner_scanlines_colour_r"),val,getcvarnum("lidarscanner_scanlines_colour_b")) scanlines_preview_foreground_image:SetImageColor(col) colour_cube:SetColor(col) end
		slider_b.OnValueChanged = function(self,val) local col = Color(getcvarnum("lidarscanner_scanlines_colour_r"),getcvarnum("lidarscanner_scanlines_colour_g"),val) scanlines_preview_foreground_image:SetImageColor(col) colour_cube:SetColor(col) end
	end)
	concommand.Add("lidarscanner_opensavescansavesmenu",function()
		local writequeue = nil
		local savemenu = vgui.Create("DFrame")
		savemenu:SetSize(512,128)
		savemenu:Center()
		savemenu:SetTitle("")
		savemenu:MakePopup()
		savemenu:SetDraggable(false)
		local label = nil
		savemenu.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner " .. lgphrase("#lidarscanner_savescansmenu_title"),"DermaDefault",5,5,Color(127,200,255),0,3)
			if writequeue then
				timer.Simple(RealFrameTime(),function()
					if writequeue then
						LidarScanner_SaveScans(writequeue)
						if label then label:Remove() end
						writequeue = nil
					end
				end)
			end
		end
		local text_entry_filename = vgui.Create("DTextEntry",savemenu)
		text_entry_filename:SetPos(11,60)
		text_entry_filename:SetSize(379,25)
		text_entry_filename:SetPlaceholderText(lgphrase("#lidarscanner_savescansmenu_save_help"))
		button(savemenu,405,57,64,32,lgphrase("#lidarscanner_savescansmenu_save"),function()
			if not writequeue then
				if text_entry_filename:GetValue() then
					label = vgui.Create("DLabel",savemenu)
					label:SetPos(5,90)
					label:SetText(lgphrase("#lidarscanner_savescansmenu_saving"))
					label:SizeToContents()
					writequeue = text_entry_filename:GetValue()
				end
			end
		end)
	end)
	concommand.Add("lidarscanner_openloadscansavesmenu",function()
		local loadmenu = vgui.Create("DFrame")
		loadmenu:SetSize(512,256)
		loadmenu:Center()
		loadmenu:SetTitle("")
		loadmenu:MakePopup()
		loadmenu:SetDraggable(false)
		loadmenu.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner " .. lgphrase("#lidarscanner_loadscansmenu_title"),"DermaDefault",5,5,Color(200,255,200),0,3)
		end
		local saveslist = vgui.Create("DListView",loadmenu)
		saveslist:SetPos(0,30)
		saveslist:SetSize(400,224)
		saveslist:SetMultiSelect(false)
		saveslist:AddColumn(lgphrase("#lidarscanner_loadscansmenu_file_index"))
		saveslist:AddColumn(lgphrase("#lidarscanner_loadscansmenu_file_name"))
		saveslist:AddColumn(lgphrase("#lidarscanner_loadscansmenu_file_size_kb"))
		saveslist:AddColumn(lgphrase("#lidarscanner_loadscansmenu_file_date"))
		local deletebutton = nil
		local loadbutton = nil
		local function reloadsaveslist()
			for k,v in pairs(saveslist:GetLines()) do
				saveslist:RemoveLine(k)
			end
			for k,v in pairs(file.Find("lidarscanner_savedscans/*.txt","DATA")) do
				saveslist:AddLine(k,string.TrimRight(v,".txt"),math.Round(file.Size("lidarscanner_savedscans/" .. v,"DATA")/1024,2),os.date("%H:%M:%S %d.%b.%Y",file.Time("lidarscanner_savedscans/" .. v,"DATA")))
			end
			deletebutton:SetEnabled(false)
			loadbutton:SetEnabled(false)
		end
		local timetext = vgui.Create("DLabel",loadmenu)
		timetext:SetPos(405,180)
		timetext:SetSize(64,32)
		timetext:SetText("")
		checkbox(loadmenu,405,150,lgphrase("#lidarscanner_loadscansmenu_cleardots"),"lidarscanner_loadscans_cleardots")
		deletebutton = button(loadmenu,405,120,64,16,lgphrase("#lidarscanner_loadscansmenu_delete_file"),function()
			local popup_window = vgui.Create("DFrame")
			popup_window:SetSize(256,128)
			popup_window:Center()
			popup_window:SetTitle(lgphrase("#lidarscanner_warning"))
			popup_window:MakePopup()
			popup_window:SetDraggable(false)
			local label = vgui.Create("DLabel",popup_window)
			label:SetPos(30,30)
			label:SetText(lgphrase("#lidarscanner_loadscansmenu_delete_file_warning"))
			label:SizeToContents()
			local reset_btn_accept = vgui.Create("DButton",popup_window)
			reset_btn_accept:SetPos(32,90)
			reset_btn_accept:SetSize(16,16)
			reset_btn_accept:SetText(lgphrase("#lidarscanner_warning_yes"))
			reset_btn_accept.DoClick = function()
				local _,pnl = saveslist:GetSelectedLine()
				if pnl then
					file.Delete("lidarscanner_savedscans/" .. pnl:GetColumnText(2) .. ".txt")
					reloadsaveslist()
					timetext:SetText("")
				end
				popup_window:Close()
			end
			local reset_btn_cancel = vgui.Create("DButton",popup_window)
			reset_btn_cancel:SetPos(164,64)
			reset_btn_cancel:SetSize(64,64)
			reset_btn_cancel:SetText(lgphrase("#lidarscanner_warning_no"))
			reset_btn_cancel.DoClick = function() popup_window:Close() end
		end)
		loadbutton = button(loadmenu,405,60,64,32,lgphrase("#lidarscanner_loadscansmenu_load_file"),function()
			local _,pnl = saveslist:GetSelectedLine()
			if pnl then
				local starttime = SysTime()
				LidarScanner_LoadScans(pnl:GetColumnText(2))
				timetext:SetText(tostring(math.Round(SysTime()-starttime,2)) .. lgphrase("#lidarscanner_loadscansmenu_load_seconds"))
				reloadsaveslist()
			end
		end)
		deletebutton:SetEnabled(false)
		loadbutton:SetEnabled(false)
		saveslist.OnRowSelected = function()
			deletebutton:SetEnabled(true)
			loadbutton:SetEnabled(true)
		end
		button(loadmenu,405,30,64,16,lgphrase("#lidarscanner_loadscansmenu_refresh"),function()
			timetext:SetText("") reloadsaveslist()
		end)
		reloadsaveslist()
	end)
	concommand.Add("lidarscanner_opensaveloadmenu",function()
		local saveloadmenu = vgui.Create("DFrame")
		saveloadmenu:SetSize(400,140)
		saveloadmenu:Center()
		saveloadmenu:SetTitle("")
		saveloadmenu:MakePopup()
		saveloadmenu:SetDraggable(false)
		saveloadmenu.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner " .. lgphrase("#lidarscanner_saveloadmenu_title"),"DermaDefault",5,5,Color(255,200,127),0,3)
		end
		
		headertext(saveloadmenu,48,30,lgphrase("#lidarscanner_saveloadmenu_extensions"))
		button(saveloadmenu,5,60,64,32,lgphrase("#lidarscanner_saveloadmenu_loadcfg"),function() RunConsoleCommand("lidarscanner_extensions_reload","") end)
		button(saveloadmenu,96,60,64,32,lgphrase("#lidarscanner_saveloadmenu_savecfg"),function() RunConsoleCommand("lidarscanner_extensions_save_config","") end)

		headertext(saveloadmenu,256,30,lgphrase("#lidarscanner_saveloadmenu_scanssaves"))
		button(saveloadmenu,213,60,64,32,lgphrase("#lidarscanner_saveloadmenu_loadscans"),function() RunConsoleCommand("lidarscanner_openloadscansavesmenu","") end)
		button(saveloadmenu,304,60,64,32,lgphrase("#lidarscanner_saveloadmenu_savescans"),function() RunConsoleCommand("lidarscanner_opensavescansavesmenu","") end)
		headertext(saveloadmenu,4,94,lgphrase("#lidarscanner_saveloadmenu_prenotify"))
	end)
	concommand.Add("lidarscanner_opendotmenu",function()
		local dotmenu = vgui.Create("DFrame")
		dotmenu:SetSize(400,140)
		dotmenu:Center()
		dotmenu:SetTitle("")
		dotmenu:MakePopup()
		dotmenu:SetDraggable(false)
		dotmenu.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner " .. lgphrase("#lidarscanner_dotmenu_title"),"DermaDefault",5,5,Color(200,127,255),0,3)
		end

		local DScroller = vgui.Create("DScrollPanel",dotmenu)
		DScroller:Dock(FILL)
		local texsfound = file.Find("materials/lidarscanner2_valve_materials/scanned_dots/*.png","GAME","nameasc")
		local selectedmatname = LidarScanner_GetScannedDotMaterialName()
		for k,v in pairs(texsfound) do
			local DButton = DScroller:Add("DButton")
			DButton:Dock(TOP)
			DButton:DockMargin(0,0,0,5)
			DButton:SetImage("lidarscanner2_valve_materials/scanned_dots/" .. v)
			DButton.dottexname = string.Replace(v,".png","")
			if DButton.dottexname == selectedmatname then
				DButton:SetText(">" .. DButton.dottexname .. "<")
			else
				DButton:SetText(DButton.dottexname)
			end
			DButton.DoClick = function(self)
				LidarScanner_SetScannedDotMaterial(self.dottexname)
				selectedmatname = LidarScanner_GetScannedDotMaterialName()
				dotmenu:Close()
				RunConsoleCommand("lidarscanner_opendotmenu","")
			end
		end
		local text_entry_filename = DScroller:Add("DTextEntry")
		text_entry_filename:Dock(TOP)
		text_entry_filename:SetPlaceholderText(lgphrase("#lidarscanner_dotmenu_custom_help"))
		text_entry_filename.OnEnter = function(self,val)
			if not val then return end
			if #val == 0 then return end
			local nmat = Material(val,"nocull")
			if nmat:IsError() then return end
			LidarScanner_SetScannedDotMaterial(nmat)	
			selectedmatname = LidarScanner_GetScannedDotMaterialName()
		end
	end)
	concommand.Add("lidarscanner_opensvmenu",function(_,_,args)
		local frame = vgui.Create("DFrame")
		frame:SetSize(384,256)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.btnMaxim:Hide(true)
		frame.btnMinim:Hide(true)
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner SV","DermaLarge",5,-3,Color(200,200,200),0,3)
		end
		frame.PaintOver = function(self,w,h)
			if not self.childpaneldesc then return end
			local cx,cy = self:LocalCursorPos()
			local old = DisableClipping(true)
			surface.SetFont("DermaDefault")
			local textw,texth = surface.GetTextSize(self.childpaneldesc)
			draw.RoundedBox(3,cx+10,cy,textw,texth,Color(200,200,200))
			draw.SimpleText(self.childpaneldesc,"DermaDefault",cx+10,cy,Color(10,10,10))
			DisableClipping(old)
			self.childpaneldesc = nil
		end
		helptext(frame,10,32,lgphrase("#lidarscanner_serverside"))

		button(frame,10,64,128,32,lgphrase("#lidarscanner_resetsettings"),function()
			local popup_window = vgui.Create("DFrame")
			popup_window:SetSize(256,128)
			popup_window:Center()
			popup_window:SetTitle(lgphrase("#lidarscanner_warning"))
			popup_window:MakePopup()
			popup_window:SetDraggable(false)
			local label = vgui.Create("DLabel",popup_window)
			label:SetPos(30,30)
			label:SetText(lgphrase("#lidarscanner_resetsettings_warning") .. "\n (lidarscanner_resetsvconvars)")
			label:SizeToContents()
			local lw = label:GetSize()
			label:SetPos(128-(lw/2),30)
			local reset_btn_accept = vgui.Create("DButton",popup_window)
			reset_btn_accept:SetPos(32,90)
			reset_btn_accept:SetSize(32,32)
			reset_btn_accept:SetText(lgphrase("#lidarscanner_warning_yes"))
			reset_btn_accept.DoClick = function() RunConsoleCommand("lidarscanner_resetsvconvars","") popup_window:Close() end
			local reset_btn_cancel = vgui.Create("DButton",popup_window)
			reset_btn_cancel:SetPos(164,64)
			reset_btn_cancel:SetSize(64,64)
			reset_btn_cancel:SetText(lgphrase("#lidarscanner_warning_no"))
			reset_btn_cancel.DoClick = function() popup_window:Close() end
		end)

		checkbox(frame,10,101,lgphrase("#lidarscanner_enabled"),"lidarscanner_sv_enabled")

		slider(frame,10,116,374,lgphrase("#lidarscanner_maxdist"),"lidarscanner_sv_maxdist",1)

		checkbox(frame,10,131,lgphrase("#lidarscanner_seeker"),"lidarscanner_sv_seeker_enabled")

		checkbox(frame,10,146,lgphrase("#lidarscanner_multiplayerbridge"),"lidarscanner_sv_multiplayerbridge_enabled")
	end)
	concommand.Add("lidarscanner_openmenu",function(_,_,args)
		local frame = vgui.Create("DFrame")
		frame:SetSize(640,256)
		frame:Center()
		frame:SetTitle("")
		frame:MakePopup()
		frame.btnMaxim:Hide(true)
		frame.btnMinim:Hide(true)
		frame.btnClose.Paint = function(self,w,h)
			draw.RoundedBox(3,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(3,1,1,w-2,h-2,Color(200,200,200))
			draw.SimpleText("X","DermaLarge",7,-4,Color(10,10,10))
		end
		frame.Paint = function(self,w,h)
			draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
			draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
			draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
			draw.SimpleText("Lidar Scanner " .. tostring(LIDARSCANNER_VERSION),"DermaLarge",5,-3,Color(200,200,200),0,3)
		end
		frame.PaintOver = function(self,w,h)
			if not self.childpaneldesc then return end
			local cx,cy = self:LocalCursorPos()
			local old = DisableClipping(true)
			surface.SetFont("DermaDefault")
			local textw,texth = surface.GetTextSize(self.childpaneldesc)
			draw.RoundedBox(3,cx+10,cy,textw,texth,Color(200,200,200))
			draw.SimpleText(self.childpaneldesc,"DermaDefault",cx+10,cy,Color(10,10,10))
			DisableClipping(old)
			self.childpaneldesc = nil
		end
		button(frame,574,62,64,32,lgphrase("#lidarscanner_clearscans"),function()
			local popup_window = vgui.Create("DFrame")
			popup_window:SetSize(256,128)
			popup_window:Center()
			popup_window:SetTitle(lgphrase("#lidarscanner_warning"))
			popup_window:MakePopup()
			popup_window:SetDraggable(false)
			local label = vgui.Create("DLabel",popup_window)
			label:SetText(lgphrase("#lidarscanner_clearscans_warning") .. "\n (lidarscanner_clearallscans)")
			label:SizeToContents()
			local lw = label:GetSize()
			label:SetPos(128-(lw/2),30)
			local reset_btn_accept = vgui.Create("DButton",popup_window)
			reset_btn_accept:SetPos(32,90)
			reset_btn_accept:SetSize(32,32)
			reset_btn_accept:SetText(lgphrase("#lidarscanner_warning_yes"))
			reset_btn_accept.DoClick = function() RunConsoleCommand("lidarscanner_clearallscans","") popup_window:Close() end
			local reset_btn_cancel = vgui.Create("DButton",popup_window)
			reset_btn_cancel:SetPos(164,64)
			reset_btn_cancel:SetSize(64,64)
			reset_btn_cancel:SetText(lgphrase("#lidarscanner_warning_no"))
			reset_btn_cancel.DoClick = function() popup_window:Close() end
		end)
		button(frame,574,94,64,32,lgphrase("#lidarscanner_binds"),function() RunConsoleCommand("lidarscanner_openbindsmenu","") end)
		button(frame,542,126,96,32,lgphrase("#lidarscanner_extensions"),function() RunConsoleCommand("lidarscanner_openextmenu","") end)
		button(frame,382,158,128,32,lgphrase("#lidarscanner_rebuildfromsaved"),function()
			if input.IsKeyDown(KEY_LSHIFT) then
				RunConsoleCommand("lidarscanner_rebuildfromsaved","")
				return
			end
			local popup_window = vgui.Create("DFrame")
			popup_window:SetSize(256,160)
			popup_window:Center()
			popup_window:SetTitle(lgphrase("#lidarscanner_warning"))
			popup_window:MakePopup()
			popup_window:SetDraggable(false)
			local label = vgui.Create("DLabel",popup_window)
			label:SetText(lgphrase("#lidarscanner_rebuildfromsaved_warning") .. "\n (lidarscanner_rebuildfromsaved)")
			label:SizeToContents()
			local lw = label:GetSize()
			label:SetPos(128-(lw/2),30)
			local reset_btn_accept = vgui.Create("DButton",popup_window)
			reset_btn_accept:SetPos(32,122)
			reset_btn_accept:SetSize(32,32)
			reset_btn_accept:SetText(lgphrase("#lidarscanner_warning_yes"))
			reset_btn_accept.DoClick = function() RunConsoleCommand("lidarscanner_rebuildfromsaved","") popup_window:Close() end
			local reset_btn_cancel = vgui.Create("DButton",popup_window)
			reset_btn_cancel:SetPos(164,96)
			reset_btn_cancel:SetSize(64,64)
			reset_btn_cancel:SetText(lgphrase("#lidarscanner_warning_no"))
			reset_btn_cancel.DoClick = function() popup_window:Close() end
		end)
		button(frame,510,158,128,32,lgphrase("#lidarscanner_saveloadmenu"),function() RunConsoleCommand("lidarscanner_opensaveloadmenu","")end)
		button(frame,510,190,128,32,lgphrase("#lidarscanner_resetsettings"),function()
			local popup_window = vgui.Create("DFrame")
			popup_window:SetSize(256,128)
			popup_window:Center()
			popup_window:SetTitle(lgphrase("#lidarscanner_warning"))
			popup_window:MakePopup()
			popup_window:SetDraggable(false)
			local label = vgui.Create("DLabel",popup_window)
			label:SetPos(30,30)
			label:SetText(lgphrase("#lidarscanner_resetsettings_warning") .. "\n (lidarscanner_resetconvars)")
			label:SizeToContents()
			local lw = label:GetSize()
			label:SetPos(128-(lw/2),30)
			local reset_btn_accept = vgui.Create("DButton",popup_window)
			reset_btn_accept:SetPos(32,90)
			reset_btn_accept:SetSize(32,32)
			reset_btn_accept:SetText(lgphrase("#lidarscanner_warning_yes"))
			reset_btn_accept.DoClick = function() RunConsoleCommand("lidarscanner_resetconvars","") popup_window:Close() end
			local reset_btn_cancel = vgui.Create("DButton",popup_window)
			reset_btn_cancel:SetPos(164,64)
			reset_btn_cancel:SetSize(64,64)
			reset_btn_cancel:SetText(lgphrase("#lidarscanner_warning_no"))
			reset_btn_cancel.DoClick = function() popup_window:Close() end
		end)
		button(frame,510,222,128,32,lgphrase("#lidarscanner_scanlinescolour"),function() RunConsoleCommand("lidarscanner_openscanlinesmenu","") end)

		headertext(frame,280,105,lgphrase("#lidarscanner_burstscan"))
		
		checkbox(frame,282,120,lgphrase("#lidarscanner_burstscan_rotated"),"lidarscanner_burstscan_direction")
		checkbox(frame,282,135,lgphrase("#lidarscanner_burstscan_reverse"),"lidarscanner_burstscan_reverse")
		checkbox(frame,282,150,lgphrase("#lidarscanner_burstscan_180scan"),"lidarscanner_burstscan_180scan")
		checkbox(frame,282,165,lgphrase("#lidarscanner_burstscan_360scan"),"lidarscanner_burstscan_360scan")
		--
		helptext(frame,382,120,lgphrase("#lidarscanner_burstscan_type"))
		local burstscan_type = combobox(frame,382,135,128,20,"",function(_,_,_,val)
			setcvarnum("lidarscanner_burstscan_type",val)
		end)
		burstscan_type:AddChoice(lgphrase("#lidarscanner_burstscan_type_normal"),0)
		burstscan_type:AddChoice(lgphrase("#lidarscanner_burstscan_type_interleaved"),1)
		burstscan_type:AddChoice(lgphrase("#lidarscanner_burstscan_type_crossed"),2)
		if getcvarnum("lidarscanner_burstscan_type") == 0 then
			burstscan_type:SetValue(lgphrase("#lidarscanner_burstscan_type_normal"))
		elseif getcvarnum("lidarscanner_burstscan_type") == 1 then
			burstscan_type:SetValue(lgphrase("#lidarscanner_burstscan_type_interleaved"))
		elseif getcvarnum("lidarscanner_burstscan_type") == 2 then
			burstscan_type:SetValue(lgphrase("#lidarscanner_burstscan_type_crossed"))
		end

		headertext(frame,280,180,lgphrase("#lidarscanner_other"))

		checkbox(frame,282,195,lgphrase("#lidarscanner_weaponhud"),"lidarscanner_hud_enabled")
		checkbox(frame,282,210,lgphrase("#lidarscanner_optimize_visible"),"lidarscanner_optimize_visible")
		checkbox(frame,282,225,lgphrase("#lidarscanner_optimize_colour"),"lidarscanner_optimize_colour")
		checkbox(frame,282,240,lgphrase("#lidarscanner_glitch"),"lidarscanner_glitch_enabled")
		checkbox(frame,390,195,lgphrase("#lidarscanner_prescan_functions"),"lidarscanner_prescan_enabled")
		checkbox(frame,390,210,lgphrase("#lidarscanner_postscan_functions"),"lidarscanner_postscan_enabled")
		checkbox(frame,390,225,lgphrase("#lidarscanner_savedots"),"lidarscanner_savedots")
		checkbox(frame,390,240,lgphrase("#lidarscanner_seeker"),"lidarscanner_sv_seeker_enabled")

		headertext(frame,5,30,lgphrase("#lidarscanner_general"))

		checkbox(frame,7,45,lgphrase("#lidarscanner_enabled"),"lidarscanner_enabled")
		checkbox(frame,7,60,lgphrase("#lidarscanner_blindness_enabled"),"lidarscanner_background_enabled")
		checkbox(frame,7,75,lgphrase("#lidarscanner_mirror_enabled"),"lidarscanner_mirror_enabled")
		checkbox(frame,9,90,lgphrase("#lidarscanner_mirror_input"),"lidarscanner_mirror_input_enabled","lidarscanner_mirror_enabled")

		headertext(frame,5,105,lgphrase("#lidarscanner_scan"))

		button(frame,10,120,200,15,lgphrase("#lidarscanner_dot_shape") .. LidarScanner_GetScannedDotMaterialName(),
			function() RunConsoleCommand("lidarscanner_opendotmenu","") end)
		slider(frame,10,135,200,lgphrase("#lidarscanner_dot_size"),"lidarscanner_dotsize",1)
		slider(frame,10,150,200,lgphrase("#lidarscanner_maxdots"),"lidarscanner_maxdots",0)
		slider(frame,10,165,200,lgphrase("#lidarscanner_maxmeshes"),"lidarscanner_maxmeshes",0)
		checkbox(frame,7,180,lgphrase("#lidarscanner_nohitsky"),"lidarscanner_nohitsky")
		
		headertext(frame,5,195,lgphrase("#lidarscanner_viewmodel"))

		slider(frame,10,210,200,lgphrase("#lidarscanner_viewmodel_blurscale"),"lidarscanner_viewmodel_blurscale",2)
		slider(frame,10,225,200,lgphrase("#lidarscanner_viewmodel_farscale"),"lidarscanner_viewmodel_farscale",2)

		headertext(frame,196,30,lgphrase("#lidarscanner_fastscan"))

		slider(frame,199,45,300,lgphrase("#lidarscanner_fastscan_size"),"lidarscanner_scansize",1)
		slider(frame,199,60,300,lgphrase("#lidarscanner_fastscan_bind_size_delta"),"lidarscanner_scansize_sizediff",1)
		checkbox(frame,196,75,lgphrase("#lidarscanner_fastscan_size_scroll"),"lidarscanner_scansize_scrollinput")
		slider(frame,199,90,300,lgphrase("#lidarscanner_fastscan_dotsperscan"),"lidarscanner_dotsperfastscan",0)

		checkbox(frame,564,27,lgphrase("#lidarscanner_developer"),"lidarscanner_developer")
		-- Language selection menu
		if (args[1] ~= "skiplang") and (getcvarstr("lidarscanner_language") == "") then
			local langmenu = vgui.Create("DFrame")
			langmenu:SetSize(202,128)
			langmenu:Center()
			langmenu:SetTitle("")
			langmenu:MakePopup()
			langmenu:SetDraggable(false)
			langmenu.Paint = function(self,w,h)
				draw.RoundedBox(6,0,0,w,h,Color(10,10,10))
				draw.RoundedBox(6,1,1,w-2,h-2,Color(127,127,127))
				draw.RoundedBoxEx(6,0,0,w,25,Color(55,55,55),true,true,false,false)
				draw.SimpleText("Lidar Scanner","DermaDefault",5,5,Color(200,255,200),0,3)
			end
			local combobox = combobox(langmenu,5,30,192,20,LSL.GetLanguages()[LSL.GetCurrentLanguage()],nil)
			for k,v in pairs(LSL.GetLanguages()) do
				combobox:AddChoice(v,k)
			end
			button(langmenu,69,96,64,24,"OK",function()
				local _,lname = combobox:GetSelected()
				LSL.SetCurrentLanguage(lname)
				langmenu:Close()
				frame:Close()
				RunConsoleCommand("lidarscanner_openmenu","skiplang")
			end)
		end
	end)
	hook.Add("PopulateToolMenu","LidarScanner2ToolOption",function()
	    spawnmenu.AddToolMenuOption("Utilities","User","LidarScanner2","#LidarScanner2","","",function(panel)
	        panel:ClearControls()
	        local menubutton = vgui.Create("DButton",panel)
	        menubutton:Dock(TOP)
	        menubutton:SetText("Menu")
	        menubutton.DoClick = function()
	            RunConsoleCommand("lidarscanner_openmenu")
	        end
	        local svmenubutton = vgui.Create("DButton",panel)
	        svmenubutton:Dock(TOP)
	        svmenubutton:SetText("SV Menu")
	        svmenubutton.DoClick = function()
	            RunConsoleCommand("lidarscanner_opensvmenu")
	        end
	    end)
	end)
end
