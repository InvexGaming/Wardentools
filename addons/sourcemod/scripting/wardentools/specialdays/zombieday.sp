#include "wardentools/blind.sp"

//Defines
#define INFECT_SOUND_1 "invex_gaming/jb_wardentools/infected_1.mp3"
#define INFECT_SOUND_2 "invex_gaming/jb_wardentools/infected_2.mp3"
#define INFECT_SOUND_3 "invex_gaming/jb_wardentools/infected_3.mp3"
#define INFECT_DEATH_SOUND_1 "invex_gaming/jb_wardentools/infected_death1.mp3"
#define INFECT_DEATH_SOUND_2 "invex_gaming/jb_wardentools/infected_death2.mp3"

//Static globals
static bool isEnabled = false;
static Handle zombiedayNonInfectedWinHandle = null;
static bool isInfected[MAXPLAYERS+1] = {false, ...};
static bool isInInfectedHideTime = false;
static int infectedIcon[MAXPLAYERS+1] = {-1, ...};
static bool isPastCureFoundTime = false;
static Handle drainTimer = null;
static Handle infectionStartTimer = null;

static bool restoreClanTags = false;
static char clantagStorage[MAXPLAYERS+1][32];

//Convars
ConVar cvar_specialdays_zombieday_tptime = null;
ConVar cvar_specialdays_zombieday_hidetime = null;
ConVar cvar_specialdays_zombieday_noninfectedwintime = null;
ConVar cvar_specialdays_zombieday_infectedhealth = null;
ConVar cvar_specialdays_zombieday_infectedspeed = null;
ConVar cvar_specialdays_zombieday_infectedgravity = null;
ConVar cvar_specialdays_zombieday_min_drain = null;
ConVar cvar_specialdays_zombieday_max_drain = null;
ConVar cvar_specialdays_zombieday_drain_interval = null;

public void Specialdays_Init_ZombieDay()
{
  Specialdays_RegisterDay("Zombie Day", Specialdays_ZombieDay_Start, Specialdays_ZombieDay_End, Specialdays_ZombieDay_RestrictionCheck, Specialdays_ZombieDay_OnClientPutInServer, false, false);
  
  //Convars
  cvar_specialdays_zombieday_tptime = CreateConVar("sm_wt_specialdays_zombieday_tptime", "10.0", "The amount of time before prisoners are teleported to start beacon (def. 10.0)");
  cvar_specialdays_zombieday_hidetime = CreateConVar("sm_wt_specialdays_zombieday_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  cvar_specialdays_zombieday_noninfectedwintime = CreateConVar("sm_wt_specialdays_zombieday_noninfectedwintime", "420.0", "The amount of time before non infected win the zombie day (def. 420.0)");
  cvar_specialdays_zombieday_infectedhealth = CreateConVar("sm_wt_specialdays_zombieday_infectedhealth", "3000", "Health each infected gets (def. 3000)");
  cvar_specialdays_zombieday_infectedspeed = CreateConVar("sm_wt_specialdays_zombieday_infectedspeed", "1.35", "The speed multiplier the infected get (def. 1.35)");
  cvar_specialdays_zombieday_infectedgravity = CreateConVar("sm_wt_specialdays_zombieday_infectedgravity", "0.8", "The gravity infected zombies get (def. 0.8)");
  cvar_specialdays_zombieday_min_drain = CreateConVar("sm_wt_specialdays_zombieday_min_drain", "12", "Minimum amount of HP that can be taken away during a drain (def. 12)");
  cvar_specialdays_zombieday_max_drain = CreateConVar("sm_wt_specialdays_zombieday_max_drain", "60", "Maximum amount of HP that can be taken away during a drain (def. 60)");
  cvar_specialdays_zombieday_drain_interval = CreateConVar("sm_wt_specialdays_zombieday_drain_interval", "1.0", "Interval of time between every drain (def. 1.0)");
  
  //Hooks
  HookEvent("round_prestart", Specialdays_ZombieDay_Reset, EventHookMode_Post);
  HookEvent("player_death", Specialdays_ZombieDay_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", Specialdays_ZombieDay_EventPlayerSpawn, EventHookMode_Post);
}

public void Specialdays_ZombieDay_Start() 
{
  isEnabled = true;
  
  //Remove radar
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      CreateTimer(0.0, RemoveRadar, i);
    }
  }
  
  //Create timer to kill infected if they lose
  zombiedayNonInfectedWinHandle = CreateTimer(GetConVarFloat(cvar_specialdays_zombieday_noninfectedwintime) - GetTimeSinceRoundStart(), Specialdays_ZombieDay_InfectedWin);
  
  //Turn on friendly fire to prevent early round ends
  SetConVarBool(FindConVar("mp_friendlyfire"), true);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), true);
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day", RoundToNearest(GetConVarFloat(cvar_specialdays_zombieday_tptime)), RoundToNearest(GetConVarFloat(cvar_specialdays_zombieday_hidetime)));
  
  //Show warning
  Specialdays_ShowGameStartWarning(GetConVarFloat(cvar_specialdays_zombieday_tptime) + GetConVarFloat(cvar_specialdays_zombieday_hidetime), 5);
  
  //Create timer for infection start
  infectionStartTimer = CreateTimer(GetConVarFloat(cvar_specialdays_zombieday_tptime) + GetConVarFloat(cvar_specialdays_zombieday_hidetime), Specialdays_ZombieDay_StartInfection);
  
  //Is in hide time
  isInInfectedHideTime = true;
  
  for (int i = 1; i <= MaxClients; ++i) {
    //Shouldn't be blind or highlighted at this stage
    isInfected[i] = false;
    
    //Shouldn't have a preserved clan tag
    clantagStorage[i] = "";
  }
  
  //Disable unlockables on Zombie days
  toggleUnlockables(CS_TEAM_T, 0);
  toggleUnlockables(CS_TEAM_CT, 0);
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    Specialdays_TeleportPlayers(warden, GetConVarFloat(cvar_specialdays_zombieday_tptime), "Zombie Day", Specialdays_Teleport_Start_All, TELEPORTTYPE_ALL);
}

