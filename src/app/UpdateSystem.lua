-----author:bailufeiba 2017/5/12 2:21:11-----
require( "app.md5" )
local UpdateSystem = class( "UpdateSystem" )

local PRINT_LOG     =       true        --日志开关

local ERROR_STARTUPDATE_PARAM           =   { code=1, msg="参数错误" }
local ERROR_LOCALTOTALFILE_CONTENT      =   { code=2, msg="本地[更新总文件]内容错误" }
local ERROR_SERVERTOTALFILE_CONTENT     =   { code=3, msg="服务器[更新总文件]内容错误" }
local ERROR_NETWORK                     =   { code=4, msg="网络错误" }
local ERROR_NEEDTO_UPDATECLIENT         =   { code=5, msg="强制更新客户端", detail="这里会放置新版更新的描述" }
local ERROR_SERVER_FILELIST_CONTENT     =   { code=6, msg="服务器文件列表内容错误", detail="url" }
local ERROR_UPDATE_CALCEN               =   { code=7, msg="更新被取消" }
local ERROR_DOWNLOAD_FILE_CONTENT       =   { code=8, msg="文件内容校验错误", detail="" }
local ERROR_WRITE_FILE                  =   { code=9, msg="存储文件失败", detail="" }
local ERROR_RECORD_FILE_TO_FILELIST     =   { code=10, msg="记录文件到文件列表失败", detail="" }
local ERROR_FILE_RENAME                 =   { code=11, msg="文件重命名失败", detail="" }
local ERROR_FILE_NOT_EXIST              =   { code=12, msg="文件不存在", detail="" }
local ERROR_RECORD_TOTAL                =   { code=13, msg="记录更新总文件失败" }

local DEFAULT_VERSION_SIZE          =       4       --版本段位数 比如:1.0.0.0是4段数 , 注意:版本号仅支持数字
local DOWNLOAD_FILE_SUFFIX          =       ".updtmp"

function UpdateSystem:Create()
    return self.new(self)
end

function UpdateSystem:Cancel()
    self.bUpdateContinue = false
end

function UpdateSystem:SetUpdateProgressCallback( func )
    self.UpdateProgressCallback = func
end

function UpdateSystem:SetUpdateDoneCallback( func )
    self.UpdateDoneCallback = func
end

function UpdateSystem:SetUpdateErrorCallback( func )
    self.UpdateErrorCallback = func
end

--更新入口  localFilePath:本地更新文件(UpdateTotal.ver)的相对路径
--localFileList:本地文件列表
function UpdateSystem:StartUpdate( localFilePath, localFileListPath )
    self:ResetAll()
    self.localTotalFilePath = localFilePath
    self.localFileListPath = localFileListPath
    
    self:LoadTotalUpdateFile( localFilePath )
    self:RequestServerTotalUpdateFile()
end

function UpdateSystem:ResetAll()
    
end

------------读取本地[更新总文件]------------
function UpdateSystem:LoadTotalUpdateFile( localFilePath )
    self:PrintLog( "读取本地[更新总文件]" )
    self:ResetCUpdateTotal()

    local data = ""
    local path = cc.FileUtils:getInstance():getWritablePath()..localFilePath   --防呆
    if cc.FileUtils:getInstance():isFileExist( path ) then
        data = cc.FileUtils:getInstance():getStringFromFile( path )
    else
        data = cc.FileUtils:getInstance():getStringFromFile( localFilePath )
    end
    
    if type(data) ~= "string" or data == "" or data == nil then
        self:ErrorUpdate( ERROR_LOCALTOTALFILE_CONTENT )
        return
    end
    
    local jsData = json.decode(data)
    if self:CheckLocalFileData(jsData) ~= true then
        self:ErrorUpdate( ERROR_LOCALTOTALFILE_CONTENT )
        return
    end

    self.tbCUpdateTotal.md5 = jsData.md5
    self.tbCUpdateTotal.currversion = jsData.currversion
    self.tbCUpdateTotal.compulsive = jsData.compulsive or false
    self.tbCUpdateTotal.url = jsData.url
