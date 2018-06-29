public Plugin myinfo = 
{
    name        = "[CAT] - VPN/Proxy detector",
    author      = "Kyle \"Kxnrl\" Frankiss",
    description = "Kick client if using VPN",
    version     = "1.0",
    url         = "https://kxnrl.com"
};

#pragma semicolon 1
#pragma newdecls required

#define URL "https://api.kxnrl.com/Anti-Proxy/?id="

#include <system2>
#include <smutils>

Database g_hDB;

static Handle g_tCheck[MAXPLAYERS+1];
static bool g_bCheck[MAXPLAYERS+1];
static bool g_bPass[MAXPLAYERS+1];

public void OnPluginStart()
{
    SMUtils_SetChatPrefix(" \x0A[\x02CAT\x0A]\x01");
    SMUtils_SetChatConSnd(true);

    Database.Connect(Database_OnConnected, "default");
}

public void Database_OnConnected(Database db, const char[] error, any data)
{
    if(db == null || error[0])
        SetFailState("Failed to connect to database: %s", error);

    g_hDB = db;

    db.SetCharset("utf8");
    db.Query(Database_OnInited, "CREATE TABLE IF NOT EXISTS `k_antiproxy` (`steamid` int(11) unsigned NOT NULL DEFAULT '0', `ip` varchar(24) NOT NULL DEFAULT '0.0.0.0', `retry` tinyint(3) unsigned NOT NULL DEFAULT '0', `result` tinyint(3) unsigned NOT NULL DEFAULT '0', PRIMARY KEY (`steamid`)) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
}

public void Database_OnInited(Database db, DBResultSet results, const char[] error, any unuse)
{
    if(results == null || error[0])
        SetFailState("Failed to create table: %s", error);
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
    if(g_hDB == null)
    {
        strcopy(rejectmsg, maxlen, "CAT Server is unavailable now. Please try again later.");
        return false;
    }
    
    return true;
}

public void OnClientConnected(int client)
{
    g_bPass[client] = false;
    g_bCheck[client] = false;
}

public void OnClientDisconnect(int client)
{
    g_bPass[client] = false;
    g_bCheck[client] = false;

    StopTimer(g_tCheck[client]);
}

public void OnClientPutInServer(int client)
{
    if(IsFakeClient(client))
        return;

    g_tCheck[client] = CreateTimer(10.0, Timer_Delay, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Delay(Handle timer, int client)
{
    g_tCheck[client] = null;
    
    if(!ClientIsValid(client))
        return Plugin_Stop;
    
    int account = GetSteamAccountID(client, true);
    if(account < 1)
    {
        Log("Kick \"%L\" :  Invalid SteamId detected!", client);
        KickClient(client, "Invalid SteamId detected!");
        return Plugin_Stop;
    }

    char ip[24];
    GetClientIP(client, ip, 24, true);

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "REPLACE INTO k_antiproxy VALUES (%d, '%s', 0, 0);",  account, ip);
    g_hDB.Query(Database_OnInserted, m_szQuery, GetClientUserId(client), DBPrio_High);

    return Plugin_Stop;
}

public void Database_OnInserted(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!ClientIsValid(client))
        return;

    if(results == null || error[0])
    {
        LogError("Failed to Insert \"%L\" data: %s", client, error);
        return;
    }

    ForwardClient(client);
}

public Action Timer_Destroy(Handle timer, int client)
{
    g_tCheck[client] = null;
    
    if(!ClientIsValid(client))
        return Plugin_Stop;

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "SELECT `retry`, `result` FROM `k_antiproxy` WHERE steamid = %d", GetSteamAccountID(client));
    g_hDB.Query(Database_OnChecked, m_szQuery, GetClientUserId(client), DBPrio_High);

    return Plugin_Stop;
}

public void Database_OnChecked(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!ClientIsValid(client) || !g_bCheck[client] || g_bPass[client])
        return;

    if(results == null || error[0])
    {
        LogError("Failed to Check \"%L\" data: %s", client, error);
        return;
    }

    if(!results.FetchRow() || results.RowCount != 1)
    {
        LogError("Failed to Check \"%L\" data: No results", client);
        return;
    }

    int result = results.FetchInt(1);
    
    if(result == 2)
    {
        g_bPass[client] = true;
        return;
    }

    if(result == 1)
    {
        Log("Kick \"%L\" :  Proxy / VPN detected", client);
        KickClient(client, "Proxy / VPN detected!\nPlease reconncct to server after closing vpn and proxy!\n服务器当前禁止使用代理或VPN\n请关闭VPN和代理后重试!");
        return;
    }

    int ret = results.FetchInt(0);

    if(++ret >= 5)
    {
        Log("Kick \"%L\" :  Failed to connect to CAT server", client);
        KickClient(client, "Failed to connect to CAT server!\nPlease check your network connection.\n无法连接到CAT服务器!\n请检查您的网络连接");
        return;
    }

    char m_szQuery[128];
    FormatEx(m_szQuery, 128, "UPDATE k_antiproxy SET `retry` = `retry` + 1 WHERE steamid=%d", GetSteamAccountID(client));
    g_hDB.Query(Database_OnUpdated, m_szQuery, userid);
    PrintToConsole(client, "[CAT] Retrying... %d", ret);
}

public void Database_OnUpdated(Database db, DBResultSet results, const char[] error, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!ClientIsValid(client))
        return;
    
    if(results == null || error[0])
    {
        LogError("Failed to Update \"%L\" data: %s", client, error);
        return;
    }

    ForwardClient(client);
}

static void ForwardClient(int client)
{
    g_bCheck[client] = true;
    
    if(g_bPass[client])
        return;
    
    char url[192];
    FormatEx(url, 192, "%s%d", URL, GetSteamAccountID(client));

    KeyValues kv = new KeyValues("data");
    kv.SetString("title", "Anti Proxy");
    kv.SetNum("type", MOTDPANEL_TYPE_URL);
    kv.SetNum("cmd", 0);
    kv.SetString("msg", url);
    ShowVGUIPanel(client, "info", kv, false);
    delete kv;

    g_tCheck[client] = CreateTimer(15.0, Timer_Destroy, client, TIMER_FLAG_NO_MAPCHANGE);
}

static void Log(const char[] buffer, any ...)
{
    char log[256];
    VFormat(log, 256, buffer, 2);
    LogToFileEx("addons/sourcemod/logs/cat.log", log);
}