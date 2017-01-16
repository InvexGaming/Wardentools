//Convars
ConVar cvar_specialdays_ffadm_tptime = null;
ConVar cvar_specialdays_ffadm_hidetime = null;
ConVar cvar_specialdays_ffadm_slaytime = null;
ConVar cvar_specialdays_ffadm_autobeacontime = null;

//Global statics
static bool isEnabled = false;
static int numKills[MAXPLAYERS+1] = {0, ...};
static Handle freeforallRoundEndHandle = null;
static Handle freeforallStartTimer = null;
static bool isFFARoundStalemate = false;
static Handle autoBeaconHandle = null;

public void Specialdays_Init_FfaDm()
{
  Specialdays_RegisterDay("FFA Deathmatch Day", Specialdays_FfaDm_Start, Specialdays_FfaDm_End, Specialdays_FfaDm_RestrictionCheck, Specialdays_FfaDm_OnClientPutInServer, false, false);
  
  //Convars
  cvar_specialdays_ffadm_tptime = CreateConVar("sm_wt_specialdays_ffadm_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  cvar_specialdays_ffadm_hidetime = CreateConVar("sm_wt_specialdays_ffadm_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_specialdays_ffadm_slaytime = CreateConVar("sm_wt_specialdays_ffadm_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  cvar_specialdays_ffadm_autobeacontime = CreateConVar("sm_wt_specialdays_ffadm_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Hooks
  HookEvent("round_prestart", Specialdays_FfaDm_Reset, EventHookMode_Post);
  HookEvent("player_death", Specialdays_FfaDm_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", Specialdays_FfaDm_EventPlayerSpawn, EventHookMode_Post);
}

public void Specialdays_FfaDm_Start() 
{
  isEnabled = true;

  //Apply Effects
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      numKills[i] = 0;
      Specialdays_FfaDm_ApplyEffects(i);
    }
  }
  
  //Create timer to slay all players
  freeforallRoundEndHandle = CreateTimer(GetConVarFloat(cvar_specialdays_ffadm_slaytime) - GetTimeSinceRoundStart(), Specialdays_FfaDm_FfaDmEnd);
  
  //Turn on friendly fire for FFA
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
  
  //Create timer for damage protection
  Specialdays_SetDamageProtection(true, GetConVarFloat(cvar_specialdays_ffadm_tptime) + GetConVarFloat(cvar_specialdays_ffadm_hidetime));
  
  //Create Timer for auto beacons
  autoBeaconHandle = CreateTimer(GetConVarFloat(cvar_specialdays_ffadm_autobeacontime) - GetTimeSinceRoundStart(), Specialdays_FfaDm_AutoBeaconOn); 
  
  //FFADM Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Day", RoundToNearest(GetConVarFloat(cvar_specialdays_ffadm_tptime)), RoundToNearest(GetConVarFloat(cvar_specialdays_ffadm_hidetime)));

  //Show warning
  Specialdays_ShowGameStartWarning(GetConVarFloat(cvar_specialdays_ffadm_tptime) + GetConVarFloat(cvar_specialdays_ffadm_hidetime), 5);
  
  //Create timer for ffa dm start
  freeforallStartTimer = CreateTimer(GetConVarFloat(cvar_specialdays_ffadm_tptime) + GetConVarFloat(cvar_specialdays_ffadm_hidetime), Specialdays_FfaDm_FfaDmStart);
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    Specialdays_TeleportPlayers(warden, GetConVarFloat(cvar_specialdays_ffadm_tptime), "FFA Deathmatch", Specialdays_Teleport_Start_All, TELEPORTTYPE_ALL);
}

public void Specialdays_FfaDm_End() 
{
  isEnabled = false;
}

public bool Specialdays_FfaDm_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

public void Specialdays_FfaDm_OnClientPutInServer() 
{
  //Nop
}

//Round pre start
public void Specialdays_FfaDm_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  if (freeforallRoundEndHandle != null)
    delete freeforallRoundEndHandle;
    
  if (freeforallStartTimer != null)
    delete freeforallStartTimer;
    
  if (autoBeaconHandle != null)
    delete autoBeaconHandle;
    
  isFFARoundStalemate = false;
    
  SetConVarBool(FindConVar("mp_friendlyfire"), false);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), false);
}

//Called when FFADM round ends
public Action Specialdays_FfaDm_FfaDmEnd(Handle timer)
{
  //Set FFA to stalement so no winner is picked based on deaths
  isFFARoundStalemate = true;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Round Over");
  
  //Reset timer handle
  freeforallRoundEndHandle = null;
}

//Player death hook
public Action Specialdays_FfaDm_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
  
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  if (attacker != 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker)) {
    ++numKills[attacker];
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
  if (numAlive == 1 && lastAliveClient != -1 && !isFFARoundStalemate) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "FFA Deathmatch", numKills[lastAliveClient]);
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action Specialdays_FfaDm_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
    
  Specialdays_FfaDm_ApplyEffects(client);
  return Plugin_Continue;
}

//Timer called once FFADM day starts
public Action Specialdays_FfaDm_FfaDmStart(Handle timer)
{
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - FFADM Started");
  
  freeforallStartTimer = null;
  
  return Plugin_Handled;
}
//Auto beacon all alive players
public Action Specialdays_FfaDm_AutoBeaconOn(Handle timer)
{
  autoBeaconHandle = null;
  
  if (!isEnabled)
    return Plugin_Handled;
    
  ServerCommand("sm_beacon @alive");
  ServerCommand("sm_msay All players must now actively hunt other players.");
  
  return Plugin_Handled;
}

//Apply special day effects
void Specialdays_FfaDm_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  GivePlayerItem(client, "item_assaultsuit");
  SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
}