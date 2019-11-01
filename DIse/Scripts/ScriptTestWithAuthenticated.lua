local configuration = {
	domain ='http://www-stage.di.se/',
	splusdomain ='http://account.qa.newsplus.se/',
	minThinkTime = 20,
	maxThinkTime = 40,
	userName = 'userEmailGoesHere',
	password = 'passwordGoesHere',
	enableCheckLoginStatusInEachRequest = true,
  	enableCheckLoginStatusAfterLogout = true,
	enableLogin = true,
	pageDataSource = 'stage-data-source',
	resourceSource = 'stage-resource-source',
	isRandomPick = false,
	accountName = 'Quan',
	appId = 'di.se',
	callbackUrl = 'http://account.qa.newsplus.se/login?appId=di.se&lc=sv&callback=http%3a%2f%2fwww-stage.di.se%2fhandlers%2freturn%3freturnUrl%3dhttp%253a%252f%252fwww-stage.di.se%252f'
}
local dsPages
local dsResource

--setup necessary parameters
function setup()
	dsPages = datastore.open(configuration.pageDataSource)
	dsResource = datastore.open(configuration.resourceSource)
end

--start the test
function runTest()  
	if configuration.enableLogin then			    
		login()	    
	end

	local length = dsPages:get_length()
    if configuration.isRandomPick then
        for i=1, length do
          local temp = dsPages:get_random() 
          url = table.remove(temp,1)
          loadPage(url, url, dsResource)
        end
      else
          for i=1, length do
          local temp = dsPages:get(i)
          url = table.remove(temp,1)
          loadPage(url, url, dsResource)
        end
    end
end

--core function to perform a test
function  loadPage(pageName, pageUrl, resources)
  	--log.info('pageName'..pageName)
  	--log.info('pageUrl'..pageUrl)
	http.page_start(pageName)

	local response = http.get(
        {"GET", pageUrl, response_body_bytes = 1000000}
    )	

	if configuration.enableCheckLoginStatusInEachRequest then
		checkLoginStatus()
	end

	--build resources table
	local resourceTable = {}
  	local length = resources:get_length()
	for i=1, length do	    			
		local temp = resources:get(i)
    	local url = table.remove(temp,1)    	
    	--log.info('resource'..url)
      	table.insert(resourceTable, {'GET', url})
    end
	http.request_batch(resourceTable)

    http.page_end(pageName)
  	--log.info('pageEnd'..pageName)
    client.sleep(math.random(configuration.minThinkTime, configuration.maxThinkTime))  
end

--check login status
function checkLoginStatus()
  	local accountName = configuration.accountName
  
	local response = http.get({ url = configuration.splusdomain..'profiles', response_body_bytes=1000000 })
    local log_body = response['body']	  	
  
    if string.find(log_body, accountName) == nil then
        return 'Anonymous'
    else
        return 'Authenticated'
    end
end

--get load generator information
function getLoadGeneratorInfo()
	local info = 'Load ID: '..client.get_load_generator_id()..' - Time Elapsed: '..client.get_time_since_start()
  	return info
end

--login to S+
function  login()
	 -- Login information
    local username = configuration.userName
    local pw = configuration.password
    local accountName = configuration.accountName
    local appId = configuration.appId
    local callbackUrl = url_encode(configuration.callbackUrl)
    --log.info(callbackUrl)

    local dataPost = 'username='..username..'&password='..pw..'&appId='..appId..'&remember=true&lc=sv&callback='..callbackUrl

    local response2 = http.post({ url = configuration.splusdomain..'authenticate-hybrid', headers={["Content-Type"]="application/x-www-form-urlencoded"}, data=dataPost, auto_decompress=true, response_body_bytes=1000000 })
	
    -- Check if login is successfully by making request to profile page
  	log.info('LoginStatus_Login: '..checkLoginStatus()..' | '..getLoadGeneratorInfo())
end

--logout from S+
function logout()
  http.get({ url = configuration.splusdomain..'logout' })
  if configuration.enableCheckLoginStatusAfterLogout then
    log.info('LoginStatus_Logout: '..checkLoginStatus()..' | '..getLoadGeneratorInfo())
  end
end

function url_encode(str)
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str	
end

setup()
runTest()
