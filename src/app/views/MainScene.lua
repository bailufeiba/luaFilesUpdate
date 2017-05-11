cc.exports.UpdateSystem = require("app.UpdateSystem" )

local MainScene = class("MainScene", cc.load("mvc").ViewBase)

function MainScene:onCreate()
    -- add background image
    display.newSprite("HelloWorld.png")
        :move(display.center)
        :addTo(self)

    -- add HelloWorld label
    cc.Label:createWithSystemFont("Hello World", "Arial", 40)
        :move(display.cx, display.cy + 200)
        :addTo(self)

    self:StartUpdate()
end

function MainScene:StartUpdate()
    local us = UpdateSystem:Create()
    us:SetUpdateProgressCallback( handler( self, self.UpdateProgress ) )
    us:SetUpdateDoneCallback( handler( self, self.UpdateDone ) )
    us:SetUpdateErrorCallback( handler( self, self.UpdateError ) )
    us:StartUpdate( "UpdateTotal.ver", "UpdateFileList.ver" )
end

function MainScene:UpdateProgress( currSize, totalSize )
    print( "MainScene:UpdateProgress "..currSize.."/"..totalSize )
end

function MainScene:UpdateDone()
    print( "MainScene:UpdateDone" )
end

function MainScene:UpdateError( err )
    dump( err, "MainScene:UpdateError err" )
end

return MainScene