end

function UpdateSystem:ResetCUpdateTotal()
    self.tbCUpdateTotal = {}
    self.tbCUpdateTotal.md5 = ""
    self.tbCUpdateTotal.currversion = "1.0.0"
    self.tbCUpdateTotal.compulsive = false
    self.tbCUpdateTotal.url = ""
end

function UpdateSystem:CheckLocalFileData( tb )
    if type(tb) ~= "table" then return false end
    if type(tb.md5) ~= "string" or tb.md5 == "" then return false end
    if type(tb.url) ~= "string" or tb.url == "" then return false end
    if type(tb.currversion) ~= "string" or tb.currversion == "" then return false end
    return true
end



------------请求服务器[更新总文件]------------
function UpdateSystem:RequestServerTotalUpdateFile()
    self:PrintLog( "正在请求服务器更新总文件" )
    self:ResetSUpdateTotal()
    self:HttpRequest( self.tbCUpdateTotal.url, handler(self, self.OnServerTotalResponse) ) 
end

function UpdateSystem:ResetSUpdateTotal()
    self.tbSUpdateTotal = {}
    self.tbSUpdateTotal.md5 = ""
    self.tbSUpdateTotal.compulsive = false
    self.tbSUpdateTotal.url = ""
    self.tbSUpdateTotal.desc = ""
end

function UpdateSystem:OnServerTotalResponse()
    self:PrintLog( "收到[更新总文件]的响应 状态:"..self.xhr.readyState )    
    self.xhr:unregisterScriptHandler()
    
    if self.xhr.readyState == 4 and (self.xhr.status >= 200 and self.xhr.status < 207) then
        self:ResetSUpdateTotal()
        
        local jsData = json.decode( self.xhr.response )
        if jsData == nil then return end
        if self:CheckServerTotalData(jsData) ~= true then
            self:ErrorUpdate(ERROR_SERVERTOTALFILE_CONTENT)
            return
        end
        
        self.tbSUpdateTotal = clone( jsData )
        self.tbSUpdateTotal.md5 = jsData.md5
        self.tbSUpdateTotal.currversion = jsData.currversion
        self.tbSUpdateTotal.lastversion = jsData.lastversion
        self.tbSUpdateTotal.compulsive = jsData.compulsive
        self.tbSUpdateTotal.url = jsData.url
        self.tbSUpdateTotal.desc = jsData.desc or ""
        
        self:CheckUpdate()
    elseif self.xhr.readyState == 1 and self.xhr.status == 0 then
        self:ErrorUpdate( ERROR_NETWORK )
    end
end

function UpdateSystem:CheckServerTotalData( tb )
    if type(tb) ~= "table" then return false end
    if type(tb.md5) ~= "string" or tb.md5 == "" then return false end
    if type(tb.url) ~= "string" or tb.url == "" then return false end
    if type(tb.currversion) ~= "string" or tb.currversion == "" then return false end
    if type(tb.lastversion) ~= "string" or tb.lastversion == "" then return false end
    if type(tb.compulsive) ~= "boolean" then return false end
    return true
end

function UpdateSystem:HttpRequest( url, func )
    if self.xhr == nil then
        self.xhr = cc.XMLHttpRequest:new()
        self.xhr:retain()
    end
    self.xhr.timeout = 30 -- 设置超时时间
    self.xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON
    self.xhr:open("GET", url )
    self.xhr:registerScriptHandler( func )
    self.xhr:send()    
end