public void Specialdays_ZombieDay_End() 
{
  isEnabled = false;
}

public bool Specialdays_ZombieDay_RestrictionCheck() 
{
  //Check that we have 3 people total alive
  int numAlive = 0;

  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        ++numAlive;
      }
    }
  }

  //Check for enough people
  if (numAlive < 3) {
    int warden = GetWarden();
    if (warden != -1)
      CPrintToChat(warden, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - More People Needed", 3);
    
    return false;
  }
  
  return true;
}

//Round pre start
public void Specialdays_ZombieDay_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  if (zombiedayNonInfectedWinHandle != null)
    delete zombiedayNonInfectedWinHandle;
    
  if (drainTimer != null)
    delete drainTimer;  
    
  if (infectionStartTimer != null)
    delete infectionStartTimer;
    
  isInInfectedHideTime = false;
  isPastCureFoundTime = false;
    
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
  
    //Reset infected related things
    if (isInfected[i]) {
      //Icon
      Specialdays_ZombieDay_SafeDelete(infectedIcon[i]);
      infectedIcon[i] = -1;
      
      //Reset speed
      SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
      
      //Reset overlays
      ShowOverlayToClient(i, "");
      
      isInfected[i] = false;
    }
    
    //Reset clan tags to what was stored
    if (restoreClanTags) {
      CS_SetClientClanTag(i, clantagStorage[i]);
      clantagStorage[i] = ""; //reset storage
    }
  }
  
  //After all clan tags have been restored, disable bool
  restoreClanTags = false;
    
  SetConVarBool(FindConVar("mp_friendlyfire"), false);
  SetConVarBool(FindConVar("mp_teammates_are_enemies"), false);
  
  //Enable Store jetpack and bunnyhop unlockables
  toggleUnlockables(CS_TEAM_T, 1);
  toggleUnlockables(CS_TEAM_CT, 1);
}

