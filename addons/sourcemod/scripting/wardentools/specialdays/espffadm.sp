#include "wardentools/esp.sp"

//Convars
ConVar g_Cvar_SpecialDays_EspFfaDm_TeleportTime = null;
ConVar g_Cvar_SpecialDays_EspFfaDm_HideTime = null;
ConVar g_Cvar_SpecialDays_EspFfaDm_SlayTime = null;
ConVar g_Cvar_SpecialDays_EspFfaDm_AutoMustHuntTime = null;

//Global statics
static bool s_IsEnabled = false;
static int s_NumKills[MAXPLAYERS+1] = {0, ...};
static Handle s_FreeForAllRoundEndHandle = null;
static Handle s_FreeForAllStartTimer = null;
static bool s_IsFFARoundStalemate = false;
static bool s_DayStarted = false;
static Handle s_AutoMustHuntHandle = null;
static int s_EspColour[] = {255, 0, 0, 200};

public void SpecialDays_Init_EspFfaDm()
{
  SpecialDays_RegisterDay("ESP FFA Deathmatch Day", SpecialDays_EspFfaDm_Start, SpecialDays_EspFfaDm_End, SpecialDays_EspFfaDm_RestrictionCheck, SpecialDays_EspFfaDm_OnClientPutInServer, false, false);
  
  //Convars
  g_Cvar_SpecialDays_EspFfaDm_TeleportTime = CreateConVar("sm_wt_specialdays_espffadm_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  g_Cvar_SpecialDays_EspFfaDm_HideTime = CreateConVar("sm_wt_specialdays_espffadm_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  g_Cvar_SpecialDays_EspFfaDm_SlayTime = CreateConVar("sm_wt_specialdays_espffadm_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  g_Cvar_SpecialDays_EspFfaDm_AutoMustHuntTime = CreateConVar("sm_wt_specialdays_espffadm_automusthunttime", "300.0", "The amount of time before all players are told to actively hunt (def. 300.0)");
  
  //Hooks
  HookEvent("round_prestart", SpecialDays_EspFfaDm_Reset, EventHookMode_Post);
  HookEvent("player_death", SpecialDays_EspFfaDm_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", SpecialDays_EspFfaDm_EventPlayerSpawn, EventHookMode_Post);
}

public void SpecialDays_EspFfaDm_Start() 
{
  s_IsEnabled = true;
  s_DayStarted = false;

  //Apply Effects
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      if (IsPlayerAlive(i))
        s_NumKills[i] = 0;
        
      SpecialDays_EspFfaDm_ApplyEffects(i);
    }
  }
  
  //Create timer to slay all players
  s_FreeForAllRoundEndHandle = CreateTimer(g_Cvar_SpecialDays_EspFfaDm_SlayTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_EspFfaDm_EspFfaDmEnd);
  
  //Turn on friendly fire for FFA
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
  
  //Create timer for damage protection
  SpecialDays_SetDamageProtection(true, g_Cvar_SpecialDays_EspFfaDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_EspFfaDm_HideTime.FloatValue);
  
  //Create Timer for auto beacons
  s_AutoMustHuntHandle = CreateTimer(g_Cvar_SpecialDays_EspFfaDm_AutoMustHuntTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_EspFfaDm_AutoMustHuntMsgOn); 
  
  //ESP FFADM Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - ESP FFADM Day", RoundToNearest(g_Cvar_SpecialDays_EspFfaDm_TeleportTime.FloatValue), RoundToNearest(g_Cvar_SpecialDays_EspFfaDm_HideTime.FloatValue));

  //Show warning
  SpecialDays_ShowGameStartWarning(g_Cvar_SpecialDays_EspFfaDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_EspFfaDm_HideTime.FloatValue, 5);
  
  //Create timer for ffa dm start
  s_FreeForAllStartTimer = CreateTimer(g_Cvar_SpecialDays_EspFfaDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_EspFfaDm_HideTime.FloatValue, SpecialDays_EspFfaDm_EspFfaDmStart);
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    SpecialDays_TeleportPlayers(warden, g_Cvar_SpecialDays_EspFfaDm_TeleportTime.FloatValue, "ESP FFA Deathmatch", SpecialDays_Teleport_Start_All, TeleportType_All);
}

public void SpecialDays_EspFfaDm_End() 
{
  s_IsEnabled = false;
  
  Esp_Reset(); //remove esp
}

public bool SpecialDays_EspFfaDm_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void SpecialDays_EspFfaDm_OnClientPutInServer() 
{
  //Nop
}

//Round pre start
public void SpecialDays_EspFfaDm_Reset(Event event, const char[] name, bool dontBroadcast)
{
  delete s_FreeForAllRoundEndHandle;
  delete s_FreeForAllStartTimer;
  delete s_AutoMustHuntHandle;
    
  s_IsFFARoundStalemate = false;
  s_DayStarted = false;
  
  FindConVar("mp_friendlyfire").BoolValue = false;
  FindConVar("mp_teammates_are_enemies").BoolValue = false;
}

//Called when FFADM round ends
public Action SpecialDays_EspFfaDm_EspFfaDmEnd(Handle timer)
{
  s_FreeForAllRoundEndHandle = null; //Resolve dangling handle
  
  //Set FFA to stalement so no winner is picked based on deaths
  s_IsFFARoundStalemate = true;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - ESP FFADM Round Over");
}

//Player death hook
public Action SpecialDays_EspFfaDm_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
  
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  if (attacker != 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker)) {
    ++s_NumKills[attacker];
  }
  
  //Count number of alive players
  int numAlive = 0;
  int lastAliveClient = -1;
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ++numAlive;
      lastAliveClient = i;
    }
  }
  
  //Check if there is only 1 remaining player
  if (numAlive == 1 && lastAliveClient != -1 && !s_IsFFARoundStalemate) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "ESP FFA Deathmatch", s_NumKills[lastAliveClient]);
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action SpecialDays_EspFfaDm_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
    
  SpecialDays_EspFfaDm_ApplyEffects(client);
  
  if (s_DayStarted) {
    Esp_SetIsUsingEsp(client, true);
    Esp_CheckGlows(); //Refresh Glows
  }
  
  return Plugin_Continue;
}

