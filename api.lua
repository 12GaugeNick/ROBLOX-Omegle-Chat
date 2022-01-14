local module = {}

local Sending = {}
local SpyMode = false
local Connected = false
local Confirmation = false
local Id = ""

local SearchWord = ""

local BaseURL = "http://omegle.com/"
local http = game:GetService("HttpService")
local chatservice = game:GetService("Chat")

local Event = Instance.new("BindableEvent")

local Colors = {
	Cyan = Color3.fromRGB(0,255,255),
	Blue = Color3.fromRGB(0,0,255),
	Yellow = Color3.fromRGB(255,255,0),
	Red = Color3.fromRGB(255,0,0),
	Green = Color3.fromRGB(0,255,0)
}

local SendEvent = function(m,c)
	Event:Fire(m,c)
end

local toHex = function(n)
	local b, k, ret, i, d = 16, "0123456789ABCDEF", "", 0, nil
	while n>0 do
		i = i + 1
		n, d = math.floor(n/b), n%b + 1
		ret = string.sub(k, d, d)..ret
	end
	return ret
end

local MessageSplit = function(message, prefix) 
	local r = {} 
	for c in message:gmatch('([^'..prefix..']+)') do 
		r[#r+1] = c end 
	return r 
end

function fromHex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

local New;

local GetNewId;
GetNewId = function(spy)
	local token = http:UrlEncode('["'..SearchWord..'"]')
	local url = BaseURL.."start?caps=recaptcha2&firstevents=1&spid=&randid="..toHex(math.random(1,500000)).."&topics="..token.."&lang=en"
	Id = http:GetAsync(url,false)
	if Id:find("You are temporarily banned.") then
		SendEvent('You are temporarily banned',Colors.Red)
	elseif Id:find("\[[\"waiting\"]],") then
		SendEvent("Queued, reconnecting",Colors.Red)
		New()
	end
end

New = function()
	Connected = false
	local r,e = pcall(function()
		local spy = "&wantsspy=1"
		if not SpyMode then spy = "" end
		GetNewId(spy)
		if Id and Id:sub(1,1) == "{" then
			Id = http:JSONDecode(Id).clientID
			Connected = true
		end
	end)
	if (not r) then
		warn("Connection error:",e)
		SendEvent('Connection error : '..e,Colors.Red)
	end
	SendEvent('Connected',Colors.Blue)
end

local SendConfirmation = function()
	if Confirmation == true then
		local confirmation = "Your connected to a roblox server! https://www.roblox.com/games/4600186951/Omegle-Chat"
		table.insert(Sending,{player=nil,address=BaseURL.."send",message="msg=["..http:UrlEncode(confirmation).."&id="..http:UrlEncode(Id),base=confirmation})
		SendEvent('Sent confirmation',Colors.Blue)
	end
end

local Disconnect = function()
	http:PostAsync(BaseURL.."disconnect","id="..http:UrlEncode(Id), 2)
	Connected = false
	SendEvent('Disconnected',Colors.Blue)
end

local Chatted;
Chatted = function(p,m)
	if m:sub(0,1) ~= "/" then
		if m:sub(0,4) == "!new" or m:sub(0,8) == "!connect" then
			pcall(function()
				Disconnect()
			end)
			New()
		elseif m:sub(0,3) == "!sw" then
			SpyMode = (not SpyMode)
		elseif m:sub(0,3) == "!dc" then
			Disconnect()
		elseif m:sub(0,4) == "!key" then
			SearchWord = m:sub(6)
			Disconnect()
			New()
		elseif m:sub(0,8) == "!confirm" then
			Confirmation = (not Confirmation)
		else
			if Connected == true then
				--m = chatservice:FilterStringForBroadcast(m, p)
				table.insert(Sending,{player=p,address=BaseURL.."send",message="msg=["..http:UrlEncode(m).."&id="..http:UrlEncode(Id),base=m})
			end
		end
	end
end

module.connectPlayer = function(p)
	p.Chatted:Connect(function(m)
		Chatted(p,m)
	end)
	SendEvent(p.Name.." chat connected",Colors.Yellow)
end

spawn(function()
	while true do
		pcall(function()
			local received = http:PostAsync(BaseURL.."events","id="..http:UrlEncode(Id), 2)
			local chatdata = http:JSONDecode(received)
			if type(chatdata) == "table" and chatdata[1] ~= nil then
				local context = chatdata[1]
				if context[1]:lower() == "connected" then
					SendEvent("[Stranger Connected]",Colors.Green)
					SendConfirmation()
				elseif context[1]:lower() == "gotmessage" then
					local msg = context[2]
					--msg = chatservice:FilterStringForBroadcast(msg, game.Players:GetPlayers()[1])
					SendEvent("[Stranger]:"..msg,Colors.Cyan)
				elseif context[1]:lower() == "typing" then
					SendEvent("[Stranger Is Typing]",Colors.Green)
				elseif context[1]:lower() == "strangerdisconnected" then
					New()
					SendEvent("[Stranger Left, reconnecting]",Colors.Blue)
				elseif context[1]:lower() == "identdigests" then
					
				else
					print(context[1]:lower(),context[2]:lower())
				end
			end
		end)
		wait(.35)
	end
end)

spawn(function()
	while true do
		pcall(function()
			if #Sending > 0 then
				local Outgoing = Sending[1]
				local Address = Outgoing.address
				local Message = Outgoing.message
				local BaseMsg = Outgoing.base
				local reqpost = http:PostAsync(Address, Message, 2)
				table.remove(Sending, 1)
				SendEvent("[You]: "..BaseMsg,Colors.Yellow)
			end
		end)
		wait(.35)
	end
end)

game:BindToClose(function()
	Disconnect()
end)

return {Connect=module.connectPlayer,OnNetworkEvent=Event}
