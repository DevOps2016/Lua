local domain = "http://www-stage.dn.se/"
local resourceHandlerSuffix = 635860036530600000

local commonResources = {
    {"GET", domain.."css/safari/safari.css?v=2015"},
    {"GET", domain.."css/ie/style.ie.all.css?v=2015"},
    {"GET", domain.."files/js/analys/advertisement.js?xver=41"},
    {"GET", domain.."files/js/burtjs/simpleStorage.js?xver=41"},    
    {"GET", domain.."files/js/analys/datalayer_setup.js?xver=41"},
    {"GET", domain.."files/js/burtjs/burt_init.js?xver=43"},
    {"GET", domain.."oas/fusion_utils_dnuuid.js?v=17"},
    {"GET", domain.."files/js/analys/gtm.js?xver=40"},
    {"GET", domain.."Images/Logos/desk_DNse_logo.svg"},
    {"GET", domain.."Images/2011/10/12/croneman166.png"},
    {"GET", domain.."Images/2011/10/18/hagerman166_ny.png"},
    {"GET", domain.."Images/2011/10/12/Helmerson166.png"},
    {"GET", domain.."Images/2011/10/12/jonsson166.png"},
    {"GET", domain.."Images/2011/10/12/bojs192.png"},
    {"GET", domain.."Images/2013/01/28/fahlhanna_166_ny.jpg"},    
    {"GET", domain.."PageFiles/68500/rocky.gif"},
    {"GET", domain.."Documents/external_resource/AdditionalHeaderScript.js?v=1.84"},
    {"GET", domain.."files/js/burtjs/burt_bottom.js?xver=41"},
    {"GET", domain.."files/js/burt-dn-se.js?xver=7"},
    {"GET", domain.."img/icons/favicon.ico"},
    {"GET", domain.."Images/Logos/desk_DNprio_logo.svg"},
    {"GET", domain.."Images/Logos/desk_DNse_e-DN_logo.svg"},
    {"GET", domain.."Images/Logos/DNse_FAQ_32x32.svg"},
    {"GET", domain.."Images/Logos/DNse_logo_black.png"},    
    {"GET", domain.."PageFiles/68500/ernie.gif"},
    {"GET", domain.."PageFiles/69296/sudoku.gif"},    
    {"GET", domain.."PageFiles/69296/ord-pa-ord.gif"},    
    {"GET", domain.."Images/Logos/DNse_BestallDNDigitalt_32x32.svg"},
    {"GET", domain.."Images/Logos/DNse_SkapaKonto_32x32.svg"},
    {"GET", domain.."Images/Icons/icon_foot_rss.gif"},
    {"GET", domain.."Images/Icons/icon_foot_sms.gif"},
    {"GET", domain.."Images/Icons/icon_foot_tablet.gif"},
    {"GET", domain.."Images/Icons/icon_foot_newsletter.gif"},
    {"GET", domain.."Images/Logos/Woman.png"},
    {"GET", domain.."Images/Icons/icon_foot_support.gif"},
    {"GET", domain.."PageFiles/214/dnse-logo-footer.png"},
    {"GET", domain.."files/js/burtjs/ads-panoramareload.js?xver=2"},
    {"GET", domain.."files/js/analys/puma/puma.js?xver=66"},
    {"GET", domain.."Images/Logos/DNse_BestallTidningen_32x32.svg"},
    {"GET", domain.."jquery/js/jquery-1.8.3.min.js"},
    {"GET", domain.."files/js/analys/analytics_static.js?xver=74"},
    {"GET", domain.."Images/Logos/DNse_Kundservice_32x32.svg"},
    {"GET", domain.."files/js/analys/comscore_top.js?xver=41"},
    {"GET", domain.."files/js/burtjs/campaign_watcher.js?xver=41"}
}

function loadPage(pageName, pageUrl)
    http.page_start(pageName)    
    
    local response = http.request_batch({
        {"GET", domain..pageUrl}
    })
    checkLoginStatus(response)

    local resourceRequests = {
        --{"GET", domain.."/ResourceHandler/DesktopCssDependencies/0-1-3-4-5-6-7-8-9-10-11-13-14-20-22-23-25-26-27-28-32-33-35-36-41-42-46-47-81-87-88-89-91-92-93-99."..resourceHandlerSuffix..".css"},    
        --{"GET", domain.."ResourceHandler/DesktopJsDependencies/0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15-16-17-18-19-20-21-22-23-24-25-26-27-29-30-31-32-33-34-35-36-37-38-40-42-43-44-45-46-47-48-49-50-51-52-65-67-68-69-70-71-72-73-74."..resourceHandlerSuffix..".js"},    

    }

    for i, name in ipairs(commonResources) do
      table.insert(resourceRequests, name)
    end
    
    http.request_batch(resourceRequests)
    http.page_end(pageName)
    client.sleep(math.random(20, 40))
end

