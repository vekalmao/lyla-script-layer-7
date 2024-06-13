local whitelist = {
    "127.0.0.1",
    "YOUR_IP_HERE"
}

local blacklist = {}

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

local function display_recaptcha()
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
            </style>
            <script>
                function onSubmit(token) {
                    document.cookie = "TOKEN=" + token + "; max-age=1800; path=/";
                    window.location.reload();
                }
            </script>
        </head>
        <body>
            <div class="box">
                <h1>We are checking your browser...</h1>
                <p>DDOS Protection by LylaNodes</p>
                <div class="g-recaptcha" data-sitekey="SITE-KEY" data-callback="onSubmit"></div>
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

    if ip_in_list(client_ip, blacklist) then
        ngx.log(ngx.ERR, "Client IP is blacklisted: " .. client_ip)
        ngx.exit(ngx.HTTP_FORBIDDEN)
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
        set_cookie() -- Generate token for whitelisted IP
        return 
    end

    if ngx.var.cookie_TOKEN then
        ngx.log(ngx.ERR, "Token cookie found")
        return -- Allow the request to proceed normally
    end

    ngx.log(ngx.ERR, "Client IP is not whitelisted, showing reCAPTCHA")
    display_recaptcha()
end

main()