//Timer called once FFADM day starts
public Action SpecialDays_EspFfaDm_EspFfaDmStart(Handle timer)
{
  s_FreeForAllStartTimer = null;
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - ESP FFADM Started");

  //Set ESP for teams for all clients
  for (int i = 1; i <= MaxClients; ++i) {
    Esp_SetIsUsingEsp(i, true);
  }
  
  Esp_CheckGlows(); //Refresh Glows
  
  s_DayStarted = true;
  
  return Plugin_Handled;
}
//Auto beacon all alive players
public Action SpecialDays_EspFfaDm_AutoMustHuntMsgOn(Handle timer)
{
  s_AutoMustHuntHandle = null;
  
  if (!s_IsEnabled)
    return Plugin_Handled;
    
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      SetHudTextParams(-1.0, 0.2, 5.0, 255, 0, 0, 120, 0, 1.0, 1.0, 1.0);
      ShowHudText(i, -1, "YOU MUST NOW ACTIVELY HUNT");
    }
  }
  
  return Plugin_Handled;
}

//Apply special day effects
void SpecialDays_EspFfaDm_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  
  if (IsPlayerAlive(client)) {
    GivePlayerItem(client, "item_assaultsuit");
    SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
  }
  
  //Prepare ESP
  Esp_SetIsUsingEsp(client, false); //will be turned on when ready
  Esp_SetEspColour(client, s_EspColour);
  for (int i = 1; i <= MaxClients; ++i) {
    Esp_SetEspCanSeeClient(client, i, true);
  }
}