local whitelist = {
    "127.0.0.1",
    "YOUR_IP_HERE"
}

local blacklist = {
    "192.168.0.1",
    "10.0.0.1"
}

local request_counters = {} -- Table to keep track of request counts per IP
local max_requests = 5
local traffic_limit = 1 * 1024 * 1024 * 1024 * 1024 -- 1 TB in bytes

-- Table to store traffic data per IP
local traffic_data = {}

-- List of known VPN IP ranges
local vpn_ip_ranges = {
    -- ExpressVPN
    "4.16.32.0/20",
    "4.16.240.0/20",
    "45.64.64.0/22",
    "45.64.80.0/22",
    "45.64.152.0/22",
    "45.64.156.0/22",
    -- NordVPN
    "103.86.96.0/22",
    "185.189.160.0/22",
    "185.189.162.0/23",
    "185.189.164.0/22",
    -- CyberGhost VPN
    "104.238.191.0/24",
    "172.107.86.0/24",
    "185.199.80.0/24",
    -- Private Internet Access
    "10.0.0.0/16",
    "185.233.104.0/22",
    "185.233.106.0/23",
    "185.233.108.0/22",
    -- VyprVPN
    "92.38.160.0/19",
    "185.205.40.0/22",
    "2001:1c00::/32",
    -- Surfshark
    "109.70.60.0/22",
    "172.104.0.0/15",
    "5.252.161.0/24",
    -- StrongVPN
    "216.131.80.0/20",
    "68.65.120.0/21",
    -- Windscribe VPN
    "104.244.72.0/24",
    "172.107.95.0/24",
    -- ProtonVPN
    "185.244.192.0/22",
    "185.244.196.0/23",
    "185.244.198.0/24",
    -- IPVanish
    "64.145.64.0/18",
    "209.99.80.0/21",
    -- TunnelBear VPN
    "172.111.0.0/16",
    "198.7.229.0/24",
    -- Mullvad VPN
    "5.45.64.0/20",
    "185.206.128.0/20",
    -- AirVPN
    "5.196.64.0/19",
    "185.17.184.0/23",
    -- HideMyAss (HMA)
    "5.62.56.0/21",
    "204.11.128.0/17",
    -- Hotspot Shield VPN
    "199.193.246.0/24",
    "64.68.148.0/22",
    -- ZenMate VPN
    "185.207.16.0/22",
    "185.207.20.0/23",
    -- PureVPN
    "5.175.128.0/17",
    "185.128.41.0/24",
    -- Astrill VPN
    "45.32.12.0/22",
    "45.77.32.0/20",
    -- Add more VPN IP ranges as necessary
}

-- Function to check if an IP is in a VPN IP range
local function is_vpn_ip(ip)
    for _, range in ipairs(vpn_ip_ranges) do
        if ngx.re.match(ip, "^" .. range) then
            return true
        end
    end
    return false
end

local function ip_in_list(ip, list)
    for _, value in ipairs(list) do
        if value == ip then
            return true
        end
    end
    return false
end

local function get_client_ip()
    local real_ip = ngx.var.http_x_forwarded_for
    if real_ip then
        local first_ip = real_ip:match("([^,%s]+)")
        if first_ip then
            return first_ip
        end
    end
    return ngx.var.remote_addr
end

-- Function to get traffic data for an IP
local function get_traffic_for_ip(ip)
    return traffic_data[ip] or 0
end

-- Function to update traffic data for an IP
local function update_traffic_for_ip(ip, bytes)
    if not traffic_data[ip] then
        traffic_data[ip] = bytes
    else
        traffic_data[ip] = traffic_data[ip] + bytes
    end
end

