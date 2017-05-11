# luaFilesUpdate
FilesUpdate
github排版有问题,请raw阅读

项目简介
  这是一个基于cocos2d-x 3.x lua版的文件更新
  
  请把读写目录第一个加入到收索目录!
  FileUtils::getInstance()->addSearchPath(FileUtils::getInstance()->getWritablePath());
  

UpdateSystem.lua 简介
	更新入口
		function UpdateSystem:StartUpdate( localFilePath, localFileListPath )
		参数 localFilePath:本地[更新总文件]的路径	(后面讲如何配置这个文件)
		参数 localFileListPath:本地文件列表	(后面讲如何配置这个文件)

	第一步 校验MD5
	  1 读取本地[更新总文件],获得更新的基本信息 
	  	function UpdateSystem:LoadTotalUpdateFile()
	  	
	  2 请求服务器[更新总文件],获得服务器上的基本信息(服务器文件地址在本地[更新总文件]里配置的)
	  	function UpdateSystem:RequestServerTotalUpdateFile()
	 	
	 	3 请求道服务器[更新总文件]后,对比客户端和服务器的[更新总文件]
	 		function UpdateSystem:OnServerTotalResponse() 		
	 		function UpdateSystem:CheckUpdate()
	 		通过对比本地和服务器文件里的MD5值,可以知道当前需不需要更新,如果不需要更新,则更新完成
	 		如果需要更新,并且服务器当前设置了强更,则更新失败,同时删除所有在文件列表并且在读写目录的文件
	 		如果需要更新,并且服务器当前设置可更新,但是客户端当前版本低于服务器设置的上一个强更版本,则更新失败,同时删除所有在文件列表并且在读写目录的文件
	 		更新流程进入第二步
 	
 	第二步 对比文件列表,获得更新列表
 		function UpdateSystem:StartCompareFileList()
 		1 读取本地文件列表
 			function UpdateSystem:LoadClientFileList()
 		2 获取服务器的文件列表(服务器文件列表地址在服务器的[更新总文件]里配置的)
 			function UpdateSystem:RequestServerFileList()
 		3 对比文件列表,获得更新列表
 			function UpdateSystem:OnServerFileListResponse()
 			function UpdateSystem:GetUpdateFileList()
 			更新流程进入第三步
 			
 	第三步 根据更新列表进行文件下载
 		0 开始下载文件
 			function UpdateSystem:DownloadNext()
 			此处会根据取消标记,结束更新流程,更新错误(更新被取消)
 			
 		1 收到服务器文件后,对文件内容进行md5运算,得到文件内容的MD5值
 			拿这个值跟服务器文件列表里该文件的MD5值进行对比
 			如果不同,说明文件内容有问题,重新下载,重试三次.(如果三次都对不上,说明配置错误或者网络错误,更新失败)
 		
 		2 如果文件校验通过,则储存这个文件
 			function UpdateSystem:SaveDownloadFile( filename, data )
 			创建该文件的目录
 			给该文件名加上临时后缀 ".updtmp"
 			如果存在该文件名+临时后缀的文件,则删除
 			将该文件内容储存到 文件名+".updtmp" 
 		
 		3 通知外部回调函数,当前的进度
 			function UpdateSystem:UpdateProgresses()
 			
 		4 从更新列表中删除该文件,开始下载下一个文件,进入步骤0
 		
 		5 所有文件下载成功
 			function UpdateSystem:DownloadAllDone()
 			
 			function UpdateSystem:ChangeAllTmpToWork()
 			把所有更新列表里的文件并且在读写目录带有.updtmp的文件,去掉.updtmp后缀
 			
 			function UpdateSystem:RecordFileList()
 			更新本地的文件列表
 			
 			function UpdateSystem:RecordTotal()
 			更新本地[更新总文件]
 			
 		6 function UpdateSystem:UpdateDone()
 			更新完成,通知外部回调函数
 			

如何使用
	参见:function MainScene:StartUpdate()
	local us = UpdateSystem:Create()			
  us:SetUpdateProgressCallback( handler( self, self.UpdateProgress ) )	--设置进度回调函数
  us:SetUpdateDoneCallback( handler( self, self.UpdateDone ) )					--设置更新完成回调函数
  us:SetUpdateErrorCallback( handler( self, self.UpdateError ) )				--设置更新错误回调函数,传入参数参见UpdateSystem.lua顶部
  us:StartUpdate( "UpdateTotal.ver", "UpdateFileList.ver" )							--传入本地[更新总文件]和本地文件列表地址,开始更新流程
  
  取消函数
  function UpdateSystem:Cancel()
  调用该函数后,会在下载下一个文件之前停止流程,并回调更新错误回调函数,参数是ERROR_UPDATE_CALCEN
  
  

配置文件
	本地[更新总文件]的配置 json格式,参见UpdateTotal.ver
		md5:所有文件内容md5值相加字符串的md5值
		currversion:当前版本号
		url:服务器[更新总文件]的地址
		
		--其余参数无用,保留其他参数是为了方便配置服务器[更新总文件]
	
	服务器[更新总文件]的配置 json格式,UpdateFileList.ver
		md5:所有文件内容md5值相加字符串的md5值
		compulsive:当前版本是否需要强制更新
		currversion:当前版本号
		lastversion:上一个强制更新的版本号
		url:服务器的文件列表地址  --注意:此处与客户端不同
		desc:当前版本的更新内容
		
	本地文件列表的配置 json格式 参见UpdateFileList.ver
		具体不多说,直接看例子
		
	服务器文件列表的配置 json格式 参见UpdateFileList.ver
		参见客户端文件列表的配置
		注意:加入一个元素
		"url":"" 指向服务器文件的下载地址的开头,比如"test.update.com/"
	
	配置工具
		GetFilesMD5.exe
		运行该工具会自动生成UpdateFileList.ver,并且返回一个MD5值,你需要将这个值填写到[更新总文件]的MD5值那里
		该工具会忽略.exe .ver文件
		
		特别注意:服务器UpdateFileList.ver别忘了手动加入
		"url":"" 指向服务器文件的下载地址的开头,比如"test.update.com/"
		
		https://github.com/bailufeiba/GetFilesMD5

如果可以的话,请保留第一行,让我装个逼 (づ￣ 3￣)づ
如有问题QQ联系:2686885181
