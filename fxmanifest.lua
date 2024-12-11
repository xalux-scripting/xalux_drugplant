fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'xalux'
description 'Drug Plant System'
version '1.0.0'


shared_scripts {
    '@ox_lib/init.lua',
    '@es_extended/imports.lua',
    'config.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'sv/server.lua',
}

client_scripts {
    'cl/client.lua',
}

files {
    'buyingPoints.json',
}


