# This is LylaNodes Protection Layer 7 for your sites!



## Setting it up!

### Files
You will have to install lyla-script to use this and in order for this to work. Please Install the script by running
```sh
bash <(curl https://raw.githubusercontent.com/vekalmao/lyla-script/main/ddos_lylanodes.sh)
```

### Installing
You then go to the directory ``/etc/nginx/conf.d/layer7` and download **ddos.lua** into it. Run this below to download it:
```sh
curl -Lo protect.lua https://raw.githubusercontent.com/vekalmao/lyla-script-layer-7/main/protect.lua
```

### File manageing
After downloading the files, and eveything you would have to whitelist your IP's, for it to give requests to your panels,websites, and more.
```lua
local whitelist = {
    "127.0.0.1",
	"YOUR_IP_HERE"
}
```

Now go to ddos.lua and change the SITE-KEY to your cloudflare site key please.
```lua
<div class="g-recaptcha" data-sitekey="SITE-KEY" data-callback="onSubmit"></div>
```

## How to get the cloudflare key?
Go To Cloudflare
Go to Turnstile 
Press "Add Site"
Give it a name, Then click "Domains", "Managed", Then select "No" and press "Create". It will give you your Site Key!

## How do i make this enabled on nginx?
There is only 1 way for right now which is below.

#### Method 1: 
 You can edit the ``nginx.conf``, And add this below the ``http {``:
```lua
access_by_lua_file /etc/nginx/conf.d/lyla-script-layer-7/protect.lua;
```


# Support
If you need help with errors or anything please join the discord server
https://discord.gg/lylanodes

# Credits
# Relational Throne