public void Specialdays_ZombieDay_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_OnTakeDamage, Specialdays_ZombieDay_OnTakeDamage);
  SDKHook(client, SDKHook_WeaponCanUse, Specialdays_ZombieDay_BlockPickup);
}

//Called when a player takes damage
public Action Specialdays_ZombieDay_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim >= 0 && victim <= MaxClients) || !(attacker >= 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }

  if (isEnabled) {
    if (isInfected[attacker] && !isInfected[victim]) {
      Specialdays_ZombieDay_InfectClient(victim, true);
    }
    //Non infected can harm the infected
    else if (!isInfected[attacker] && isInfected[victim]) {
      return Plugin_Continue;
    }
    
    return Plugin_Handled;
  }
  
  return Plugin_Continue;
}

public Action Specialdays_ZombieDay_BlockPickup(int client, int weapon)
{
  if (!isEnabled)
    return Plugin_Continue;
    
  char weaponClass[64];
  GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
  
  if (isInfected[client]) {
    if (!StrEqual(weaponClass, "weapon_knife"))
      return Plugin_Handled;
  }
  
  return Plugin_Continue;
}

//Player death hook
public Action Specialdays_ZombieDay_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
  
  int client = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  
  if (!isInInfectedHideTime) {
    Specialdays_ZombieDay_CheckInfectedOver();
    
    if (isInfected[client]) {
      Specialdays_ZombieDay_SafeDelete(infectedIcon[client]);
      infectedIcon[client] = -1;
      
      //Remove fade
      Handle fadePack;
      CreateDataTimer(0.0, Blind_UnfadeClient, fadePack);
      WritePackCell(fadePack, client);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
      WritePackCell(fadePack, 0);
    }
  }
  
  if (isInfected[client] && !isInfected[attacker]) {
    if (attacker != 0)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day Infected Killed", attacker, client);
    
    //Play sound
    char infectDeathSounds[2][] = {INFECT_DEATH_SOUND_1, INFECT_DEATH_SOUND_2};
    int randNum = GetRandomInt(0, sizeof(infectDeathSounds) - 1);

    //Play explosion sounds
    EmitSoundToAllAny(infectDeathSounds[randNum], client, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
    
    //Make burn appear in kill feed
    if (isPastCureFoundTime) {
      event.SetString("weapon", "inferno");
    }
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action Specialdays_ZombieDay_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!isEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
  
  CreateTimer(0.0, RemoveRadar, client); //radar removal
        
  if (isInfected[client])
    Specialdays_ZombieDay_InfectClient(client, false);
  
  return Plugin_Continue;
}

//Timer called once Zombie day starts
public Action Specialdays_ZombieDay_StartInfection(Handle timer)
{
  //Pick two people to infect
  int entryCount = 0;
  ArrayList eligblePlayers = CreateArray(MaxClients+1);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        PushArrayCell(eligblePlayers, i);
        ++entryCount;
        setAndPreserveClanTag(i, "[NOT INFECTED]", clantagStorage);
        restoreClanTags = true;
      }
    }
  }
  
  int totalToGive = 2;
  
  //Check to see if at least 'totalToGive' players are alive at this point and if not, abort
  if (entryCount < totalToGive) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day Aborted");
    infectionStartTimer = null; //Needed so invalid handle doesnt occur later
    return Plugin_Handled;
  }
  
  int client1 = -1;
  int client2 = -1;
  
  for (int c = 0; c < totalToGive; ++c) {
    int rand = GetRandomInt(0, entryCount - 1);
    int client = GetArrayCell(eligblePlayers, rand);
    removeClientFromArray(eligblePlayers, client);
    entryCount = GetArraySize(eligblePlayers);
    
    if (client1 == -1)
      client1 = client;
    else if (client2 == -1)
      client2 = client;
    
    //Infect said client
    Specialdays_ZombieDay_InfectClient(client, false);
  }
  
  isInInfectedHideTime = false;
  
  //Enable hud for all
  CreateTimer(0.5, Specialdays_ZombieDay_ShowHud);
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day First Infected", client1, client2);
  
  infectionStartTimer = null;
  
  return Plugin_Handled;
}

