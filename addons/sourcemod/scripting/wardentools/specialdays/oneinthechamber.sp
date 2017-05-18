//Defines
#define KILL_SOUND "invex_gaming/jb_wardentools/orch_hit_csharp_short_clipped.mp3"

//Convars
ConVar g_Cvar_SpecialDays_OneInTheChamber_TeleportTime = null;
ConVar g_Cvar_SpecialDays_OneInTheChamber_HideTime = null;
ConVar g_Cvar_SpecialDays_OneInTheChamber_SlayTime = null;
ConVar g_Cvar_SpecialDays_OneInTheChamber_AutoBeaconTime = null;

//Global statics
static bool s_IsEnabled = false;
static const char s_DesignatedWeapon[32] = "weapon_deagle";
static int s_NumKills[MAXPLAYERS+1] = {0, ...};
static int s_NumBullets[MAXPLAYERS+1] = {-1, ...};
static bool s_IsPastHideTime = false;
static Handle s_FreeForAllRoundEndHandle = null;
static Handle s_FreeForAllStartTimer = null;
static bool s_IsFfaRoundStalemate = false;
static Handle s_AutoBeaconHandle = null;

public void SpecialDays_Init_OneInTheChamber()
{
  SpecialDays_RegisterDay("One in the Chamber Day", SpecialDays_OneInTheChamber_Start, SpecialDays_OneInTheChamber_End, SpecialDays_OneInTheChamber_RestrictionCheck, SpecialDays_OneInTheChamber_OnClientPutInServer, false, false);
  
  //Convars
  g_Cvar_SpecialDays_OneInTheChamber_TeleportTime = CreateConVar("sm_wt_specialdays_oneinthechamber_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  g_Cvar_SpecialDays_OneInTheChamber_HideTime = CreateConVar("sm_wt_specialdays_oneinthechamber_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  g_Cvar_SpecialDays_OneInTheChamber_SlayTime = CreateConVar("sm_wt_specialdays_oneinthechamber_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  g_Cvar_SpecialDays_OneInTheChamber_AutoBeaconTime = CreateConVar("sm_wt_specialdays_oneinthechamber_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Hooks
  HookEvent("player_spawn", SpecialDays_OneInTheChamber_EventPlayerSpawn, EventHookMode_Post);
  HookEvent("player_death", SpecialDays_OneInTheChamber_EventPlayerDeath, EventHookMode_Post);
  HookEvent("weapon_fire", SpecialDays_OneInTheChamber_EventWeaponFire, EventHookMode_Post);
}

public void SpecialDays_OneInTheChamber_Start()
{
  s_IsEnabled = true;
  
  //Remove radar
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      s_NumKills[i] = 0;
      s_NumBullets[i] = -1;
      SpecialDays_OneInTheChamber_ApplyEffects(i);
    }
  }
  
  //Create timer to slay all players
  s_FreeForAllRoundEndHandle = CreateTimer(g_Cvar_SpecialDays_OneInTheChamber_SlayTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_OneInTheChamber_GameEnd);
  
  //Turn on friendly fire for FFA
  FindConVar("mp_friendlyfire").BoolValue = true;
  FindConVar("mp_teammates_are_enemies").BoolValue = true;
  
  //Create timer for damage protection
  SpecialDays_SetDamageProtection(true, g_Cvar_SpecialDays_OneInTheChamber_TeleportTime.FloatValue + g_Cvar_SpecialDays_OneInTheChamber_HideTime.FloatValue);
  
  //Create Timer for auto beacons
  s_AutoBeaconHandle = CreateTimer(g_Cvar_SpecialDays_OneInTheChamber_AutoBeaconTime.FloatValue - GetTimeSinceRoundStart(), SpecialDays_OneInTheChamber_AutoBeaconOn);
  
  //Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - One in the Chamber", RoundToNearest(g_Cvar_SpecialDays_OneInTheChamber_TeleportTime.FloatValue), RoundToNearest(g_Cvar_SpecialDays_OneInTheChamber_HideTime.FloatValue));
  
  //Show warning
  SpecialDays_ShowGameStartWarning(g_Cvar_SpecialDays_OneInTheChamber_TeleportTime.FloatValue + g_Cvar_SpecialDays_OneInTheChamber_HideTime.FloatValue, 5);
  
  //Create timer for start
  s_FreeForAllStartTimer = CreateTimer(g_Cvar_SpecialDays_OneInTheChamber_TeleportTime.FloatValue + g_Cvar_SpecialDays_OneInTheChamber_HideTime.FloatValue, SpecialDays_OneInTheChamber_GameStart);
  
  //Teleport all players to warden beam
  int warden = GetWarden();
  if (warden != -1)
    SpecialDays_TeleportPlayers(warden, g_Cvar_SpecialDays_OneInTheChamber_TeleportTime.FloatValue, "One in the Chamber", SpecialDays_Teleport_Start_All, TeleportType_All);
}

