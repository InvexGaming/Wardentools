//Convars
ConVar g_Cvar_SpecialDays_HungerGames_TeleportTime = null;
ConVar g_Cvar_SpecialDays_HungerGames_HideTime = null;
ConVar g_Cvar_SpecialDays_HungerGames_SlayTime = null;
ConVar g_Cvar_SpecialDays_HungerGames_MinRandomHealth = null;
ConVar g_Cvar_SpecialDays_HungerGames_MaxRandomHealth = null;
ConVar g_Cvar_SpecialDays_HungerGames_AutoBeaconTime = null;

//Global statics
static bool s_IsEnabled = false;
static bool s_IsPastHideTime = false;
static int s_NumKills[MAXPLAYERS+1] = {0, ...};
static Handle s_FreeForAllRoundEndHandle = null;
static Handle s_FreeForAllStartTimer = null;
static bool s_IsFFARoundStalemate = false;
static Handle s_AutoBeaconHandle = null;

static char s_PrimaryWeapons[23][] = {"weapon_ak47","weapon_aug","weapon_awp","weapon_bizon","weapon_famas","weapon_g3sg1","weapon_galilar","weapon_m249","weapon_m4a1","weapon_m4a1_silencer","weapon_mac10","weapon_mag7","weapon_mp7","weapon_mp9","weapon_negev","weapon_nova","weapon_p90","weapon_sawedoff","weapon_scar20","weapon_sg556","weapon_ssg08","weapon_ump45","weapon_xm1014"};
static char s_SecondaryWeapons[10][] = {"weapon_cz75a","weapon_deagle","weapon_fiveseven","weapon_elite","weapon_glock","weapon_hkp2000","weapon_p250","weapon_revolver","weapon_usp_silencer","weapon_tec9"};
static char s_Grenades[6][] = {"weapon_decoy","weapon_flashbang","weapon_hegrenade","weapon_incgrenade","weapon_molotov","weapon_smokegrenade"};

public void SpecialDays_Init_HungerGames()
{
  SpecialDays_RegisterDay("Hunger Games Day", SpecialDays_HungerGames_Start, SpecialDays_HungerGames_End, SpecialDays_HungerGames_RestrictionCheck, SpecialDays_HungerGames_OnClientPutInServer, false, false);
  
  //Convars
  g_Cvar_SpecialDays_HungerGames_TeleportTime = CreateConVar("sm_wt_specialdays_hungergames_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  g_Cvar_SpecialDays_HungerGames_HideTime = CreateConVar("sm_wt_specialdays_hungergames_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  g_Cvar_SpecialDays_HungerGames_SlayTime = CreateConVar("sm_wt_specialdays_hungergames_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  g_Cvar_SpecialDays_HungerGames_MinRandomHealth = CreateConVar("sm_wt_specialdays_hungergames_minrandomhealth", "100.0", "The lower bound for randomised health for hunger games (def. 75.0)");
  g_Cvar_SpecialDays_HungerGames_MaxRandomHealth = CreateConVar("sm_wt_specialdays_hungergames_maxrandomhealth", "175.0", "The upper bound for randomised health for hunger games (def. 125.0)");
  g_Cvar_SpecialDays_HungerGames_AutoBeaconTime = CreateConVar("sm_wt_specialdays_hungergames_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Hooks
  HookEvent("round_prestart", SpecialDays_HungerGames_Reset, EventHookMode_Post);
  HookEvent("player_spawn", SpecialDays_HungerGames_EventPlayerSpawn, EventHookMode_Post);
  HookEvent("player_death", SpecialDays_HungerGames_EventPlayerDeath, EventHookMode_Pre);
}

public void SpecialDays_HungerGames_Start()
{
  s_IsEnabled = true;

  //Remove radar
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      s_NumKills[i] = 0;
      SpecialDays_HungerGames_ApplyEffects(i);
    }
  }
  
  //Create timer to slay all players
  s_FreeForAllRoundEndHandle = CreateTimer(g_Cvar_SpecialDays_HungerGames_SlayTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_HungerGames_HungerGamesRoundEnd);
  
  //Turn on friendly fire for FFA
  FindConVar("mp_friendlyfire").BoolValue = true;
  FindConVar("mp_teammates_are_enemies").BoolValue = true;
  
  //Create timer for damage protection
  SpecialDays_SetDamageProtection(true, g_Cvar_SpecialDays_HungerGames_TeleportTime.FloatValue + g_Cvar_SpecialDays_HungerGames_HideTime.FloatValue);
  
  //Create Timer for auto beacons
  s_AutoBeaconHandle = CreateTimer(g_Cvar_SpecialDays_HungerGames_AutoBeaconTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_HungerGames_AutoBeaconOn);
  
  //Hunger Games Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Day", RoundToNearest(g_Cvar_SpecialDays_HungerGames_TeleportTime.FloatValue), RoundToNearest(g_Cvar_SpecialDays_HungerGames_HideTime.FloatValue));
  
  //Show warning
  SpecialDays_ShowGameStartWarning(g_Cvar_SpecialDays_HungerGames_TeleportTime.FloatValue + g_Cvar_SpecialDays_HungerGames_HideTime.FloatValue, 5);
  
  //Create timer for start
  s_FreeForAllStartTimer = CreateTimer(g_Cvar_SpecialDays_HungerGames_TeleportTime.FloatValue + g_Cvar_SpecialDays_HungerGames_HideTime.FloatValue, SpecialDays_HungerGames_HungerGamesStart);
  
  //Teleport all players to warden beam
  int warden = GetWarden();
  if (warden != -1)
    SpecialDays_TeleportPlayers(warden, g_Cvar_SpecialDays_HungerGames_TeleportTime.FloatValue, "Hunger Games", SpecialDays_Teleport_Start_All, TeleportType_All);
}

public void SpecialDays_HungerGames_End() 
{
  s_IsEnabled = false;
}

public bool SpecialDays_HungerGames_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

//Round pre start
public void SpecialDays_HungerGames_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  delete s_FreeForAllRoundEndHandle;
  delete s_FreeForAllStartTimer;
  delete s_AutoBeaconHandle;
  
  s_IsPastHideTime = false;
  s_IsFFARoundStalemate = false;
  
  FindConVar("mp_friendlyfire").BoolValue = false;
  FindConVar("mp_teammates_are_enemies").BoolValue = false;
}