//Called when non infected win zombie day
public Action Specialdays_ZombieDay_InfectedWin(Handle timer)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (isInfected[i]) {
        //Burn the infected
        ServerCommand("sm_burn #%d 10000", GetClientUserId(i));
      }
    }
  }
  
  isPastCureFoundTime = true;
  
  //Disable medic
  Disable_Medics();
  
  //Start draining all infected
  drainTimer = CreateTimer(GetConVarFloat(cvar_specialdays_zombieday_drain_interval), Specialdays_ZombieDay_DrainHP, _, TIMER_REPEAT);
  
  //Print victory message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day Non Infected Win");
  
  //Reset timer handle
  zombiedayNonInfectedWinHandle = null;
}

public Action Specialdays_ZombieDay_ShowHud(Handle timer)
{
  if (!isEnabled)
    return Plugin_Handled;
  
  int numDead = 0;
  int numInfected = 0;
  int numNotInfected = 0;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      if (!IsPlayerAlive(i))
        ++numDead;
      else {
        if (isInfected[i])
          ++numInfected;
        else
          ++numNotInfected;
      }
    }
  }
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      char status[32];
      char statusColour[10];
      
      if (!IsPlayerAlive(i)) {
        Format(status, sizeof(status), "%s", "Dead");
        Format(statusColour, sizeof(statusColour), "%s", "#CCCCCC");
      }
      else {
        if (isInfected[i]) {
          Format(status, sizeof(status), "%s", "Infected");
          Format(statusColour, sizeof(statusColour), "%s", "#FF0033");
        }
        else {
          Format(status, sizeof(status), "%s", "Not Infected");
          Format(statusColour, sizeof(statusColour), "%s", "#336600");
        }
      }
      
      //Hint HUD
      PrintHintText(i, "%t", "SpecialDay - Zombie Day HUD", statusColour, status, numInfected, numNotInfected);
    }
  }
  
  CreateTimer(0.5, Specialdays_ZombieDay_ShowHud);

  return Plugin_Handled;
}

