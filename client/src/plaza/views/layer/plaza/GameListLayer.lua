-- 游戏列表
local GameListLayer = class("GameListLayer", ccui.ScrollView)

local ClientUpdate = appdf.req(appdf.BASE_SRC.."app.controllers.ClientUpdate")

local ExternalFun = appdf.req(appdf.EXTERNAL_SRC .. "ExternalFun")

local QueryDialog = appdf.req(appdf.BASE_SRC .. "app.views.layer.other.QueryDialog")

function GameListLayer:ctor(scene)
	print("============= 游戏列表界面创建 =============")

    self._scene = scene

    self:setDirection(ccui.ScrollViewDir.vertical)--(ccui.ScrollViewDir.horizontal)
    self:setScrollBarEnabled(false)
    self:setBounceEnabled(true)
    self._isClickGame = false
end

--------------------------------------------------------------------------------------------------------------------
-- 功能方法

--更新游戏列表
function GameListLayer:updateGameList(gamelist)

    print("更新游戏列表")
    
    --保存游戏列表
    self._gameList = gamelist

    --清空子视图
    self:removeAllChildren()

    if #gamelist == 0 then
        return
    end
    
    --设置内容高度
    local contentSize = self:getContentSize()
    local iconCX            =   231
    local iconCY            =   241
    local spacing           =   20
    local columns           =   3
    local lines             =   math.ceil( #gamelist / columns )
    local containerWidth    =   contentSize.width
    local containerHeight   =   lines * iconCY + (lines - 1) * spacing - 35

    --判断容器高度是否小于最小高度
    if containerHeight < contentSize.height then
        containerHeight = contentSize.height
    end
    self:setInnerContainerSize(cc.size(containerWidth, containerHeight))

    for i = 1, #gamelist do
         local row       =   math.floor( (i - 1) / columns )
        local col       =   (i - 1) % columns
        local x         =   col * spacing + (col + 0.5) * iconCX
        local y         =   containerHeight - (row + (row + 0.5) * iconCY)
        --游戏图标
        local filestr = "GameList/game_"..gamelist[i]..".png"
        --游戏图标按钮
        local btnGameIcon = ccui.Button:create(filestr, filestr, filestr)
        btnGameIcon:setPosition(cc.p(x,y))
        btnGameIcon:setTag(gamelist[i]) --游戏KindID做为Tag
        btnGameIcon:addTo(self)
--        btnGameIcon:addTouchEventListener(function(ref, type)

--            --改变按钮点击颜色
--            if type == ccui.TouchEventType.began then
--                ref:setColor(cc.c3b(200, 200, 200))
--            elseif type == ccui.TouchEventType.ended or ccui.TouchEventType.canceled then
--                ref:setColor(cc.WHITE)
--            end
--        end)
        btnGameIcon:addClickEventListener(function()
            if not self._isClickGame then
                self._isClickGame = true
                self:onClickGame(self._gameList[i])
            end
        end)
    end
    --滚动的到前面
    self:jumpToTop()
end

--下载游戏
function GameListLayer:downloadGame(gameinfo)

    if self._updategame then
        showToast(nil, "正在更新 “" .. self._updategame._GameName .. "” 请稍后", 2)
        return
    end

    --保存更新的游戏
    self._updategame = gameinfo

    local app = self._scene:getApp()
    --写死  多渠道下载游戏 走同一个地址
    local updateUrl
    if appdf.ENV == 2 then                  --正式服
        updateUrl= "http://cdn.game217.com/Download/Phone"
    elseif appdf.ENV == 4 then              --内网
        updateUrl= "http://192.168.31.81/Download/Phone"
    else                                    --正式服
        updateUrl= "http://cdn.game217.com/Download/Phone"        
    end

     if  appdf.isErrorLogin == true then
        updateUrl = "http://game217.oss-cn-hangzhou.aliyuncs.com/Download/Phone"
     end

    --local updateUrl = app:getUpdateUrl()--"http://game217.oss-cn-hangzhou.aliyuncs.com/qipai/land.zip"

    --下载地址
    local fileurl = updateUrl .. "/game/" .. string.sub(gameinfo._Module, 1, -2) .. ".zip"
    print(fileurl)
    --文件名
    local pos = string.find(gameinfo._Module, "/")
    local savename = string.sub(gameinfo._Module, pos + 1, -2) .. ".zip"
    --保存路径
    local savepath = nil
    local unzippath = nil
	local targetPlatform = cc.Application:getInstance():getTargetPlatform()
	if cc.PLATFORM_OS_WINDOWS == targetPlatform then
		savepath = device.writablePath .. "download/game/" .. gameinfo._Type .. "/"
        unzippath = device.writablePath .. "game/" .. gameinfo._Type .. "/"
    else
        savepath = device.writablePath .. "game/" .. gameinfo._Type .. "/"
        unzippath = device.writablePath .. "game/" .. gameinfo._Type .. "/"
	end

    print("savepath: " .. savepath)
    print("savename: " .. savename)
    print("unzippath: " .. unzippath)
    self:showGameProgress(gameinfo._KindID, 0)
    --下载游戏压缩包
    downFileAsync(fileurl, savename, savepath, function(main, sub)

        --对象已经被销毁
        if not appdf.isObject(self) then
            return
        end

		--下载回调
		if main == appdf.DOWN_PRO_INFO then --进度信息
			print(sub)
            self:showGameProgress(gameinfo._KindID, sub)

		elseif main == appdf.DOWN_COMPELETED then --下载完毕

            local zipfile = savepath .. savename

            --解压
            unZipAsync(zipfile, unzippath, function(result)
				
                --删除压缩文件
                os.remove(zipfile)

                --清空正在更新的游戏状态
                self._updategame = nil

                self:hideGameProgress(gameinfo._KindID)

                if result == 1 then
                    --保存版本记录
                    app:getVersionMgr():setResVersion(gameinfo._ServerResVersion, gameinfo._KindID)

                    showToast(nil, "“" .. gameinfo._GameName .. "” 下载完毕", 2)
                    --播放音效
                    self:playFinishEffect()
                    self:OnEnterGame(gameinfo)
                else
                    showToast(nil, "“" .. gameinfo._GameName .. "” 解压失败", 2)
                    self._isClickGame = false
                end

			end)

		else

            --清空正在更新的游戏状态
            self._updategame = nil

            self:hideGameProgress(gameinfo._KindID)

            showToast(nil, "“" .. gameinfo._GameName .. "” 下载失败，错误码：" ..main, 2)

            self._isClickGame = false

		end
	end)
end


-- 自动进入            
function GameListLayer:OnEnterGame(gameinfo)

     --获取房间列表                        
    local roomList = GlobalUserItem.roomlist[tonumber(gameinfo._KindID)]
    local roomCount = roomList and #roomList or 0
    dump(roomList)
    local myScore = tonumber(GlobalUserItem.lUserScore)
    
    if roomCount == 0 then
        showToast(nil, "抱歉，游戏房间暂未开放，请稍后再试！", 2)
        self._isClickGame = false
        return 
    end
   
    --判断金币是否满足进入最低的房间
    if myScore < roomList[1].lEnterScore and GlobalUserItem.getRoomCount(tonumber(gameinfo._KindID)) == 1 then
        local str = "进入游戏失败\n抱歉，您的游戏成绩低于当前游戏的最低进入成绩"..tostring(roomList[1].lEnterScore).."，不能进入当前游戏!"
        QueryDialog:create(str, function()
            self._scene:onShowShop()
            end, nil, QueryDialog.QUERY_SURE)
                            :addTo(self._scene)
        self._isClickGame = false                  
        return
    end

    local retRommCount = roomCount > 1 and true or false

    if retRommCount == true then

        self:OnAutoGame(gameinfo,false)

    else
     -- 直接进入游戏
        if gameinfo._KindID ~= tostring(516) and gameinfo._KindID ~= tostring(601) and gameinfo._KindID ~= tostring(19) then
            self._scene._roomLayer:GameLoadingView(tonumber(gameinfo._KindID))
        end
        self:OnAutoGame(gameinfo,true)
    end 
    
end


--进入房间
--更新游戏
function GameListLayer:OnAutoGame(gameinfo,bAutoGame)

   --根据分数判断适合加入哪个房间
    local myScore = tonumber(GlobalUserItem.lUserScore)
     
     --获取房间列表                        
    local roomList = GlobalUserItem.roomlist[tonumber(gameinfo._KindID)]
    local roomCount = roomList and #roomList or 0
    

    local wServerID = nil
    
    table.sort(roomList,function(a,b)
            return a.lEnterScore < b.lEnterScore
            end)
    if roomCount > 0 then
        --if myScore >= roomList[1].lEnterScore then
            wServerID = roomList[1].wServerID
        --end
    else
        return
    end
    for k, v in pairs(roomList) do 
        if myScore >= v.lEnterScore then
            wServerID = v.wServerID
        end
    end

    if bAutoGame == false then
        self._scene:onClickGame(tonumber(gameinfo._KindID))--OnAutoGameHide()
    end
    self._scene._bIsQuickStart = bAutoGame;
   -- self._roomListLayer:showRoomList(tonumber(gameinfo._KindID))

    self._scene:onOuatGameLIst(tonumber(gameinfo._KindID),true)
    if bAutoGame then
        self._scene:onClickRoom(wServerID, tonumber(gameinfo._KindID))
    end
end

--更新游戏
function GameListLayer:updateGame(gameinfo)

    if self._updategame then
        showToast(nil, "正在更新 “" .. self._updategame._GameName .. "” 请稍后", 2)
        return
    end

    --保存更新的游戏
    self._updategame = gameinfo

    local app = self._scene:getApp()
    local updateUrl
    if appdf.ENV == 2 then                  --正式服
        updateUrl= "http://cdn.game217.com/Download/Phone"
    elseif appdf.ENV == 4 then              --内网
        updateUrl= "http://192.168.31.81/Download/Phone"
    else                                    --正式服
        updateUrl= "http://cdn.game217.com/Download/Phone"        
    end
    
    local newfileurl = updateUrl.."/game/"..gameinfo._Module.."res/filemd5List.json"
    local src = nil
	local dst = nil
	local targetPlatform = cc.Application:getInstance():getTargetPlatform()
	if cc.PLATFORM_OS_WINDOWS == targetPlatform then
        dst = device.writablePath .. "game/" .. gameinfo._Type .. "/"
        src = device.writablePath.."game/"..gameinfo._Module.."res/filemd5List.json"
    else
        dst = device.writablePath .. "game/" .. gameinfo._Type .. "/"
        src = device.writablePath.."game/"..gameinfo._Module.."res/filemd5List.json"
	end

	local downurl = updateUrl .. "/game/" .. gameinfo._Type .. "/"

	--创建更新
	self._update = ClientUpdate:create(newfileurl,dst,src,downurl)
	self._update:upDateClient(self)
end

--显示游戏进度
function GameListLayer:showGameProgress(wKindID, nPercent)

    --游戏图标
    local gameicon = self:getChildByTag(wKindID)
    if not gameicon then
        return
    end

    local contentSize = gameicon:getContentSize()

    --遮罩
    local mask = gameicon:getChildByTag(1)
    if mask == nil then

        mask = ccui.Layout:create()
                    :setClippingEnabled(true)
                    :setAnchorPoint(cc.p(0, 0))
                    :setPosition(0, 0)
                    :setTag(1)
                    :addTo(gameicon)

        gameicon:clone()
                    :setColor(cc.c3b(150, 150, 150))
                    :setAnchorPoint(cc.p(0, 0))
                    :setPosition(0, 0)
                    :addTo(mask)
    end

    mask:setContentSize(contentSize.width, contentSize.height * (100 - nPercent) / 100)

    --进度
    local progress = gameicon:getChildByTag(2)
    if progress == nil then
        progress = cc.Label:createWithTTF("0%", "fonts/round_body.ttf", 32)
                        :enableOutline(cc.c4b(0,0,0,255), 1)
                        :setPosition(contentSize.width / 2, contentSize.height / 2)
                        :setTag(2)
                        :addTo(gameicon)
    end

    if nPercent == 100 then 
        progress:setString("正在安装...")
    else
        progress:setString(nPercent .. "%")
    end
end

--隐藏游戏进度
function GameListLayer:hideGameProgress(wKindID)

    --游戏图标
    local gameicon = self:getChildByTag(wKindID)
    if not gameicon then
        return
    end

    gameicon:removeAllChildren()
end

--播放完成音效
function GameListLayer:playFinishEffect()
    --播放音效
    ExternalFun.playPlazaEffect("gameDownFinish.mp3")   
end
--------------------------------------------------------------------------------------------------------------------
-- 事件处理

--点击游戏
function GameListLayer:onClickGame(wKindID)

    print("点击游戏图标", wKindID)

    --播放按钮音效
    ExternalFun.playClickEffect()

    local app = self._scene:getApp()

    --判断游戏是否存在
    local gameinfo = app:getGameInfo(wKindID)
    if not gameinfo then 
        showToast(nil, "大爷，人家还没准备好呢！", 2)
        self._isClickGame = false
        return
    end

    if LOCAL_DEVELOP == 1 then
        --判断是否开放房间
        if GlobalUserItem.getRoomCount(wKindID) == 0 then
            showToast(nil, "抱歉，游戏房间暂未开放，请稍后再试！", 2)
            self._isClickGame = false
            return
        end

        --通知进入游戏类型
        if self._scene and self._scene.onClickGame then
            self._scene:onClickGame(wKindID)
        end
    else
        local version = tonumber(app:getVersionMgr():getResVersion(gameinfo._KindID))
        if version == nil then --下载游戏

            self:downloadGame(gameinfo)

        elseif gameinfo._ServerResVersion > version then --更新游戏

            self:updateGame(gameinfo)

        else
            --判断是否开放房间
            if GlobalUserItem.getRoomCount(wKindID) == 0 then
                showToast(nil, "抱歉，游戏房间暂未开放，请稍后再试！", 2)
                self._isClickGame = false
                return
            end
            --根据房间数判断进入游戏还是进入房间列表
            if GlobalUserItem.getRoomCount(wKindID) == 1 then
                --直接进入游戏
                self:OnEnterGame(gameinfo)
            else
                --通知进入游戏类型
                if self._scene and self._scene.onClickGame then
                    self._scene:onClickGame(wKindID)
                end
            end
        end
    end
    
end

--------------------------------------------------------------------------------------------------------------------
-- ClientUpdate 回调

--更新进度
function GameListLayer:onUpdateProgress(sub, msg, mainpersent)
    
    if self._updategame then
        self:showGameProgress(self._updategame._KindID, math.ceil(mainpersent))
    end
end

--更新结果
function GameListLayer:onUpdateResult(result,msg)

    self:hideGameProgress(self._updategame._KindID)

    if result == true then
        msg = "“" .. self._updategame._GameName .. "” 更新完毕"

        --保存版本记录
        self._scene:getApp():getVersionMgr():setResVersion(self._updategame._ServerResVersion, self._updategame._KindID)

        --播放音效
        self:playFinishEffect()
        --自动进入游戏
        self:OnEnterGame(self._updategame)
    else
        msg = "“" .. self._updategame._GameName .. "” " .. msg
        self._isClickGame = false
    end

    --清空正在更新的游戏状态
    self._updategame = nil
    self._update = nil
    self._isClickGame = false
    showToast(nil, msg, 2)
end

return GameListLayer