------------对比本地更新总文件和服务器更新总文件------------
function UpdateSystem:CheckUpdate()
    self:PrintLog( "对比本地MD5和服务器MD5" )
    
    --对比总更新的MD5
    if self.tbCUpdateTotal.md5 == self.tbSUpdateTotal.md5 then
        self:UpdateDone()
        return
    end
    
    --如果需要强更
    if self.tbSUpdateTotal.compulsive then
        self:PrintLog( "检测到需要强制更新" )
        self:RemoveAllDownloadFile()
        ERROR_NEEDTO_UPDATECLIENT.detail = self.tbSUpdateTotal.desc
        self:ErrorUpdate( ERROR_NEEDTO_UPDATECLIENT )
        return
    end

    --客户端版本低于上次强更版本
    local nv = self:CompareVersion( self.tbCUpdateTotal.currversion, self.tbSUpdateTotal.lastversion, DEFAULT_VERSION_SIZE )
    if nv < 0 then
        self:PrintLog( "检测到需要强制更新" )
        self:RemoveAllDownloadFile()        
        ERROR_NEEDTO_UPDATECLIENT.detail = self.tbSUpdateTotal.desc
        self:ErrorUpdate( ERROR_NEEDTO_UPDATECLIENT )
        return
    end

    --开始对比文件列表
    self:StartCompareFileList()
end

--比较两个版本    版本格式 1.0.0.0
--如果version和oldVersion相同,则返回0
--如果version比oldVersion高,则返回1
--如果version比oldVersion低,则返回-1
function UpdateSystem:CompareVersion( version, oldVersion, len )
    if version == oldVersion then return 0 end

    if len == nil then len = 4 end
    local tbV = self:GetVersionTable( version, len )
    local tbOldV = self:GetVersionTable( oldVersion, len )

    for i=1,len do
        if tbV[i] > tbOldV[i] then
            return 1
        end
    end

    return -1
end

function UpdateSystem:GetVersionTable( version, size )
    local tb = {}
    local tbStr = string.split( version, "." )
    for i=1,size do
        if tbStr[i] ~= nil then
            local n = tonumber( tbStr[i] )
            if n ~= nil then
                table.insert( tb, n )
            else
                table.insert( tb, 0 )
            end            
        else
            table.insert( tb, 0 )
        end        
    end
    return tb
end

function UpdateSystem:StartCompareFileList()
    self.bUpdateContinue = true
    self:LoadClientFileList()
    self:RequestServerFileList()
    --self:LoadServerFileList()
end

function UpdateSystem:LoadClientFileList()
    self:PrintLog( "读取本地文件列表" )
    local data = ""
    local path = cc.FileUtils:getInstance():getWritablePath()..self.localFileListPath --防呆
    if cc.FileUtils:getInstance():isFileExist(path) then
        data = cc.FileUtils:getInstance():getStringFromFile( path )
    else
        data = cc.FileUtils:getInstance():getStringFromFile( self.localFileListPath )    
    end    
    self.tbCFileList = json.decode(data)    
end

function UpdateSystem:RequestServerFileList()
    self:PrintLog( "正在请求服务器文件列表" )
    self:HttpRequest( self.tbSUpdateTotal.url, handler(self, self.OnServerFileListResponse) )   
end

function UpdateSystem:OnServerFileListResponse()
    self:PrintLog( "收到文件列表的响应 状态:"..self.xhr.readyState )        
    self.xhr:unregisterScriptHandler()
    
    if self.xhr.readyState == 4 and (self.xhr.status >= 200 and self.xhr.status < 207) then    
        local jsData = json.decode( self.xhr.response )
        if self:CheckServerFileList(jsData) ~= true then
            self:ErrorUpdate( ERROR_SERVER_FILELIST_CONTENT )
            return 
        end
        
        self.FileDownloadURL = jsData[ "url" ]
        jsData[ "url" ] = nil
        
        self.tbSFileList = clone(jsData)
        self:GetUpdateFileList()
    elseif self.xhr.readyState == 1 and self.xhr.status == 0 then
        self:ErrorUpdate( ERROR_NETWORK )
    end
end

