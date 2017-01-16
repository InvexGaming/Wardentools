//Convars
ConVar cvar_specialdays_hungergames_tptime = null;
ConVar cvar_specialdays_hungergames_hidetime = null;
ConVar cvar_specialdays_hungergames_slaytime = null;
ConVar cvar_specialdays_hungergames_minrandomhealth = null;
ConVar cvar_specialdays_hungergames_maxrandomhealth = null;
ConVar cvar_specialdays_hungergames_autobeacontime = null;

//Global statics
static bool isEnabled = false;
static bool isPastHideTime = false;
static int numKills[MAXPLAYERS+1] = {0, ...};
static Handle freeforallRoundEndHandle = null;
static Handle freeforallStartTimer = null;
static bool isFFARoundStalemate = false;
static Handle autoBeaconHandle = null;

static char primaryWeapons[23][] = {"weapon_ak47","weapon_aug","weapon_awp","weapon_bizon","weapon_famas","weapon_g3sg1","weapon_galilar","weapon_m249","weapon_m4a1","weapon_m4a1_silencer","weapon_mac10","weapon_mag7","weapon_mp7","weapon_mp9","weapon_negev","weapon_nova","weapon_p90","weapon_sawedoff","weapon_scar20","weapon_sg556","weapon_ssg08","weapon_ump45","weapon_xm1014"};
static char secondaryWeapons[10][] = {"weapon_cz75a","weapon_deagle","weapon_fiveseven","weapon_elite","weapon_glock","weapon_hkp2000","weapon_p250","weapon_revolver","weapon_usp_silencer","weapon_tec9"};
static char grenades[6][] = {"weapon_decoy","weapon_flashbang","weapon_hegrenade","weapon_incgrenade","weapon_molotov","weapon_smokegrenade"};

public void Specialdays_Init_Hungergames()
{
  Specialdays_RegisterDay("Hunger Games Day", Specialdays_Hungergames_Start, Specialdays_Hungergames_End, Specialdays_Hungergames_RestrictionCheck, Specialdays_Hungergames_OnClientPutInServer, false, false);
  
  //Convars
  cvar_specialdays_hungergames_tptime = CreateConVar("sm_wt_specialdays_hungergames_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  cvar_specialdays_hungergames_hidetime = CreateConVar("sm_wt_specialdays_hungergames_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_specialdays_hungergames_slaytime = CreateConVar("sm_wt_specialdays_hungergames_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  cvar_specialdays_hungergames_minrandomhealth = CreateConVar("sm_wt_specialdays_hungergames_minrandomhealth", "100.0", "The lower bound for randomised health for hunger games (def. 75.0)");
  cvar_specialdays_hungergames_maxrandomhealth = CreateConVar("sm_wt_specialdays_hungergames_maxrandomhealth", "175.0", "The upper bound for randomised health for hunger games (def. 125.0)");
  cvar_specialdays_hungergames_autobeacontime = CreateConVar("sm_wt_specialdays_hungergames_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Hooks
  HookEvent("round_prestart", Specialdays_Hungergames_Reset, EventHookMode_Post);
  HookEvent("player_spawn", Specialdays_Hungergames_EventPlayerSpawn, EventHookMode_Post);
  HookEvent("player_death", Specialdays_Hungergames_EventPlayerDeath, EventHookMode_Pre);
}

public void Specialdays_Hungergames_Start()
{
  isEnabled = true;

  //Remove radar
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      numKills[i] = 0;
      Specialdays_Hungergames_ApplyEffects(i);
    }
  }
  
  //Create timer to slay all players
  freeforallRoundEndHandle = CreateTimer(GetConVarFloat(cvar_specialdays_hungergames_slaytime) - GetTimeSinceRoundStart(), Specialdays_Hungergames_HungergamesRoundEnd);
  
  //Turn on friendly fire for FFA
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
  
  //Create timer for damage protection
  Specialdays_SetDamageProtection(true, GetConVarFloat(cvar_specialdays_hungergames_tptime) + GetConVarFloat(cvar_specialdays_hungergames_hidetime));
  
  //Create Timer for auto beacons
  autoBeaconHandle = CreateTimer(GetConVarFloat(cvar_specialdays_hungergames_autobeacontime) - GetTimeSinceRoundStart(), Specialdays_Hungergames_AutoBeaconOn);
  
  //Hunger Games Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Day", RoundToNearest(GetConVarFloat(cvar_specialdays_hungergames_tptime)), RoundToNearest(GetConVarFloat(cvar_specialdays_hungergames_hidetime)));
  
  //Show warning
  Specialdays_ShowGameStartWarning(GetConVarFloat(cvar_specialdays_hungergames_tptime) + GetConVarFloat(cvar_specialdays_hungergames_hidetime), 5);
  
  //Create timer for start
  freeforallStartTimer = CreateTimer(GetConVarFloat(cvar_specialdays_hungergames_tptime) + GetConVarFloat(cvar_specialdays_hungergames_hidetime), Specialdays_Hungergames_HungergamesStart);
  
  //Teleport all players to warden beam
  int warden = GetWarden();
  if (warden != -1)
    Specialdays_TeleportPlayers(warden, GetConVarFloat(cvar_specialdays_hungergames_tptime), "Hunger Games", Specialdays_Teleport_Start_All, TELEPORTTYPE_ALL);
}

public void Specialdays_Hungergames_End() 
{
  isEnabled = false;
}

public bool Specialdays_Hungergames_RestrictionCheck() 
{
  //Passed with no failures
  return true;
}

//Round pre start
public void Specialdays_Hungergames_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  if (freeforallRoundEndHandle != null)
    delete freeforallRoundEndHandle;
    
  if (freeforallStartTimer != null)
    delete freeforallStartTimer;
    
  if (autoBeaconHandle != null)
    delete autoBeaconHandle;
  
  isPastHideTime = false;
  isFFARoundStalemate = false;
  
  SetConVarBool(FindConVar("mp_friendlyfire"), false);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), false);
}