local function generate_random_token()
    local charset = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local token = ""
    for i = 1, 8 do
        local index = math.random(1, #charset)
        token = token .. charset:sub(index, index)
    end
    return token
end

local function set_cookie()
    local token = generate_random_token()
    ngx.header['Set-Cookie'] = 'TOKEN=' .. token .. '; path=/; max-age=1800; HttpOnly'
end

local function display_recaptcha(client_ip)
    ngx.header.content_type = 'text/html'
    ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say([[
        <!DOCTYPE html>
        <html>
        <head>
            <title>We are checking your browser...</title>
            <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?compat=recaptcha" async defer></script>
            <style>
                html, body {
                    height: 100%;
                    margin: 0;
                    padding: 0;
                    background: url('https://wallpapercave.com/wp/u0FTYvt.jpg') no-repeat center center fixed; 
                    background-size: cover;
                    color: #fff;
                    font-family: Arial, Helvetica, sans-serif;
                }
                .box {
                    background-color: rgba(0, 0, 0, 0.7);
                    border-radius: 10px;
                    text-align: center;
                    padding: 50px;
                    width: 50%;
                    margin: auto;
                    position: relative;
                    top: 50%;
                    transform: translateY(-50%);
                }
                .footer {
                    position: absolute;
                    bottom: 10px;
                    width: 100%;
                    text-align: center;
                    color: #fff;
                }
                .footer span {
                    color: #0f0;
                }
                .hidden {
                    display: none;
                }
                .unhide-link {
                    cursor: pointer;
                    color: #0f0;
                    text-decoration: underline;
                }
            </style>
            <script>
                function onSubmit(token) {
                    document.cookie = "TOKEN=" + token + "; max-age=1800; path=/";
                    window.location.reload();
                }

                function toggleHidden() {
                    var elem = document.getElementById('ip-details');
                    if (elem.classList.contains('hidden')) {
                        elem.classList.remove('hidden');
                    } else {
                        elem.classList.add('hidden');
                    }
                }

                document.addEventListener('DOMContentLoaded', function() {
                    fetch('/ip-details')
                        .then(response => response.json())
                        .then(data => {
                            document.getElementById('client-ip').textContent = data.client.ip;
                        })
                        .catch(error => console.error('Error fetching IP details:', error));
                });
            </script>
        </head>
        <body>
            <div class="box">
                <h1>We are checking your browser...</h1>
                <p>DDOS Protection by LylaNodes</p>
                <div class="g-recaptcha" data-sitekey="SITE_KEY" data-callback="onSubmit"></div>
                <p class="unhide-link" onclick="toggleHidden()">Click to unhide</p>
                <div id="ip-details" class="hidden">
                    <p>Your IP: ]] .. client_ip .. [[</p>
                </div>
            </div>
            <div class="footer">
                <p>LylaNodes - Protection - <span>2024 2025</span></p>
            </div>
        </body>
        </html>
    ]])
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

local function display_blacklisted_message()
    ngx.header.content_type = 'text/html'
    ngx.status = ngx.HTTP_FORBIDDEN
    ngx.say([[
        <!DOCTYPE html>
        <html>
        <head>
            <title>Blacklisted</title>
            <style>
                html, body {
                    height: 100%;
                    margin: 0;
                    padding: 0;
                    background: url('https://wallpapercave.com/wp/u0FTYvt.jpg') no-repeat center center fixed; 
                    background-size: cover;
                    color: #fff;
                    font-family: Arial, Helvetica, sans-serif;
                }
                .box {
                    background-color: rgba(0, 0, 0, 0.7);
                    border-radius: 10px;
                    text-align: center;
                    padding: 50px;
                    width: 50%;
                    margin: auto;
                    position: relative;
                    top: 50%;
                    transform: translateY(-50%);
                }
                .footer {
                    position: absolute;
                    bottom: 10px;
                    width: 100%;
                    text-align: center;
                    color: #fff;
                }
                .footer span {
                    color: #0f0;
                }
            </style>
        </head>
        <body>
            <div class="box">
                <h1>Blacklisted</h1>
                <p>DDOS Protection by LylaNodes</p>
                <p class="blacklist-message">You are blacklisted from this site. Please contact the owner to resolve this issue if you believe this is a mistake.</p>
            </div>
            <div class="footer">
                <p>LylaNodes - Protection - <span>2024 2025</span></p>
            </div>
        </body>
        </html>
    ]])
    ngx.exit(ngx.HTTP_FORBIDDEN)
end

local function main()
    local client_ip = get_client_ip()
    local user_agent = ngx.var.http_user_agent or ""

    ngx.log(ngx.ERR, "Client IP: " .. tostring(client_ip))

    local lyla_protection_dir = "/var/log/lyla-protection"
    local lyla_protection_log_file = lyla_protection_dir .. "/access.log"

    -- Ensure directory exists
    local mkdir_command = "mkdir -p " .. lyla_protection_dir
    os.execute(mkdir_command)

    local lyla_protection_file, lyla_protection_err = io.open(lyla_protection_log_file, "a")
    if lyla_protection_file then
        -- Get current size of the log file in KB
        local current_file_size_kb = lyla_protection_file:seek("end") / 1024

        local max_log_file_size_kb = 1024 -- 1 MB, you can adjust as needed
        if current_file_size_kb >= max_log_file_size_kb then
            lyla_protection_file:close()
            lyla_protection_file = io.open(lyla_protection_log_file, "w")
            if not lyla_protection_file then
                ngx.log(ngx.ERR, "Failed to truncate lyla-protection access log file")
            end
        end

        local log_line = "Client IP: " .. tostring(client_ip) .. "\n"
        local success, write_err = lyla_protection_file:write(log_line)
        if not success then
            ngx.log(ngx.ERR, "Failed to write to lyla-protection access log file: " .. write_err)
        end
        lyla_protection_file:close()
    else
        ngx.log(ngx.ERR, "Failed to open lyla-protection access log file: " .. lyla_protection_err)
    end

    if ip_in_list(client_ip, blacklist) then
        ngx.log(ngx.ERR, "Client IP is blacklisted: " .. client_ip)
        display_blacklisted_message()
        return
    end

    if ngx.var.request_uri:match("%.php$") or
       ngx.var.request_uri:match("%.js$") or
       ngx.var.request_uri:match("%.html$") or
       ngx.var.request_uri:match("%.jsx$") or
       ngx.var.request_uri:match("%.ts$") or
       ngx.var.request_uri:match("%.tsx$") or
       ngx.var.request_uri:match("%.png$") or
       ngx.var.request_uri:match("%.jpg$") or
       ngx.var.request_uri:match("%.jpeg$") or
       ngx.var.request_uri:match("%.gif$") or
       ngx.var.request_uri:match("%.svg$") or
       ngx.var.request_uri:match("%.ico$") or
       ngx.var.request_uri:match("%.css$") or
       ngx.var.request_uri:match("%.woff$") or
       ngx.var.request_uri:match("%.woff2$") or
       ngx.var.request_uri:match("%.ttf$") or
       ngx.var.request_uri:match("%.eot$") or
       ngx.var.request_uri:match("%.otf$") or
       ngx.var.request_uri:match("%.webp$") then
        ngx.log(ngx.ERR, "Requested file type allowed")
        return
    end

    if ip_in_list(client_ip, whitelist) then
        ngx.log(ngx.ERR, "Client IP is whitelisted: " .. client_ip)
        set_cookie()
        return 
    end

    if ngx.var.cookie_TOKEN then
        ngx.log(ngx.ERR, "Token cookie found")
        return
    end

    ngx.log(ngx.ERR, "Client IP is not whitelisted, showing reCAPTCHA")
    display_recaptcha(client_ip)
end

main()