public void SpecialDays_OneInTheChamber_End()
{
  s_IsEnabled = false;
  
  delete s_FreeForAllRoundEndHandle;
  delete s_FreeForAllStartTimer;
  delete s_AutoBeaconHandle;
  
  s_IsPastHideTime = false;
  s_IsFfaRoundStalemate = false;
  
  FindConVar("mp_friendlyfire").BoolValue = false;
  FindConVar("mp_teammates_are_enemies").BoolValue = false;
}

public bool SpecialDays_OneInTheChamber_RestrictionCheck()
{
  //Passed with no failures
  return true;
}

public void SpecialDays_OneInTheChamber_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_WeaponCanUse, SpecialDays_OneInTheChamber_BlockPickup);
  SDKHook(client, SDKHook_OnTakeDamage, SpecialDays_OneInTheChamber_OnTakeDamage);
  SDKHook(client, SDKHook_WeaponEquip, SpecialDays_OneInTheChamber_WeaponEquip);
}

//Called when a player takes damage
public Action SpecialDays_OneInTheChamber_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim >= 0 && victim <= MaxClients) || !(attacker >= 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }

  if (s_IsEnabled) {
    if (attacker != 0) {
      //Set to kill damage
      damage = 1337.0;
      
      return Plugin_Changed;
    }
  }
  
  return Plugin_Continue;
}

//Player death hook
public Action SpecialDays_OneInTheChamber_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
  
  //Award bullet to killer
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  
  if (attacker != 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker)) {
    //Play kill sound for attacker
    EmitSoundToClientAny(attacker, KILL_SOUND, attacker, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN);
  
    //Increment number kills
    ++s_NumKills[attacker];
  
    if (GetPlayerWeaponSlot(attacker, CS_SLOT_SECONDARY) != -1) {
      int weaponEntity = GetPlayerWeaponSlot(attacker, CS_SLOT_SECONDARY);
      if (weaponEntity != -1) {
        char weaponClassName[64];
        if (GetEdictClassname(weaponEntity, weaponClassName, sizeof(weaponClassName))) {
          if (StrEqual(weaponClassName, s_DesignatedWeapon)) {
            //Right weapon, give them 1 bullet
            DataPack pack;
            CreateDataTimer(0.0, SpecialDays_OneInTheChamber_DelayedSetAmmo, pack);
            pack.WriteCell(EntIndexToEntRef(attacker));
            pack.WriteCell(EntIndexToEntRef(weaponEntity));
            pack.WriteCell(1);
          }
        }
      }
    }
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
  if (numAlive == 1 && lastAliveClient != -1 && !s_IsFfaRoundStalemate) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "One in the Chamber", s_NumKills[lastAliveClient]);
  }
  
  return Plugin_Continue;
}

//We need a delay so that GetClip1Ammo(weapon) returns correct amount
public Action SpecialDays_OneInTheChamber_DelayedSetAmmo(Handle timer, DataPack pack)
{
  int client;
  int weapon;
  int ammo;
  
  pack.Reset();
  
  client = EntRefToEntIndex(pack.ReadCell());
  weapon = EntRefToEntIndex(pack.ReadCell()); 
  ammo = GetClip1Ammo(weapon) + pack.ReadCell(); //current ammo + offset
  
  //Correct num bullets
  s_NumBullets[client] = ammo;
  
  //Set ammo
  DataPack pack2;
  CreateDataTimer(0.0, SpecialDays_OneInTheChamber_SetAmmo, pack2);
  pack2.WriteCell(EntIndexToEntRef(client));
  pack2.WriteCell(EntIndexToEntRef(weapon));
  pack2.WriteCell(ammo);
}

//Player spawn hook
public Action SpecialDays_OneInTheChamber_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
  
  SpecialDays_OneInTheChamber_ApplyEffects(client);
  
  return Plugin_Continue;
}

public Action SpecialDays_OneInTheChamber_EventWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  char weaponClassName[64];
  event.GetString("weapon", weaponClassName, sizeof(weaponClassName));
  
  //Update bullets for shooter after a shot
  if (StrEqual(weaponClassName, s_DesignatedWeapon)) {
    if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1) {
      int weaponEntity = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
      if (weaponEntity != -1) {
        DataPack pack;
        CreateDataTimer(0.2, SpecialDays_OneInTheChamber_UpdateBullets, pack);
        pack.WriteCell(EntIndexToEntRef(client));
        pack.WriteCell(EntIndexToEntRef(weaponEntity));
      }
    }
  }
  
  return Plugin_Continue;
}

//Update bullet count
public Action SpecialDays_OneInTheChamber_UpdateBullets(Handle timer, DataPack pack)
{
  if (!s_IsEnabled)
    return Plugin_Handled;
    
  int client; 
  int weapon;
  
  pack.Reset();
  
  client = EntRefToEntIndex(pack.ReadCell());
  weapon = EntRefToEntIndex(pack.ReadCell());
  
  if (client == INVALID_ENT_REFERENCE || weapon == INVALID_ENT_REFERENCE)
    return Plugin_Handled;
  
  s_NumBullets[client] = GetClip1Ammo(weapon);
  
  return Plugin_Handled;
}