function UpdateSystem:CheckServerFileList( tb )
    if type(tb) ~= "table" then return false end
    if type(tb["url"]) ~= "string" then return false end
    return true
end

function UpdateSystem:GetUpdateFileList()
    self:PrintLog( "正在对比本地文件列表和服务器文件列表" )
    self.tbUpdateList = {}
    self.CurrSize = 0
    self.UpdateSize = 0
    
    self:CompareList( "", self.tbSFileList, self.tbCFileList )
    self.tbUpdateListTmp = clone(self.tbUpdateList)
    --    dump( self.UpdateSize, "UpdateSize" )
    --    dump( self.tbUpdateList, "tbUpdateList" )
    
    self:UpdateProgresses()
    self:DownloadNext()
end

function UpdateSystem:CompareList( dir, tbSList, tbCList )
    if type(tbSList) ~= "table" then return end
    if type(tbCList) ~= "table" then return end

    if tbSList["MD5"] ~= nil then
        if tbSList["MD5"] ~= tbCList["MD5"] then
            self:AddFileList( dir, tbSList, self.tbUpdateList )
        end
        return
    end

    for k,tb in pairs(tbSList) do
        if type(tb) == "table" then
            local path = dir
            if path ~= "" then path = path .. "/" end
            path = path .. k
            if tbCList[ k ] == nil then
                self:AddFileList( path, tb, self.tbUpdateList )
            else
                self:CompareList( path, tb, tbCList[ k ] )
            end            
        end
    end
end

function UpdateSystem:AddFileList( dir, tbList, tbUpdateList )
    if type(tbList) ~= "table" then return end
    if type(tbUpdateList) ~= "table" then return end

    if tbList["MD5"] ~= nil then
        local t = {}
        t.file = dir
        t.md5 = tbList["MD5"] or ""
        t.size = tbList[ "size" ] or 0
        table.insert( tbUpdateList, t )
        if self.UpdateSize == nil then self.UpdateSize = 0 end 
        self.UpdateSize = self.UpdateSize + t.size
        return
    end

    for k,tb in pairs( tbList ) do
        if type(tb) == "table" then
            local path = dir
            if path ~= "" then path = path .. "/" end
            path = path .. k
            self:AddFileList( path, tb, tbUpdateList )
        end
    end
end



------------下载文件------------
function UpdateSystem:DownloadNext()
    if self.bUpdateContinue ~= true then
        self:ErrorUpdate( ERROR_UPDATE_CALCEN )
        return
    end

    if table.nums( self.tbUpdateList ) <= 0 then
        local err = self:DownloadAllDone()
        if type(err) == "nil" then
            self:UpdateDone()
        end        
    else
        local url = self.FileDownloadURL..self.tbUpdateList[1].file
        self:HttpRequest( url, handler(self, self.OnServerFileResponse) ) 
    end
end

function UpdateSystem:OnServerFileResponse()
    self:PrintLog( "收到File的响应 状态:"..self.xhr.readyState )    
    self.xhr:unregisterScriptHandler()
    
    if self.xhr.readyState == 1 and self.xhr.status == 0 then
        self:ErrorUpdate( ERROR_NETWORK )
        return
    end
    
    if self.xhr.readyState == 4 and (self.xhr.status >= 200 and self.xhr.status < 207) then    
        self:PrintLog( "开始校验文件内容" )
        local md5code = string.upper( md5.sumhexa( self.xhr.response ) )        
        if md5code ~= string.upper(self.tbUpdateList[1].md5) then        
            if not self.nFileReDownload then self.nFileReDownload = 0 end
            if self.nFileReDownload < 3 then
                self:PrintLog( "错误的文件内容,重新下载该文件" )
                self.nFileReDownload = self.nFileReDownload + 1 
                self:DownloadNext()
                return
            end
                       
            self:PrintLog( "文件内容错误,停止下载" )
            ERROR_DOWNLOAD_FILE_CONTENT.detail = self.tbUpdateList[1].file
            self:ErrorUpdate( ERROR_DOWNLOAD_FILE_CONTENT )
            return
        end
        
        self:PrintLog( "文件内容正确" )
        self.nFileReDownload = 0
        self:SaveDownloadFile( self.tbUpdateList[1].file, self.xhr.response )
                
        self.CurrSize = self.CurrSize + string.len( self.xhr.response )
        self:UpdateProgresses()

        table.remove( self.tbUpdateList, 1 )
        self:DownloadNext()
    end
