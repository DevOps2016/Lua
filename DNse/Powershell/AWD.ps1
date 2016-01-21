$action=""
Import-Module WebAdministration; 
function WriteLog($string)
{
    #(Get-Date -format 'yyyy-MM-dd HH:mm:ss') + ": "+$string | out-file log.txt -append
}
function CreateLogVersionDeploy($info)
{
    "Version: " + $info + " at "+(Get-Date -format 'yyyy-MM-dd HH:mm:ssZ') | out-file "$WebrootFolder\deploy.txt"
}
function WriteLine(){
	Write-Host "------------------------------------------" -ForegroundColor White
}
function WriteMsg($msg){
	$date = Get-Date
	Write-Host $msg -ForegroundColor DarkCyan
}
function WriteInfo($msg){
	Write-Host
	Write-Host "["(Get-Date -format 'yyyy-MM-dd HH:mm:ss')"] " $msg -ForegroundColor White
}
function WriteSuccess($msg){
	Write-Host $msg -ForegroundColor Green
}
function WriteFail($msg){
	Write-Host "["(Get-Date -format 'yyyy-MM-dd HH:mm:ss')"] " $msg -ForegroundColor Red
}

function CatchExeption()
{
	Write-Host "Script break on $stepname" -ForegroundColor Red
	WriteLog("Script break on $stepname")
}
function UpdateBindings(){
    if($SiteDomains -ne ""){
        $wsbindings = (Get-ItemProperty -Path "IIS:\Sites\$SiteName" -Name Bindings)
         $option = [System.StringSplitOptions]::RemoveEmptyEntries
        $separator = ";"
        $domains = $SiteDomains.Split($separator, $option)
        $existedDomains ="","";
        Write-Host "Sitename: "$SiteName
        Write-Host "Current domains:"
        for($i=0;$i -lt ($wsbindings.Collection).length;$i++){
                Write-Host ($wsbindings.Collection[$i]).bindingInformation
                $existedDomains+= ($wsbindings.Collection[$i]).bindingInformation;
            }
        Write-Host "Adding domains:"
        foreach($domain in $domains){
            $newValue = "*:80:$domain";
            if($existedDomains -contains $newValue){
                    Write-Host $newValue " existed"
                }else{
                    New-ItemProperty IIS:\Sites\$SiteName –name bindings –value @{protocol="http";hostName=$domain;port=80;bindingInformation=$newValue};
                    Write-Host $newValue " is added".
                }
        }
    }
}
function Get-ComputerStats { 

  process {
          try{
            $avg = Get-WmiObject win32_processor -computername $ServerName | 
                       Measure-Object -property LoadPercentage -Average | 
                       Foreach {$_.Average}
            $mem = Get-WmiObject win32_operatingsystem -ComputerName $ServerName |
                       Foreach {"{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize)}
            $free = Get-WmiObject Win32_Volume -ComputerName $ServerName -Filter "DriveLetter = 'C:'" |
                        Foreach {"{0:N2}" -f (($_.FreeSpace / $_.Capacity)*100)}
    					
    					Write-Host "CPU usage: $avg %" -ForegroundColor Green
    					Write-Host "Memory usage: $mem %" -ForegroundColor Green
    					Write-Host "OS Disk free: $free %" -ForegroundColor Green    
            Write-Host "----------------------PROCESSes------------" 
            Get-Process w3wp,EPiServer*,java*,wrapper* | Format-Table Name, @{Label="Running";Expression={[bool]$_.Responding}}, @{Label="Memory(Mb)";Expression={[int]($_.WorkingSet64/1024/1024)}},@{Label="Last running (sec)";Expression={[int]$_.CPU}},Handles,@{Label="Threads";Expression={[int]$_.Threads.Count}} -autosize | Format-List * #| where-object {$_.WorkingSet -gt 200000000} 
      
          }catch{
              
          }
      }
  
}


function ConfigTransforming(){
     param (
    [string]$paraFile = $ParamsFile,
	[string]$configFolder = $WebFolder,
    [string]$paramFolder = $ParamFolder
     )
    
    
    Write-Host "Parameter file:" $paraFile
    Write-Host "Target folder :" $configFolder
    Write-Host "Full param folder :" $paramFolder\$paraFile
    
    
    #Doc tham so duoi dang Xml
    $doc = (Get-Content $paramFolder\$paraFile -Encoding UTF8) -as [Xml] 
    $params = $doc.parameters.ChildNodes 
    Write-Host "Reading child node " $params
    #if debug -> copy all config to debug folder and execute there
    if($debug){
    	$configFolderOutput = Join-Path $configFolder 'debug'
    	if (!(Test-Path -path $configFolderOutput)){
    		New-Item $configFolderOutput -type directory
    	}
    	Copy-Item (Join-Path $configFolder '*.config') $configFolderOutput -force
    	$configFolder = $configFolderOutput
    }
    
    $option = [System.StringSplitOptions]::RemoveEmptyEntries
    $separator = ";"
    
    #Xu ly tham so
    foreach($item in $params)
    {
    	#Chi xu ly xml element, bo qua cac dang khac (comment, xtext,...)
        if ($item.GetType().Name -eq "XmlElement" -and $item.LocalName -eq "item"){
    Write-Host "Physical file " $item.physicalFile
    		$files = $item.physicalFile.Split($separator, $option)
    		foreach($file in $files){
    			Write-Host "Physical file:" $file
    
    			#Target config file
        		$configFile = Join-Path $configFolder $file
    
    Write-Host "config file " $configFile
    
    			#Remove readonly from config file
        		Set-ItemProperty $configFile -name IsReadOnly -value $false
    
    			#Read content of config file as XML
    			$docConfig = (Get-Content $configFile -Encoding UTF8) -as [Xml]
    
    			#Prepare namespace before processing config
    			#$ns = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
    			#$ns.AddNamespace("ns", $docConfig.DocumentElement.NamespaceURI)
    
    			#Walk through parameters and process configs
    			foreach($paraEntry in $item.ChildNodes)
    			{
    			
    				 if ($paraEntry.GetType().Name -eq "XmlElement"){
    					 #Find element by match rule
    					 $nodeList = $docConfig.SelectNodes($paraEntry.parentMatch)
    			     
    					 #go next if null
    					 if($nodeList -eq $null){
    						Write-Host $file ': cannot find node "'$paraEntry.parentMatch
    						continue
    					 }
    					 foreach($node in $nodeList){
    						 $nodeType = $node.GetType().Name
    						 if($node.ParentNode -eq $null -and $nodeType -ne 'XmlAttribute'){
    							Write-Host $file ': cannot find parent node of "'$paraEntry.parentMatch
    							continue
    						 }
    			         
    						 #processing for replace
    						 if($paraEntry.LocalName -eq "replace"){
    							 if($nodeType -eq 'XmlAttribute'){
    								 $node.Value = $paraEntry.value
    								 Write-Host $file ': {set} value for "'$paraEntry.parentMatch'" with value: "'$paraEntry.value'"'
    							 }else{
    								Write-Host $file ': {invalid} only works with xml attribute. Wrong match: "'$paraEntry.parentMatch'" with value: "'$paraEntry.value'"'
    								throw "interruption by error"
    							 }
    						 }
    						 #processing for remove
    						 elseif($paraEntry.LocalName -eq "remove"){
    							Write-Host $file ': {removing} node "'$paraEntry.parentMatch
    							$node.ParentNode.RemoveChild($node)
    							Write-Host $file ': {done}'
    						 }
    						 #processing for append
    						 elseif($paraEntry.LocalName -eq "append"){
    							#this is to make sure we follow ms deploy, always insert node to top
    							$firstChild = $node.FirstChild
    							if($firstChild -ne $null -and $firstChild.GetType().Name -eq 'XmlComment'){
    								$firstChild = $firstChild.NextSibling
    							}
    							foreach($appendNode in $paraEntry.ChildNodes){
    								$appendNode = $docConfig.ImportNode($appendNode, $true)
    								if($firstChild -eq $null){
    								$node.AppendChild($appendNode)
    								} else{
    								$node.InsertBefore($appendNode, $firstChild)
    								}
    							}
    							Write-Host $file ': {append} to node "'$paraEntry.parentMatch
    						  }
    						  #processing for addAttr
        					   elseif($paraEntry.LocalName -eq "addAttr"){
        							Write-Host $file ': {AddAttribute} node "'$paraEntry.parentMatch
        							$node.SetAttribute($paraEntry.attribute,$paraEntry.value)
        							Write-Host $file ': {done}'
        						 } 
    					 }
    				 }
    			}      
    
    			#save processed content to original file
    			$docConfig.Save($configFile)
    		}
    		
        }
    }
}
function ResetService($sn){
    Stop-Service -Name $sn
    Get-Service $sn
    Start-Service $sn
    Get-Service $sn
}

function SetAttribute($attrName, $attrValue, $xpath,$fileName, $firstOnly){	
    $xml=New-Object XML
    $xml.Load($fileName)
    $nodes = $xml.SelectNodes($xpath);
   
    foreach($node in $nodes) {        
            $node.SetAttribute($attrName, $attrValue);
            Write-Host "$attrName is updated with value: $attrValue"      
            if($firstOnly) {
                break;
            }
    }
    $xml.Save($fileName)
}

function RemoveHttpErrors(){
   $fileName = "$SiteFolder\Webroot\Web.config"
   $xml=New-Object XML
   $xml.Load($fileName)
   $node = $xml.SelectSingleNode("/configuration/system.webServer/httpErrors");
   $node.ParentNode.RemoveChild($node)
    
   Write-Host "httpErrors removed"
        
   $xml.Save($fileName)
}

	
function get-ChoiceOnExeption()
{$choices = [System.Management.Automation.Host.ChoiceDescription[]](
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Stop","Stop execute script"),
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Try Repeate","Try Repeate execute $stepname step" ),
				(New-Object System.Management.Automation.Host.ChoiceDescription "&Continue","Pass $stepname step and start execute next step" ),
                (New-Object System.Management.Automation.Host.ChoiceDescription "&RollBack","Start Rollback script" )
    )
	$caption = "Script has exception during execute $stepname step"
	$message = "Which action should be used?" 
	$result = $Host.UI.PromptForChoice($caption,$message,$choices,1)
	return $result
	}

function get-HoldUserChoice()
{$choices = [System.Management.Automation.Host.ChoiceDescription[]](
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Stop","Stop execute script"),
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Continue","Start execute next step" ),
                (New-Object System.Management.Automation.Host.ChoiceDescription "&RollBack","Start Rollback script" )
    )
	$caption = "Script is hold"
	$message = "Which action should be used?" 
	$result = $Host.UI.PromptForChoice($caption,$message,$choices,1)
	return $result
	}

function get-LoadBalancerUserChoice()
	{$choices = [System.Management.Automation.Host.ChoiceDescription[]](
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Stop","Stop execute script"),
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Continue","Start execute next step" )
    )
	$caption = "Pass more than $MinutesLimit minutes, but we have external connection for site. Need close all connection manually and continue"
	$message = "Which action should be used?" 
	$result = $Host.UI.PromptForChoice($caption,$message,$choices,1)
	return $result
	}

function get-LoadBalancerStartUserChoice()
	{$choices = [System.Management.Automation.Host.ChoiceDescription[]](
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Stop","Stop execute script"),
                (New-Object System.Management.Automation.Host.ChoiceDescription "&Continue","Start execute next step" )
    )
	$caption = "Pass more than $MinutesLimit minutes, but site doesn't have new connection. Need check manually that LoadBalancer file renamed and continue"
	$message = "Which action should be used?" 
	$result = $Host.UI.PromptForChoice($caption,$message,$choices,1)
	return $result
	}

function StartPool2()
{
        try{
    		WriteMsg "Starting AppPool $PoolName on $servername for $SiteName site"
    	
    		Start-WebAppPool $PoolName
    		while((Get-WebAppPoolState -name $PoolName).Value -ne "Started")
    	        {
    			    Start-Sleep -Seconds 3
    	        }
    		if ($LASTEXITCODE -ne 0) {CatchExeption}
    		else
    		{
    			Write-Host "AppPool for $SiteName site is started" -ForegroundColor Green
    			WriteLog("AppPool for $SiteName site is started")
    		}
        }catch{
            
        }
		WriteLine
}

function StopPool2()
{
    try{
			WriteMsg("Stopping AppPool $PoolName on $servername for $sitename site")
		    Stop-WebAppPool $PoolName
		    while((Get-WebAppPoolState -name $PoolName).Value -ne "Stopped")
	        {
			    Start-Sleep -Seconds 5
	        }
			if ($LASTEXITCODE -ne 0) 
			{CatchExeption} 
			else
			{
				Write-Host "AppPool for $SiteName site is stopped" -ForegroundColor Green
				WriteLog("AppPool for $SiteName site is stopped")
			}
    }catch{
        
    }
			WriteLine
	
}

function WarmUpTryReset2($HTTP_Status){
	IF($wamup -le $WarmUpMax){				
	    if($HTTP_Status -ne 504)
	    {
	        Write-Host "The Site may be down with error:$HTTP_Status, trying to reset apppool #$wamup" -ForegroundColor Red
	    }
		
		StopPool2
		StartPool2	
		$wamup = $wamup+1
		WarmUp2
	}
	ELSE{
		$(Throw "Failed to warm up $SiteName")		
	}
}

function WarmUp2()
{
	try{
	 	Write-Host "#$wamup Starting a warm up: $DomainURL" -ForegroundColor Gray	
		
		# First we create the request.
		$HTTP_Request = [System.Net.WebRequest]::Create($DomainURL)
        $HTTP_Request.Timeout=$HttpRequestTimeOutDefaultWarmUp
        Write-Host "With timeout is $HttpRequestTimeOutDefaultWarmUp ms" -ForegroundColor Green
		# We then get a response from the site.
		$HTTP_Response = $HTTP_Request.GetResponse()
		

		# We then get the HTTP code as an integer.
		$HTTP_Status = [int]$HTTP_Response.StatusCode

		If ($HTTP_Status -eq 200) { 
		    Write-Host "Site is OK!" -ForegroundColor Green
			$HTTP_Response.Close()
		}
		ELSE{				
			$HTTP_Response.Close()
		    WarmUpTryReset2 $HTTP_Status
		}
	}catch{
	    Write-Host "Error:  $_.Exception.Response, Failed from try hit url: $FullUrl" -ForegroundColor Red
		WarmUpTryReset2 504
	}
} 
 
 
function Get-Current-Sessions()
{
 	(Get-Counter "\\$ServerName\Web Service($SiteName)\current connections").CounterSamples[0].CookedValue
}



function GetTheNumberOfConnections()
{
	$num = Get-Current-Sessions
	Write-Host "The active connections are(is) $num" -ForegroundColor Green
}

function WaitUntilNoMoreConnections(){
	$num = Get-Current-Sessions
		$eslapse = 0
		while($num -gt $MinConnectionAsOutOfLoad)
		{
		    Clear-Host
			Write-Host "There are $num conection(s) left."
			Start-Sleep -Seconds $WaitTimeForBLN
			$eslapse = $eslapse + $WaitTimeForBLN
			$num = Get-Current-Sessions		
		}
		
		if($num -le $MinConnectionAsOutOfLoad)
		{
			Write-Host "No more active connections to $SiteName now. It took $eslapse second(s) for awaiting".		
		}
}

function CheckOutOfBalancing(){
	Write-Host "Off the CheckAlive"
	$F = "$SiteFolder\Webroot\CtrlFreak\checkalive.html"
	Write-Host $F
	$content = ""
	if([System.IO.File]::Exists($F)){
	    [System.IO.File]::Delete($F)
		WaitUntilNoMoreConnections	
	}else{
	     Write-Host "$SiteName is not in Load. No need to checkout"
	}
}

function StopIfOnline(){
	$F = "$SiteFolder\Webroot\CtrlFreak\checkalive.html"
	if([System.IO.File]::Exists($F))
	{
		$(Throw "$SiteName is online. Please check out of load then try deploy again.")
	}
}

function WaitUntilGotConnections(){
		$num = Get-Current-Sessions
		$eslapse = 0
		while($num -le 0)
		{
			Write-Host "There are $num conection(s)."
			Start-Sleep -Seconds $WaitTimeForBLN
			$eslapse = $eslapse + $WaitTimeForBLN
			$num = Get-Current-Sessions		
		}
		if($num -gt 0)
		{
			Write-Host "$SiteName now is in load. There are $num conection(s). It took $eslapse second(s) for awaiting".		
		}
}


function CheckInOfBalancing()
{
    Write-Host "On the CheckAlive"
	$F = "$SiteFolder\Webroot\CtrlFreak\checkalive.html"
	Write-Host $F
	if(-not [System.IO.Directory]::Exists("$SiteFolder\Webroot\CtrlFreak")){
	    [System.IO.Directory]::CreateDirectory("$SiteFolder\Webroot\CtrlFreak")
	}
	if([System.IO.File]::Exists($F)){
	    Write-Host "$SiteName is in Load. No need to checkin"
	}
	else{
		[System.IO.File]::WriteAllText($F,"active")
		WaitUntilGotConnections	
	}
}


function Purge(){	
	#Webroot
	$web="$SiteFolder\Webroot"
	Write-Host "Trying to clean up $web"
	
	if([System.IO.Directory]::Exists($web)){
    	$files = Get-ChildItem -Path  $web -Recurse -Exclude connectionStrings.config, EPiSolr.config, SolrCore.config, ServicePlus.config, License.config, EPiServerFramework.config, App_Offline.html, EPiServerCommunityLicense.config  |
    		Select -ExpandProperty FullName
    		Where {$_ -notlike '*CheckAlive*'}
    	Write-Host "Purge $web"
    	$c1 =0
    	foreach($f in $files)
    	{
    	    $dir = [System.IO.Path]::GetDirectoryName($f);
    	    $des = [System.IO.Path]::GetFileName($dir);
    	    #ignore the config files of webapi from deleting
    	    if([System.IO.Path]::GetExtension($f) -eq ".config" -and ($des -eq "Di.Web.Api"))
    		{
    		    continue;
    		}
    		if([System.IO.File]::Exists($f))
    		{
    			[System.IO.File]::SetAttributes($f, [System.IO.FileAttributes]::Normal);
    			[System.IO.File]::Delete($f)
    			$c+=1
    		}
    	}
    	Write-Host "Purged Webroot for $c file(s)"
	}else{
	    Write-Host "Dont have Webroot folder"
	}
	#Lib
	$lib="$SiteFolder\Libraries"
	Write-Host "Trying to clean up $lib"
	if([System.IO.Directory]::Exists($lib)){
    	$files = Get-ChildItem -Path  $lib -Recurse |
    		Select -ExpandProperty FullName		
    	Write-Host "Purge $lib"
    	$c1 =0
    	foreach($f in $files)
    	{
    		if([System.IO.File]::Exists($f))
    		{		
    			[System.IO.File]::SetAttributes($f, [System.IO.FileAttributes]::Normal);
    			[System.IO.File]::Delete($f)
    			$c+=1
    		}
    	}
    	Write-Host "Purged Libraries for $c file(s)"
	}else{
	    Write-Host "Dont have Libraries folder"
	}
}


function StopWeb(){
	#$appPool = Invoke-Command -ComputerName $Servername {	
		#Get-Item ("IIS:\AppPools\"+$SiteName)
		Stop-Website -Name $SiteName
	#}
		
	#Write-Host $appPool
}
function StartWeb(){
	#$appPool = Invoke-Command -ComputerName $Servername {	
		#Get-Item ("IIS:\AppPools\"+$SiteName)
		Start-Website -Name $SiteName
	#}
		
	#Write-Host $appPool
}

function WarmUpTryReset($HTTP_Status){
	IF($wamup -le $WarmUpMax){				
	    if($HTTP_Status -ne 504)
	    {
	        Write-Host "The Site may be down with error:$HTTP_Status, trying to reset apppool #$wamup" -ForegroundColor Red
	    }
		
		StopPool
		StartPool	
		$wamup = $wamup+1
		WarmUp
	}
	ELSE{
		$(Throw "Failed to warm up $SiteName")		
	}
}

function WarmUp()
{
	try{
	 	Write-Host "#$wamup Starting a warm up: $SiteURL" -ForegroundColor Gray	
		
		# First we create the request.
		$HTTP_Request = [System.Net.WebRequest]::Create($SiteURL)
        $HTTP_Request.Timeout=$HttpRequestTimeOutDefaultWarmUp
        Write-Host "With timeout is $HttpRequestTimeOutDefaultWarmUp ms" -ForegroundColor Green
		# We then get a response from the site.
		$HTTP_Response = $HTTP_Request.GetResponse()
		

		# We then get the HTTP code as an integer.
		$HTTP_Status = [int]$HTTP_Response.StatusCode

		If ($HTTP_Status -eq 200) { 
		    Write-Host "Site is OK!" -ForegroundColor Green
			$HTTP_Response.Close()
		}
		ELSE{				
			$HTTP_Response.Close()
		    WarmUpTryReset $HTTP_Status
		}
	}catch{
	    Write-Host "Error:  $_.Exception.Response, Failed from try hit url: $FullUrl" -ForegroundColor Red
		WarmUpTryReset 504
	}
}

function Add-Zip
{
    param([string]$zipfilename)
    Write-Host "Start creating the package:$zipfilename"
    if(-not (test-path($zipfilename)))
    {
        set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        (dir $zipfilename).IsReadOnly = $false  
    }

    $shellApplication = new-object -com shell.application
    $zipPackage = $shellApplication.NameSpace($zipfilename)
    $count=0
    foreach($file in $input) 
    { 
        Write-Host $file.FullName
            $zipPackage.CopyHere($file.FullName)
             
            Start-sleep -milliseconds 500
            $count+=1
    }
    Write-Host "Finish creating the package for $count item(s)"
}

function WarUpListUrls
{
    Param([string[]] $URL, [int]$IsDesktop)
    Write-Host "# Set timeout for each response is 500 seconds" -ForegroundColor Green
    [int]$Count = 1

    foreach($URL in $URLs)
    {
        if($IsDesktop -eq 1)
        {
            $FullUrl = Join-Parts ($SiteURL, $URL) '/'
        }
        else
        {
            $FullUrl = Join-Parts ($SiteMobileURL, $URL) '/'
        }
        try{
                      
	 	    Write-Host "#$Count Starting a warm up: $FullUrl" -ForegroundColor White	
		    # First we create the request.
		    $HTTP_Request = [System.Net.WebRequest]::Create($FullUrl)
            $HTTP_Request.Timeout=$HttpRequestTimeOutWarmUpList
           
		    # We then get a response from the site.
		    $result = Measure-Command {  $HTTP_Response = $HTTP_Request.GetResponse() }
		
		    # We then get the HTTP code as an integer.
		    $HTTP_Status = [int]$HTTP_Response.StatusCode
            #$result = Measure-Command { $request = Invoke-WebRequest -Uri $uri }

		    If ($HTTP_Status -eq 200) {
                Write-Host "Status code: " $HTTP_Status -ForegroundColor Green
                Write-Host "Status description: Ok" -ForegroundColor Green
                Write-Host "Status response Uri: " $HTTP_Response.ResponseUri -ForegroundColor Green
                Write-Host "Status time response: " $result.TotalMilliseconds "milli seconds" -ForegroundColor Green
			    $HTTP_Response.Close()
                $Count++
                $global:TotalSuccess++
		    }
		    ELSE{				
			    $HTTP_Response.Close()
			    Write-Host "Error $HTTP_Status, Failed from try hit url: $FullUrl" -ForegroundColor Red
                $global:TotalFailed++
		    }
	    }catch{
		    Write-Host "Error:  $_.Exception.Response, Failed from try hit url: $FullUrl" -ForegroundColor Red
            $global:TotalFailed++
            $Count++
	    }
    }
}
[int]$global:TotalFailed = 0
[int]$global:TotalSuccess = 0
Function ReadWarmUpFile
{
    try
    {
        Write-Host "==============Start warming up list urls for desktop site=================" -ForegroundColor Green
        Write-Host "# Start reading the file contains a list of urls desktop site" -ForegroundColor Green
        $PathFolder = CombinePaths($ScriptFolder) ("\package\urlswarmup\")
        $PathFile = CombinePaths($PathFolder) ("DNDesktopUrls.txt")
        $URLs = Get-Content $PathFile
        Write-Host "# Reading urls have done" -ForegroundColor Green
        WarUpListUrls($URLs) 1
        Write-Host "==============Warm up desktop site has done===================" -ForegroundColor Green
        Write-Host "==============Start warming up list urls for mobile site===================" -ForegroundColor Green
        Write-Host "# Start reading the file contains a list of urls mobile site" -ForegroundColor Green
        $PathFile = CombinePaths($PathFolder) ("DNMobileUrls.txt")
        $URLs = Get-Content $PathFile
        Write-Host "# Reading list urls have done " -ForegroundColor Green
        WarUpListUrls($URLs) 0
        Write-Host "=============Warm up mobile site has done===================" -ForegroundColor Green
        Write-Host "===============This step was finished=======================" -ForegroundColor Green
        Write-Host "Total warm up success: "$global:TotalSuccess -ForegroundColor Green
        if($global:TotalFailed -gt 0)
        {
            Write-Host "Total warm up failed: " $global:TotalFailed -ForegroundColor Red
        }
        else
        {
            Write-Host "Total warm up failed:" $global:TotalFailed -ForegroundColor Green
        }
        $global:TotalSuccess = 0;
        $global:TotalFailed = 0;
    }
    catch
    {
        Write-Host "Error:  $_.Exception.Response -ForegroundColor Red"
    }
}

function Join-Parts {
    param ([string[]] $Parts, [string] $Seperator = '')
    $search = '(?<!:)' + [regex]::Escape($Seperator) + '+'  #Replace multiples except in front of a colon for URLs.
    $replace = $Seperator
    ($Parts | ? {$_ -and $_.Trim().Length}) -join $Seperator -replace $search, $replace
}
[char[]]$trimChars = '\\'
function FixTerminatingSlash ($root) {
    return $root.TrimEnd($trimChars)   
}

Function FixStartingSlash($suffix) {
    return $suffix.TrimStart($trimChars)
}

Function CombinePaths ([string]$root, [string]$subdir) {
    $left = FixTerminatingSlash($root)
    $right = FixStartingSlash($subdir)
    $fullPath = [System.IO.Path]::Combine($left, $right)
    return $fullPath
}
# ==============================END===============================================
$packagepath = $ScriptFolder
	$global:rlbck=0
	Write-Host "Start processing ..." -ForegroundColor Green
	#WriteLog("Start processing ... $action")
	#Write-Host "$SiteFolder"
	#$WebrootFolder = "$SiteFolder\Webroot" 
	#$LibFolder = "$SiteFolder\Libraries"