public void Specialdays_Hungergames_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_WeaponCanUse, Specialdays_Hungergames_BlockPickup);
}

//Player death hook
public Action Specialdays_Hungergames_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
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
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "Hunger Games", numKills[lastAliveClient]);
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action Specialdays_Hungergames_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
  
  Specialdays_Hungergames_ApplyEffects(client);
  
  return Plugin_Continue;
}

//Apply special day effects
void Specialdays_Hungergames_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  
  //Strip all current weapons from client and give them a knife
  StripWeapons(client);
  GivePlayerItem(client, "weapon_knife");
  
  if (isPastHideTime) {
    //Give player random health
    float randomHealth = GetRandomFloat(GetConVarFloat(cvar_specialdays_hungergames_minrandomhealth), GetConVarFloat(cvar_specialdays_hungergames_maxrandomhealth));
    SetEntProp(client, Prop_Data, "m_iHealth", RoundToFloor(randomHealth));
    
    //Give player full armour
    GivePlayerItem(client, "item_assaultsuit");
    SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
    
    //Give player random primary
    int randNum = GetRandomInt(0, sizeof(primaryWeapons) - 1);
    GivePlayerItem(client, primaryWeapons[randNum]);
      
    //Give player random secondary
    randNum = GetRandomInt(0, sizeof(secondaryWeapons) - 1);
    GivePlayerItem(client, secondaryWeapons[randNum]);
    
    //Give player random grenades
    randNum = GetRandomInt(0, sizeof(grenades) - 1);
    GivePlayerItem(client, grenades[randNum]);
  }
}


//Called when hunger games round ends
public Action Specialdays_Hungergames_HungergamesRoundEnd(Handle timer)
{
  //Set FFA to stalement so no winner is picked based on deaths
  isFFARoundStalemate = true;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Round Over");
  
  //Reset timer handle
  freeforallRoundEndHandle = null;
}

//Timer called once hunger games start
public Action Specialdays_Hungergames_HungergamesStart(Handle timer)
{
  isPastHideTime = true; //no longer hide time

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      Specialdays_Hungergames_ApplyEffects(i);
    }
  }
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Hunger Games Started");
  
  freeforallStartTimer = null;
  
  return Plugin_Handled;
}

//Auto beacon all alive players
public Action Specialdays_Hungergames_AutoBeaconOn(Handle timer)
{
  autoBeaconHandle = null;
  
  if (!isEnabled)
    return Plugin_Handled;
    
  ServerCommand("sm_beacon @alive");
  ServerCommand("sm_msay All players must now actively hunt other players.");
  
  return Plugin_Handled;
}

public Action Specialdays_Hungergames_BlockPickup(int client, int weapon)
{
  if (!isEnabled)
    return Plugin_Continue;

  //You can pick up guns after hide time
  if (isPastHideTime)
    return Plugin_Continue;

  char weaponClass[64];
  GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
  
  if (!StrEqual(weaponClass, "weapon_knife"))
    return Plugin_Handled;

  return Plugin_Continue;
}