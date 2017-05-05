//Convars
ConVar g_Cvar_SpecialDays_FfaDm_TeleportTime = null;
ConVar g_Cvar_SpecialDays_FfaDm_HideTime = null;
ConVar g_Cvar_SpecialDays_FfaDm_SlayTime = null;
ConVar g_Cvar_SpecialDays_FfaDm_AutoBeaconTime = null;

//Global statics
static bool s_IsEnabled = false;
static int s_NumKills[MAXPLAYERS+1] = {0, ...};
static Handle s_FreeForAllRoundEndHandle = null;
static Handle s_FreeForAllStartTimer = null;
static bool s_IsFFARoundStalemate = false;
static Handle s_AutoBeaconHandle = null;

public void SpecialDays_Init_FfaDm()
{
  SpecialDays_RegisterDay("FFA Deathmatch Day", SpecialDays_FfaDm_Start, SpecialDays_FfaDm_End, SpecialDays_FfaDm_RestrictionCheck, SpecialDays_FfaDm_OnClientPutInServer, false, false);
  
  //Convars
  g_Cvar_SpecialDays_FfaDm_TeleportTime = CreateConVar("sm_wt_specialdays_ffadm_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  g_Cvar_SpecialDays_FfaDm_HideTime = CreateConVar("sm_wt_specialdays_ffadm_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  g_Cvar_SpecialDays_FfaDm_SlayTime = CreateConVar("sm_wt_specialdays_ffadm_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  g_Cvar_SpecialDays_FfaDm_AutoBeaconTime = CreateConVar("sm_wt_specialdays_ffadm_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Hooks
  HookEvent("round_prestart", SpecialDays_FfaDm_Reset, EventHookMode_Post);
  HookEvent("player_death", SpecialDays_FfaDm_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", SpecialDays_FfaDm_EventPlayerSpawn, EventHookMode_Post);
}

public void SpecialDays_FfaDm_Start() 
{
  s_IsEnabled = true;

  //Apply Effects
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      s_NumKills[i] = 0;
      SpecialDays_FfaDm_ApplyEffects(i);
    }
  }
  
  //Create timer to slay all players
  s_FreeForAllRoundEndHandle = CreateTimer(g_Cvar_SpecialDays_FfaDm_SlayTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_FfaDm_FfaDmEnd);
  
  //Turn on friendly fire for FFA
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
  
  //Create timer for damage protection
  SpecialDays_SetDamageProtection(true, g_Cvar_SpecialDays_FfaDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_FfaDm_HideTime.FloatValue);
  
  //Create Timer for auto beacons
  s_AutoBeaconHandle = CreateTimer(g_Cvar_SpecialDays_FfaDm_AutoBeaconTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_FfaDm_AutoBeaconOn); 
  
  //FFADM Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Day", RoundToNearest(g_Cvar_SpecialDays_FfaDm_TeleportTime.FloatValue), RoundToNearest(g_Cvar_SpecialDays_FfaDm_HideTime.FloatValue));

  //Show warning
  SpecialDays_ShowGameStartWarning(g_Cvar_SpecialDays_FfaDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_FfaDm_HideTime.FloatValue, 5);
  
  //Create timer for ffa dm start
  s_FreeForAllStartTimer = CreateTimer(g_Cvar_SpecialDays_FfaDm_TeleportTime.FloatValue + g_Cvar_SpecialDays_FfaDm_HideTime.FloatValue, SpecialDays_FfaDm_FfaDmStart);
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    SpecialDays_TeleportPlayers(warden, g_Cvar_SpecialDays_FfaDm_TeleportTime.FloatValue, "FFA Deathmatch", SpecialDays_Teleport_Start_All, TeleportType_All);
}

public void SpecialDays_FfaDm_End() 
{
  s_IsEnabled = false;
}

public bool SpecialDays_FfaDm_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void SpecialDays_FfaDm_OnClientPutInServer() 
{
  //Nop
}

//Round pre start
public void SpecialDays_FfaDm_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  delete s_FreeForAllRoundEndHandle;
  delete s_FreeForAllStartTimer;
  delete s_AutoBeaconHandle;
    
  s_IsFFARoundStalemate = false;
  
  FindConVar("mp_friendlyfire").BoolValue = false;
  FindConVar("mp_teammates_are_enemies").BoolValue = false;
}

//Called when FFADM round ends
public Action SpecialDays_FfaDm_FfaDmEnd(Handle timer)
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
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Round Over");
}

//Player death hook
public Action SpecialDays_FfaDm_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
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
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "FFA Deathmatch", s_NumKills[lastAliveClient]);
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action SpecialDays_FfaDm_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
    
  SpecialDays_FfaDm_ApplyEffects(client);
  return Plugin_Continue;
}

//Timer called once FFADM day starts
public Action SpecialDays_FfaDm_FfaDmStart(Handle timer)
{
  s_FreeForAllStartTimer = null;
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Started");
  
  return Plugin_Handled;
}
//Auto beacon all alive players
public Action SpecialDays_FfaDm_AutoBeaconOn(Handle timer)
{
  s_AutoBeaconHandle = null;
  
  if (!s_IsEnabled)
    return Plugin_Handled;
    
  ServerCommand("sm_beacon @alive");

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i)) {
      SetHudTextParams(-1.0, -1.0, 5.0, 255, 0, 0, 200, 0, 1.0, 1.0, 1.0);
      ShowHudText(i, -1, "YOU MUST NOW ACTIVELY HUNT");
    }
  }
  
  return Plugin_Handled;
}

//Apply special day effects
void SpecialDays_FfaDm_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  GivePlayerItem(client, "item_assaultsuit");
  SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
}