public Action Specialdays_ZombieDay_DrainHP(Handle timer)
{
  //For each client
  for (int i = 1; i <= MaxClients; ++i)
  {
    //Check if player is truly alive
    if (IsClientInGame(i) && IsPlayerAlive(i) && isInfected[i]) {
      int currentHP = GetEntProp(i, Prop_Send, "m_iHealth");
      int drainAmount = GetRandomInt(GetConVarInt(cvar_specialdays_zombieday_min_drain), GetConVarInt(cvar_specialdays_zombieday_max_drain));
      
      //If player should die
      if (drainAmount >= currentHP) {
        //Play death sound
        char infectDeathSounds[2][] = {INFECT_DEATH_SOUND_1, INFECT_DEATH_SOUND_2};
        int randNum = GetRandomInt(0, sizeof(infectDeathSounds) - 1);

        //Play explosion sounds
        EmitSoundToAllAny(infectDeathSounds[randNum], i, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
        
        //Kill the player
        SetEntProp(i, Prop_Send, "m_ArmorValue", 0, 1);  //Set Armor to 0
        DealDamage(i, currentHP + 1, i, DMG_GENERIC, "");
      }
      //Othwerwise drain their HP
      else {
        SetEntityHealth(i, currentHP - drainAmount);
      }
    }
  }
}

void Specialdays_ZombieDay_InfectClient(int client, bool printMessage)
{
  isInfected[client] = true;
  
  //Set up tint
  Handle fadePack;
  CreateDataTimer(0.0, Blind_FadeClient, fadePack);
  WritePackCell(fadePack, client);
  WritePackCell(fadePack, colours_red[0]);
  WritePackCell(fadePack, colours_red[1]);
  WritePackCell(fadePack, colours_red[2]);
  WritePackCell(fadePack, 15);
  
  //Highlight infected red
  SetEntityRenderColor(client, colours_red[0], colours_red[1], colours_red[2], 255);
  
  //Play sound
  char infectSounds[3][] = {INFECT_SOUND_1, INFECT_SOUND_2, INFECT_SOUND_3};
  int randNum = GetRandomInt(0, sizeof(infectSounds) - 1);

  //Play explosion sounds
  EmitSoundToAllAny(infectSounds[randNum], client, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
  
  //Strip all weapons
  StripWeapons(client);
  
  //Give them knife
  GivePlayerItem(client, "weapon_knife");
  
  //Set player model
  SetEntityModel(client, "models/player/custom_player/legacy/zombie/zombie_v3.mdl");
  
  //Overlay infected on them
  Specialdays_ZombieDay_CreateModel(client);
  
  //Set blood overlay
  ShowOverlayToClient(client, "overlays/invex/infectedblood.vmt");
  
  //Set clan tag
  CS_SetClientClanTag(client, "[INFECTED]");
  
  //Set health
  SetEntProp(client, Prop_Data, "m_iHealth", GetConVarInt(cvar_specialdays_zombieday_infectedhealth));
  
  //Give speed boost
  SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", GetConVarFloat(cvar_specialdays_zombieday_infectedspeed));
  
  //Set gravity
  SetEntityGravity(client, GetConVarFloat(cvar_specialdays_zombieday_infectedgravity));
  
  //Burn if past cure time
  if (isPastCureFoundTime) {
    ServerCommand("sm_burn #%d 10000", GetClientUserId(client));
  }
  
  if (printMessage)
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day New Infected", client);

  Specialdays_ZombieDay_CheckInfectedOver();
    
  return;
}

void Specialdays_ZombieDay_CheckInfectedOver()
{
  //Pick two people to infect
  int nonInfected = 0;
  int infected = 0;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (isInfected[i])
        ++infected;
      else
        ++nonInfected;
    }
  }
  
  if (infected == 0) {
    //Round over, everybody is infected
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day Non Infected Win Died Off");
    
    //Fire CT Win
    CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_CTWin, false);
  }
  if (nonInfected == 0) {
    //Round over, everybody is infected
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day All Infected");
    
    //Fire Prisoners Win
    CS_TerminateRound(GetConVarFloat(FindConVar("mp_round_restart_delay")), CSRoundEnd_TerroristWin, false);
  }
}

//Icon/Sprite code
void Specialdays_ZombieDay_CreateModel(int client)
{
  Specialdays_ZombieDay_SafeDelete(infectedIcon[client]);
  infectedIcon[client] = Specialdays_ZombieDay_CreateIcon();
  Specialdays_ZombieDay_PlaceAndBindIcon(client, infectedIcon[client]);
}

int Specialdays_ZombieDay_CreateIcon()
{
  int sprite = CreateEntityByName("env_sprite_oriented");
  
  if (sprite == -1)
    return -1;

  DispatchKeyValue(sprite, "classname", "env_sprite_oriented");
  DispatchKeyValue(sprite, "spawnflags", "1");
  DispatchKeyValue(sprite, "scale", "0.3");
  DispatchKeyValue(sprite, "rendermode", "1");
  DispatchKeyValue(sprite, "rendercolor", "255 255 255");
  DispatchKeyValue(sprite, "model", "materials/sprites/invex/infected.vmt");
  
  if (DispatchSpawn(sprite))
    return sprite;

  return -1;
}

void Specialdays_ZombieDay_PlaceAndBindIcon(int client, int entity)
{
  float origin[3];

  if (IsValidEntity(entity)) {
    GetClientAbsOrigin(client, origin);
    origin[2] += 90.0;
    TeleportEntity(entity, origin, NULL_VECTOR, NULL_VECTOR);

    SetVariantString("!activator");
    AcceptEntityInput(entity, "SetParent", client);
  }
}

void Specialdays_ZombieDay_SafeDelete(int entity)
{
  if (IsValidEntity(entity))
    AcceptEntityInput(entity, "Kill");
}