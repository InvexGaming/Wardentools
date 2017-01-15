//Defines
#define KILL_SOUND "invex_gaming/jb_wardentools/orch_hit_csharp_short_clipped.mp3"

//Convars
ConVar cvar_specialdays_oneinthechamber_tptime = null;
ConVar cvar_specialdays_oneinthechamber_hidetime = null;
ConVar cvar_specialdays_oneinthechamber_slaytime = null;
ConVar cvar_specialdays_oneinthechamber_autobeacontime = null;

//Global statics
static bool isEnabled = false;
static const char designatedWeapon[32] = "weapon_deagle";

static bool isPastHideTime = false;
static Handle freeforallRoundEndHandle = null;
static Handle freeforallStartTimer = null;
static bool isFFARoundStalemate = false;
static Handle autoBeaconHandle = null;

public void Specialdays_Init_Oneinthechamber()
{
  Specialdays_RegisterDay("One in the Chamber", Specialdays_Oneinthechamber_Start, Specialdays_Oneinthechamber_End, Specialdays_Oneinthechamber_RestrictionCheck, Specialdays_Oneinthechamber_OnClientPutInServer, false, false);
  
  //Convars
  cvar_specialdays_oneinthechamber_tptime = CreateConVar("sm_wt_specialdays_oneinthechamber_tptime", "10.0", "The amount of time before all players are teleported to start beacon (def. 10.0)");
  cvar_specialdays_oneinthechamber_hidetime = CreateConVar("sm_wt_specialdays_oneinthechamber_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_specialdays_oneinthechamber_slaytime = CreateConVar("sm_wt_specialdays_oneinthechamber_slaytime", "420.0", "The amount of time before all players are slayed (def. 420.0)");
  cvar_specialdays_oneinthechamber_autobeacontime = CreateConVar("sm_wt_specialdays_oneinthechamber_autobeacontime", "300.0", "The amount of time before all players are beaconed and told to actively hunt (def. 300.0)");
  
  //Hooks
  HookEvent("player_spawn", Specialdays_Oneinthechamber_EventPlayerSpawn, EventHookMode_Post);
  HookEvent("player_death", Specialdays_Oneinthechamber_EventPlayerDeath, EventHookMode_Pre);
}

public void Specialdays_Oneinthechamber_Start()
{
  isEnabled = true;
  
  //Remove radar
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      Specialdays_Oneinthechamber_ApplyEffects(i);
    }
  }
  
  //Create timer to slay all players
  freeforallRoundEndHandle = CreateTimer(GetConVarFloat(cvar_specialdays_oneinthechamber_slaytime) - GetTimeSinceRoundStart(), Specialdays_Oneinthechamber_GameEnd);
  
  //Turn on friendly fire for FFA
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
  
  //Create timer for damage protection
  Specialdays_SetDamageProtection(true, GetConVarFloat(cvar_specialdays_oneinthechamber_tptime) + GetConVarFloat(cvar_specialdays_oneinthechamber_hidetime));
  
  //Create Timer for auto beacons
  autoBeaconHandle = CreateTimer(GetConVarFloat(cvar_specialdays_oneinthechamber_autobeacontime) - GetTimeSinceRoundStart(), Specialdays_Oneinthechamber_AutoBeaconOn);
  
  //Day message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - One in the Chamber", RoundToNearest(GetConVarFloat(cvar_specialdays_oneinthechamber_tptime)), RoundToNearest(GetConVarFloat(cvar_specialdays_oneinthechamber_hidetime)));
  
  //Create timer for start
  freeforallStartTimer = CreateTimer(GetConVarFloat(cvar_specialdays_oneinthechamber_tptime) + GetConVarFloat(cvar_specialdays_oneinthechamber_hidetime), Specialdays_Oneinthechamber_GameStart);
  
  //Teleport all players to warden beam
  int warden = GetWarden();
  if (warden != -1)
    Specialdays_TeleportPlayers(warden, GetConVarFloat(cvar_specialdays_oneinthechamber_tptime), "One in the Chamber", Specialdays_Teleport_Start_All, TELEPORTTYPE_ALL);
}

public void Specialdays_Oneinthechamber_End()
{
  isEnabled = false;
  
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

public bool Specialdays_Oneinthechamber_RestrictionCheck()
{
  //Passed with no failures
  return true;
}

public void Specialdays_Oneinthechamber_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_WeaponCanUse, Specialdays_Oneinthechamber_BlockPickup);
  SDKHook(client, SDKHook_OnTakeDamage, Specialdays_Oneinthechamber_OnTakeDamage);
}