function loadArticlePage(pageName, pageUrl)    
    http.page_start(pageName)    

    local response = http.request_batch({
        {"GET", domain..pageUrl}
    })
    checkLoginStatus(response)
    
    local resourceRequests = {
        --{"GET", domain.."/ResourceHandler/DesktopCssDependencies/0-1-3-4-5-6-7-8-9-10-11-13-14-20-22-23-25-26-27-28-32-33-35-36-41-42-46-47-81-87-88-89-91-92-93-99."..resourceHandlerSuffix..".css"},    
        --{"GET", domain.."ResourceHandler/DesktopJsDependencies/0-1-2-3-4-5-6-7-8-9-10-11-12-13-14-15-16-17-18-19-20-21-22-23-24-25-26-27-29-30-31-32-33-34-35-36-37-38-40-42-43-44-45-46-47-48-49-50-51-52-65-67-68-69-70-71-72-73-74."..resourceHandlerSuffix..".js"},    

    }

    for i, name in ipairs(commonResources) do
      table.insert(resourceRequests, name)
    end
    
    http.request_batch(resourceRequests)
    http.page_end(pageName)
    client.sleep(math.random(20, 40))
end

function checkLoginStatus(response)
    local cookies = response['cookies']
    if cookies == nil or cookies['VQB0AFIAZwB0AFgAVABjADMAUQBVAD0A'] == nil then
        log.info('Anonymous')
    else
        log.info('Authenticated')
    end
end

function checkLogin()
    local repeatTimes = client.get_repetition()
    if repeatTimes == 1
        then
            login()
    end
end

function  login()
    -- Login information
    local username = "test1@dn.se"
    local pw = "123456"
    local accountName = "Mitt DN"
    local appId = 'dagensnyheter.se'
    local callbackUrl = 'http%3a%2f%2fwww-stage.dn.se%3a80%2fServicePlus%2fUI%2fPages%2fServicePlusCallbackPage.aspx%3fact%3dlogin%26ReturnUrl%3dhttp%3a%2f%2fwww-stage.dn.se%3a80%252f'
    --log.info(callbackUrl)

    local dataPost = 'username='..username..'&password='..pw..'&appId='..appId..'&remember=true&lc=sv&callback='..callbackUrl

    local response2 = http.post({ url="http://account.qa.newsplus.se/authenticate-hybrid", headers={["Content-Type"]="application/x-www-form-urlencoded"}, data=dataPost, auto_decompress=true, response_body_bytes=1000000 })

    local log_body = response2['body']
    if string.find(log_body, accountName) == nil then
        log.info('Login failed')
    else
        log.info('Login succeeded')
    end
end

checkLogin()
loadPage("Home Page","")
loadPage("Sthlm","sthlm/")
loadPage("Sverige","nyheter/sverige/")
loadPage("vetenskap","nyheter/vetenskap/")
loadPage("varlden","nyheter/varlden/")
loadPage("fragesport","nyheter/fragesport/")
loadPage("Ekonomi","ekonomi/")
loadPage("Sport","sport/")
loadPage("WebbTv","webb-tv/klipp/")
loadPage("Kultur","kultur-noje/")
loadPage("scanpix","webb-tv/scanpix/")
loadArticlePage("Löfven: Sverige på väg ur den akuta flyktingkrisen","nyheter/sverige/lofven-sverige-pa-vag-ur-den-akuta-flyktingkrisen/")
loadArticlePage("Johan Croneman: En enda rimstuga till och man är beredd att helt ge upp","kultur-noje/kronikor/johan-croneman-en-enda-rimstuga-till-och-man-ar-beredd-att-helt-ge-upp/")
loadArticlePage("Försäkringskassans kameraövervakning olaglig","ekonomi/forsakringskassans-kameraovervakning-olaglig/")
loadArticlePage("Höns springer omkring på E4 efter lastbilsolycka","nyheter/sverige/hons-springer-omkring-pa-e4-efter-lastbilsolycka/")
loadArticlePage("Forskare: Därför separerar småbarnsföräldrar","nyheter/sverige/forskare-darfor-separerar-smabarnsforaldrar/")
loadArticlePage("Han är första svenska dragracingmästaren i USA","sport/han-ar-forsta-svenska-dragracingmastaren-i-usa/")
loadArticlePage("Murrays femte raka seger mot Ferrer","sport/murrays-femte-raka-seger-mot-ferrer/")
loadArticlePage("Här radikaliserades den jagade terroristen","nyheter/sverige/har-radikaliserades-den-jagade-terroristen/")
loadArticlePage("valet-2014","valet-2014/har-ar-den-nya-riksdagens-vanligaste-efternamn/")
loadArticlePage("ineffektivt-aik-forlorade","sport/ishockey/ineffektivt-aik-forlorade/")
loadArticlePage("vart-mal-ar-basta-skyddet","motor/vart-mal-ar-basta-skyddet/")
loadArticlePage("ata-ute","pa-stan/ata-ute/")
loadArticlePage("fondavgifterna-pa-rekordlag-niva","ekonomi/din-ekonomi/fondavgifterna-pa-rekordlag-niva/")
loadArticlePage("Nyhetsdygnet","nyhetsdygnet/?d=20151119")
loadArticlePage("reportage","mat-dryck/reportage/")
loadArticlePage("recept","mat-dryck/recept/")