end

function UpdateSystem:DownloadAllDone()
    local err = self:ChangeAllTmpToWork()
    if err ~= nil then return err end
    
    err = self:RecordFileList()
    if err ~= nil then return err end
    
    err = self:RecordTotal()
    if err ~= nil then return err end
    
    return nil
end

function UpdateSystem:ChangeAllTmpToWork()
    for k,t in pairs( self.tbUpdateListTmp ) do
        self:ChangeOneTmpToWork( t.file )
    end
end

function UpdateSystem:ChangeOneTmpToWork( filename )
    local workname = cc.FileUtils:getInstance():getWritablePath()..filename
    local tmpname = workname .. DOWNLOAD_FILE_SUFFIX
    
    if cc.FileUtils:getInstance():isFileExist( tmpname ) then
        if cc.FileUtils:getInstance():isFileExist( workname ) then
            cc.FileUtils:getInstance():removeFile( workname )
        end
        
        local dir = self:GetFileDirectory( tmpname ).."/"
        local start = string.len(dir)+1
        local oldname = string.sub( tmpname, start )
        local name = string.sub( workname, start )        
        cc.FileUtils:getInstance():renameFile( dir, oldname, name )
        return nil
    else
        ERROR_FILE_NOT_EXIST.detail = tmpname
        return ERROR_FILE_NOT_EXIST
    end
end

function UpdateSystem:RecordFileList()
    for k,tb in pairs( self.tbUpdateListTmp ) do
        if type(tb) == "table" then
            local tbList = self.tbCFileList
            local idx = string.lastindexof( tb.file, "/" )
            if idx then
                local dir = self:GetFileDirectory( tb.file )
                local tbDir = string.split( dir, "/" )
                for k,d in pairs( tbDir ) do
                    if tbList[d] == nil then
                        tbList[d] = {}
                    end
                    tbList = tbList[d]
                end
            end

            local tf = {}
            tf["MD5"] = tb.md5
            tf["size"] = tb.size
            local name = tb.file
            if idx then name = string.sub( tb.file, idx+1 ) end
            tbList[name] = tf
         end
    end

    local path = cc.FileUtils:getInstance():getWritablePath() .. self.localFileListPath
    local data = json.encode(self.tbCFileList)
    if self:WriteFile( path, data ) == false then
        self:PrintLog( "文件列表更新失败" )
        ERROR_RECORD_FILE_TO_FILELIST.detail = "filelist"
        return ERROR_RECORD_FILE_TO_FILELIST
    end
    self:PrintLog( "文件列表更新成功" )
    return nil
end

function UpdateSystem:RecordTotal()
    local path = cc.FileUtils:getInstance():getWritablePath()..self.localTotalFilePath
    local tb = clone(self.tbSUpdateTotal)
    tb.url = self.tbCUpdateTotal.url
    if self:WriteFile( path, json.encode( tb ) ) ~= true then
        self:PrintLog( "[更新总文件]修改失败" )
        ERROR_RECORD_TOTAL.detail = path
        return ERROR_RECORD_TOTAL
    end
    
    self:PrintLog( "[更新总文件]修改成功" )
    return nil
end

function UpdateSystem:WriteFile( path, data )
    local file = io.open( path, "wb" )
    if file then
        io.writefile( path, data )
        io.flush()
        io.close( file )
        return true
    else
        return false
    end