//Apply special day effects
void SpecialDays_OneInTheChamber_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  
  //Strip all current weapons from client and give them a knife and their single gun
  StripWeapons(client);
  GivePlayerItem(client, "weapon_knife");
  
  if (s_IsPastHideTime) {
    //Client will be given 1 bullet
    s_NumBullets[client] = 1;
    
    //Give player their weapon and set ammo to 1 bullet
    int weaponEntity = GivePlayerItem(client, s_DesignatedWeapon);
    
    DataPack pack;
    CreateDataTimer(0.0, SpecialDays_OneInTheChamber_SetAmmo, pack);
    pack.WriteCell(EntIndexToEntRef(client));
    pack.WriteCell(EntIndexToEntRef(weaponEntity));
    pack.WriteCell(1);
  }
}

//Timer called once game starts
public Action SpecialDays_OneInTheChamber_GameStart(Handle timer)
{
  s_FreeForAllStartTimer = null; //Resolve dangling handle
  
  s_IsPastHideTime = true; //no longer hide time

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      SpecialDays_OneInTheChamber_ApplyEffects(i);
    }
  }
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - One in the Chamber Started");
  
  return Plugin_Handled;
}

//Timer called once game ends
public Action SpecialDays_OneInTheChamber_GameEnd(Handle timer)
{
  s_FreeForAllRoundEndHandle = null; //Resolve dangling handle
  
  //Set FFA to stalement so no winner is picked based on deaths
  s_IsFfaRoundStalemate = true;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - One in the Chamber Round Over");
}

//Auto beacon all alive players
public Action SpecialDays_OneInTheChamber_AutoBeaconOn(Handle timer)
{
  s_AutoBeaconHandle = null; //Resolve dangling handle
  
  if (!s_IsEnabled)
    return Plugin_Handled;
    
  ServerCommand("sm_beacon @alive");
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      SetHudTextParams(-1.0, 0.2, 5.0, 255, 0, 0, 120, 0, 1.0, 1.0, 1.0);
      ShowHudText(i, HUDTEXT_CHANNEL_SPECIALDAYS, "YOU MUST NOW ACTIVELY HUNT");
    }
  }
  
  return Plugin_Handled;
}

//Block pick of of disallowed guns for entire round
public Action SpecialDays_OneInTheChamber_BlockPickup(int client, int weapon)
{
  if (!s_IsEnabled)
    return Plugin_Continue;

  char weaponClass[64];
  GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
  
  //Only knife and gun allowed
  if (StrEqual(weaponClass, "weapon_knife"))
    return Plugin_Continue;
  else if (StrEqual(weaponClass, s_DesignatedWeapon) && s_IsPastHideTime) //disallow deagle pick ups in hide time
    return Plugin_Continue;

  return Plugin_Handled;
}

//Use to ensure newly picked up guns from spawners provide correct number of bullets
public Action SpecialDays_OneInTheChamber_WeaponEquip(int client, int weapon)
{
  if (!s_IsEnabled)
    return Plugin_Continue;

  char weaponClass[64];
  GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
  
  if (StrEqual(weaponClass, "weapon_knife"))
    return Plugin_Continue;
  else if (StrEqual(weaponClass, s_DesignatedWeapon)) {
    //Set to correct number of bullets
    if (s_NumBullets[client] != -1) {
      DataPack pack;
      CreateDataTimer(0.0, SpecialDays_OneInTheChamber_SetAmmo, pack);
      pack.WriteCell(EntIndexToEntRef(client));
      pack.WriteCell(EntIndexToEntRef(weapon));
      pack.WriteCell(s_NumBullets[client]);
    }
    
    return Plugin_Continue;
  }
  
  return Plugin_Handled;
}

//Block dropping of weapons
public Action CS_OnCSWeaponDrop(int client, int weaponIndex)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  if (!s_IsPastHideTime)
    return Plugin_Continue;
  
  return Plugin_Handled;
}

stock int GetClip1Ammo(int weapon)
{
  return GetEntProp(weapon, Prop_Send, "m_iClip1");
}

public Action SpecialDays_OneInTheChamber_SetAmmo(Handle timer, DataPack pack)
{
  int client; 
  int weapon;
  int ammo;
  
  pack.Reset();
  
  client = EntRefToEntIndex(pack.ReadCell());
  weapon = EntRefToEntIndex(pack.ReadCell()); 
  ammo = pack.ReadCell(); 
  
  if (IsClientInGame(client) && IsPlayerAlive(client)) {
    
    SetEntProp(weapon, Prop_Send, "m_iClip1", ammo);
    SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 0);

    int offset_ammo = FindDataMapInfo(client, "m_iAmmo");
    int primaryAmmo = 0;
    int secondaryAmmo = 0;
    
    int offset1 = offset_ammo + (GetEntProp(weapon, Prop_Data, "m_iPrimaryAmmoType") * 4);
    SetEntData(client, offset1, primaryAmmo, 4, true);

    int offset2 = offset_ammo + (GetEntProp(weapon, Prop_Data, "m_iSecondaryAmmoType") * 4);
    SetEntData(client, offset2, secondaryAmmo, 4, true);
  }
  
  return Plugin_Handled;
}