//Called when a player takes damage
public Action Specialdays_Oneinthechamber_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim >= 0 && victim <= MaxClients) || !(attacker >= 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }

  if (isEnabled) {
    if (attacker != 0) {
      //Set to kill damage
      damage = 9999.0;
      
      return Plugin_Changed;
    }
  }
  
  return Plugin_Continue;
}

//Player death hook
public Action Specialdays_Oneinthechamber_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
  
  //Award bullet to killer
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  
  if (attacker != 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker)) {
    //Play kill sound for attacker
    EmitSoundToClientAny(attacker, KILL_SOUND, attacker, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN);
  
    if (GetPlayerWeaponSlot(attacker, CS_SLOT_SECONDARY) != -1) {
      int weaponEntity = GetPlayerWeaponSlot(attacker, CS_SLOT_SECONDARY);
      if (weaponEntity != -1) {
        char weaponClassName[64];
        if (GetEdictClassname(weaponEntity, weaponClassName, sizeof(weaponClassName))) {
          if (StrEqual(weaponClassName, designatedWeapon)) {
            //Right weapon, give them 1 bullet
            Handle pack;
            CreateDataTimer(0.0, Specialdays_Oneinthechamber_SetAmmo, pack);
            WritePackCell(pack, EntIndexToEntRef(attacker));
            WritePackCell(pack, EntIndexToEntRef(weaponEntity));
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
  if (numAlive == 1 && lastAliveClient != -1 && !isFFARoundStalemate) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Free For All Winner", lastAliveClient, "One in the Chamber");
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action Specialdays_Oneinthechamber_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
  
  Specialdays_Oneinthechamber_ApplyEffects(client);
  
  return Plugin_Continue;
}

//Apply special day effects
void Specialdays_Oneinthechamber_ApplyEffects(int client)
{
  CreateTimer(0.0, RemoveRadar, client);
  
  //Strip all current weapons from client and give them a knife and their single gun
  StripWeapons(client);
  GivePlayerItem(client, "weapon_knife");
  
  if (isPastHideTime) {
    //Give player their weapon and 1 bullet
    int weaponEntity = GivePlayerItem(client, designatedWeapon);
    
    Handle pack;
    CreateDataTimer(0.0, Specialdays_Oneinthechamber_SetAmmo, pack);
    WritePackCell(pack, EntIndexToEntRef(client));
    WritePackCell(pack, EntIndexToEntRef(weaponEntity));
  }
}

//Timer called once game starts
public Action Specialdays_Oneinthechamber_GameStart(Handle timer)
{
  isPastHideTime = true; //no longer hide time

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {
      Specialdays_Oneinthechamber_ApplyEffects(i);
    }
  }
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - One in the Chamber Started");
  
  freeforallStartTimer = null;
  
  return Plugin_Handled;
}

//Timer called once game ends
public Action Specialdays_Oneinthechamber_GameEnd(Handle timer)
{
  //Set FFA to stalement so no winner is picked based on deaths
  isFFARoundStalemate = true;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      ForcePlayerSuicide(i);
    }
  }
  
  //Print round end message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - One in the Chamber Round Over");
  
  //Reset timer handle
  freeforallRoundEndHandle = null;
}

//Auto beacon all alive players
public Action Specialdays_Oneinthechamber_AutoBeaconOn(Handle timer)
{
  autoBeaconHandle = null;
  
  if (!isEnabled)
    return Plugin_Handled;
    
  ServerCommand("sm_beacon @alive");
  ServerCommand("sm_msay All players must now actively hunt other players.");
  
  return Plugin_Handled;
}

//Block pick of of disallowed guns for entire round
public Action Specialdays_Oneinthechamber_BlockPickup(int client, int weapon)
{
  if (!isEnabled)
    return Plugin_Continue;

  char weaponClass[64];
  GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
  
  //Only knife and gun allowed
  if (!StrEqual(weaponClass, "weapon_knife") && !StrEqual(weaponClass, designatedWeapon))
    return Plugin_Handled;

  return Plugin_Continue;
}

public Action Specialdays_Oneinthechamber_SetAmmo(Handle timer, Handle pack)
{
  int client; 
  int weapon;
  
  ResetPack(pack);
  
  client = EntRefToEntIndex(ReadPackCell(pack)); 
  weapon = EntRefToEntIndex(ReadPackCell(pack)); 
  
  if (IsClientInGame(client) && IsPlayerAlive(client)) {
    
    SetEntProp(weapon, Prop_Send, "m_iClip1", 1);
    SetEntProp(weapon, Prop_Send, "m_iClip2", 0);
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