end

function UpdateSystem:SaveDownloadFile( filename, data )
    local dir = self:GetFileDirectory( filename )
    if dir and dir ~= "" then
        local path = cc.FileUtils:getInstance():getWritablePath()
        cc.FileUtils:getInstance():createDirectory( path..dir )
    end

    local path = cc.FileUtils:getInstance():getWritablePath()..filename..DOWNLOAD_FILE_SUFFIX
    if cc.FileUtils:getInstance():isFileExist( path ) then
        self:PrintLog( "删除本地存在的文件" )
        cc.FileUtils:getInstance():removeFile( path )
    end

    if self:WriteFile(path,data) == false then
        ERROR_WRITE_FILE.detail = filename
        self:ErrorUpdate( ERROR_WRITE_FILE )
        return
    end
    
    self:PrintLog( "储存下载文件成功" )
end

function UpdateSystem:GetFileDirectory( filename )
    local idx = string.lastindexof( filename, "/" )
    if idx ~= nil then
        return string.sub( filename, 0, idx-1 )
    end
    return ""
end



------------删除所有下载的文件------------
function UpdateSystem:RemoveAllDownloadFile()
    self:PrintLog( "删除所有下载的文件" )
    self:LoadDownloadFileList()
    self:RemoveDownloadFile()
    self:RemoveUpdateFile()    
end

function UpdateSystem:LoadDownloadFileList()
    self:PrintLog( "读取下载的文件列表" )
    local data = ""
    local path = cc.FileUtils:getInstance():getWritablePath()..self.localFileListPath
    if cc.FileUtils:getInstance():isFileExist(path) then
        data = cc.FileUtils:getInstance():getStringFromFile( path )
        local tb = json.decode(data)
        
        self.tbRemoveFileList = {}
        self:AddFileList( "", tb, self.tbRemoveFileList )
    end
end

function UpdateSystem:RemoveDownloadFile()
    for k,tb in pairs( self.tbRemoveFileList ) do
        if type(tb.file) == "string" then
            local path = cc.FileUtils:getInstance():getWritablePath()..tb.file
            if cc.FileUtils:getInstance():isFileExist( path ) then
                cc.FileUtils:getInstance():removeFile( path )
            end
        end
    end
end

function UpdateSystem:RemoveUpdateFile()
    local path = cc.FileUtils:getInstance():getWritablePath()..self.localFileListPath
    if cc.FileUtils:getInstance():isFileExist( path ) then
        cc.FileUtils:getInstance():removeFile( path )
    end
    
    path = cc.FileUtils:getInstance():getWritablePath()..self.localTotalFilePath
    if cc.FileUtils:getInstance():isFileExist( path ) then
        cc.FileUtils:getInstance():removeFile( path )
    end    
end




function UpdateSystem:UpdateProgresses()
    if self.UpdateProgressCallback then
        self.UpdateProgressCallback( self.CurrSize, self.UpdateSize )
    end
end

function UpdateSystem:UpdateDone()
    self:PrintLog( "更新完成" )
    self:ExitUpdate()
    
    if self.UpdateDoneCallback then
        self.UpdateDoneCallback()
    end
end

function UpdateSystem:ErrorUpdate( err )
    self:PrintLog( err.msg )
    self.bUpdateContinue = false
    self:ExitUpdate()
    
    if self.UpdateErrorCallback then
        self.UpdateErrorCallback( err )
    end
end

function UpdateSystem:ExitUpdate()
    if self.xhr ~= nil then
        self.xhr:release()
        self.xhr = nil
    end
end

function UpdateSystem:PrintLog( txt )
    if PRINT_LOG ~= true then return end
    if type(txt) ~= "string" then return end
    
    if type(DEBUG) == "number" and DEBUG > 0 then
        print( "[UpdateSystem]:\t".. txt )
    end
end

return UpdateSystem