public void SpecialDays_HungerGames_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_WeaponCanUse, SpecialDays_HungerGames_BlockPickup);
}

//Player death hook
public Action SpecialDays_HungerGames_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
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
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "Hunger Games", s_NumKills[lastAliveClient]);
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action SpecialDays_HungerGames_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
  
  SpecialDays_HungerGames_ApplyEffects(client);
  
  return Plugin_Continue;
}

//Apply special day effects
void SpecialDays_HungerGames_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  
  //Strip all current weapons from client and give them a knife
  StripWeapons(client);
  GivePlayerItem(client, "weapon_knife");
  
  if (s_IsPastHideTime) {
    //Give player random health
    float randomHealth = GetRandomFloat(g_Cvar_SpecialDays_HungerGames_MinRandomHealth.FloatValue, g_Cvar_SpecialDays_HungerGames_MaxRandomHealth.FloatValue);
    SetEntProp(client, Prop_Data, "m_iHealth", RoundToFloor(randomHealth));
    
    //Give player full armour
    GivePlayerItem(client, "item_assaultsuit");
    SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
    
    //Give player random primary
    int randNum = GetRandomInt(0, sizeof(s_PrimaryWeapons) - 1);
    GivePlayerItem(client, s_PrimaryWeapons[randNum]);
      
    //Give player random secondary
    randNum = GetRandomInt(0, sizeof(s_SecondaryWeapons) - 1);
    GivePlayerItem(client, s_SecondaryWeapons[randNum]);
    
    //Give player random s_Grenades
    randNum = GetRandomInt(0, sizeof(s_Grenades) - 1);
    GivePlayerItem(client, s_Grenades[randNum]);
  }
}


//Called when hunger games round ends
public Action SpecialDays_HungerGames_HungerGamesRoundEnd(Handle timer)
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
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Round Over");
}

//Timer called once hunger games start
public Action SpecialDays_HungerGames_HungerGamesStart(Handle timer)
{
  s_FreeForAllStartTimer = null; //Resolve dangling handle
  
  s_IsPastHideTime = true; //no longer hide time

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      SpecialDays_HungerGames_ApplyEffects(i);
    }
  }
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Started");
  
  return Plugin_Handled;
}

//Auto beacon all alive players
public Action SpecialDays_HungerGames_AutoBeaconOn(Handle timer)
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

public Action SpecialDays_HungerGames_BlockPickup(int client, int weapon)
{
  if (!s_IsEnabled)
    return Plugin_Continue;

  //You can pick up guns after hide time
  if (s_IsPastHideTime)
    return Plugin_Continue;

  char weaponClass[64];
  GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
  
  if (!StrEqual(weaponClass, "weapon_knife"))
    return Plugin_Handled;

  return Plugin_Continue;
}