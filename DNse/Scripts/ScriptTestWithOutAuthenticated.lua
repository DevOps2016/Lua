local configuration = {
	domain ='http://www-stage.dn.se/',
	splusdomain ='http://account.qa.newsplus.se/',
	minThinkTime = 20,
	maxThinkTime = 40,
	userName = 'userEmailGoesHere',
	password = 'passwordGoesHere',
	enableCheckLogin = true,
	enableLogin = false,
	pageDataSource = 'stage-data-source',
	resourceSource = 'stage-resource-source',
	isRandomPick = false,
	accountName = 'Mitt DN',
	appId = 'dagensnyheter.se',
	callbackUrl = 'http://www-stage.dn.se/ServicePlus/UI/Pages/ServicePlusCallbackPage.aspx?act=login&ReturnUrl=http://www-stage.dn.se%2f'
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
		local repeatTimes = client.get_repetition()
	    if repeatTimes == 1
	        then
	            login()
	    end
	end

	local length = dsPages:get_length()
	for i=1, length do	
		local url
		if configuration.isRandomPick then   	
			local temp = dsPages:get_random() 
    		url =  table.remove(temp,1)    		    	
    	else
    		local temp = dsPages:get(i)
	    	url = table.remove(temp,1)    		    	    		
    	end
    	loadPage(url,url,dsResource)
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

	if configuration.enableCheckLogin then
		checkLoginStatus(response)
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
function checkLoginStatus(response)
	local cookies = response['cookies']
	
	--for k,v in pairs(cookies) do
	--	log.info(k,v)
	--end	
    if cookies == nil or cookies['UQBVAE8AdgBNAHYAKwBhAE8AbAB1ADkARQBCAFIATgBxAHAAeQA3AFoAUQA9AD0A'] == nil then
        log.info('Anonymous')
    else
        log.info('Authenticated')
    end
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

    local log_body = response2['body']

    if string.find(log_body, accountName) == nil then
        log.info('Login failed')
    else
        log.info('Login succeeded')
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