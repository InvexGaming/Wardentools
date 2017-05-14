#include "wardentools/blind.sp"

//Defines
#define INFECT_SOUND_1 "invex_gaming/jb_wardentools/infected_1.mp3"
#define INFECT_SOUND_2 "invex_gaming/jb_wardentools/infected_2.mp3"
#define INFECT_SOUND_3 "invex_gaming/jb_wardentools/infected_3.mp3"
#define INFECT_DEATH_SOUND_1 "invex_gaming/jb_wardentools/infected_death1.mp3"
#define INFECT_DEATH_SOUND_2 "invex_gaming/jb_wardentools/infected_death2.mp3"

//Static globals
static bool s_IsEnabled = false;
static Handle s_ZombieDayNonInfectedWinHandle = null;
static bool s_IsInfected[MAXPLAYERS+1] = {false, ...};
static bool s_IsInInfectedHideTime = false;
static int s_InfectedIcon[MAXPLAYERS+1] = {-1, ...};
static bool s_IsPastCureFoundTime = false;
static Handle s_DrainTimer = null;
static Handle s_InfectionStartTimer = null;

static bool s_RestoreClanTags = false;
static char s_ClanTagStorage[MAXPLAYERS+1][32];

//Convars
ConVar g_Cvar_SpecialDays_ZombieDay_TeleportTime = null;
ConVar g_Cvar_SpecialDays_ZombieDay_HideTime = null;
ConVar g_Cvar_SpecialDays_ZombieDay_NonInfectedWinTime = null;
ConVar g_Cvar_SpecialDays_ZombieDay_InfectedHealth = null;
ConVar g_Cvar_SpecialDays_ZombieDay_InfectedSpeed = null;
ConVar g_Cvar_SpecialDays_ZombieDay_InfectedGravity = null;
ConVar g_Cvar_SpecialDays_ZombieDay_MinDrain = null;
ConVar g_Cvar_SpecialDays_ZombieDay_MaxDrain = null;
ConVar g_Cvar_SpecialDays_ZombieDay_DrainInterval = null;

public void SpecialDays_Init_ZombieDay()
{
  SpecialDays_RegisterDay("Zombie Day", SpecialDays_ZombieDay_Start, SpecialDays_ZombieDay_End, SpecialDays_ZombieDay_RestrictionCheck, SpecialDays_ZombieDay_OnClientPutInServer, false, false);
  
  //Convars
  g_Cvar_SpecialDays_ZombieDay_TeleportTime = CreateConVar("sm_wt_specialdays_zombieday_tptime", "10.0", "The amount of time before prisoners are teleported to start beacon (def. 10.0)");
  g_Cvar_SpecialDays_ZombieDay_HideTime = CreateConVar("sm_wt_specialdays_zombieday_hidetime", "60", "Number of seconds everyone has to hide (def. 60)");
  g_Cvar_SpecialDays_ZombieDay_NonInfectedWinTime = CreateConVar("sm_wt_specialdays_zombieday_noninfectedwintime", "420.0", "The amount of time before non infected win the zombie day (def. 420.0)");
  g_Cvar_SpecialDays_ZombieDay_InfectedHealth = CreateConVar("sm_wt_specialdays_zombieday_infectedhealth", "3000", "Health each infected gets (def. 3000)");
  g_Cvar_SpecialDays_ZombieDay_InfectedSpeed = CreateConVar("sm_wt_specialdays_zombieday_infectedspeed", "1.35", "The speed multiplier the infected get (def. 1.35)");
  g_Cvar_SpecialDays_ZombieDay_InfectedGravity = CreateConVar("sm_wt_specialdays_zombieday_infectedgravity", "0.8", "The gravity infected zombies get (def. 0.8)");
  g_Cvar_SpecialDays_ZombieDay_MinDrain = CreateConVar("sm_wt_specialdays_zombieday_min_drain", "12", "Minimum amount of HP that can be taken away during a drain (def. 12)");
  g_Cvar_SpecialDays_ZombieDay_MaxDrain = CreateConVar("sm_wt_specialdays_zombieday_max_drain", "60", "Maximum amount of HP that can be taken away during a drain (def. 60)");
  g_Cvar_SpecialDays_ZombieDay_DrainInterval = CreateConVar("sm_wt_specialdays_zombieday_drain_interval", "1.0", "Interval of time between every drain (def. 1.0)");
  
  //Hooks
  HookEvent("round_prestart", SpecialDays_ZombieDay_Reset, EventHookMode_Post);
  HookEvent("player_death", SpecialDays_ZombieDay_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("player_spawn", SpecialDays_ZombieDay_EventPlayerSpawn, EventHookMode_Post);
}

public void SpecialDays_ZombieDay_Start() 
{
  s_IsEnabled = true;
  
  //Remove radar
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      CreateTimer(0.0, RemoveRadar, i);
    }
  }
  
  //Create timer to kill infected if they lose
  s_ZombieDayNonInfectedWinHandle = CreateTimer(GetConVarFloat(g_Cvar_SpecialDays_ZombieDay_NonInfectedWinTime) - GetTimeSinceRoundStart(), SpecialDays_ZombieDay_InfectedWin);
  
  //Turn on friendly fire to prevent early round ends
  FindConVar("mp_friendlyfire").BoolValue = true;
  FindConVar("mp_teammates_are_enemies").BoolValue = true;
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day", RoundToNearest(g_Cvar_SpecialDays_ZombieDay_TeleportTime.FloatValue), RoundToNearest(g_Cvar_SpecialDays_ZombieDay_HideTime.FloatValue));
  
  //Show warning
  SpecialDays_ShowGameStartWarning(g_Cvar_SpecialDays_ZombieDay_TeleportTime.FloatValue + g_Cvar_SpecialDays_ZombieDay_HideTime.FloatValue, 5);
  
  //Create timer for infection start
  s_InfectionStartTimer = CreateTimer(g_Cvar_SpecialDays_ZombieDay_TeleportTime.FloatValue + g_Cvar_SpecialDays_ZombieDay_HideTime.FloatValue, SpecialDays_ZombieDay_StartInfection);
  
  //Is in hide time
  s_IsInInfectedHideTime = true;
  
  for (int i = 1; i <= MaxClients; ++i) {
    //Shouldn't be blind or highlighted at this stage
    s_IsInfected[i] = false;
    
    //Shouldn't have a preserved clan tag
    s_ClanTagStorage[i] = "";
  }
  
  //Disable unlockables on Zombie days
  ToggleUnlockables(CS_TEAM_T, 0);
  ToggleUnlockables(CS_TEAM_CT, 0);
  
  //Teleport all players to warden
  int warden = GetWarden();
  if (warden != -1)
    SpecialDays_TeleportPlayers(warden, g_Cvar_SpecialDays_ZombieDay_TeleportTime.FloatValue, "Zombie Day", SpecialDays_Teleport_Start_All, TeleportType_All);
}

public void SpecialDays_ZombieDay_End() 
{
  s_IsEnabled = false;
}

public bool SpecialDays_ZombieDay_RestrictionCheck() 
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
public void SpecialDays_ZombieDay_Reset(Event event, const char[] name, bool dontBroadcast)
{
  delete s_ZombieDayNonInfectedWinHandle;
  delete s_DrainTimer;  
  delete s_InfectionStartTimer;
    
  s_IsInInfectedHideTime = false;
  s_IsPastCureFoundTime = false;
    
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
  
    //Reset infected related things
    if (s_IsInfected[i]) {
      //Icon
      SpecialDays_ZombieDay_SafeDelete(s_InfectedIcon[i]);
      s_InfectedIcon[i] = -1;
      
      //Reset speed
      SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
      
      //Reset overlays
      ShowOverlayToClient(i, "");
      
      s_IsInfected[i] = false;
    }
    
    //Reset clan tags to what was stored
    if (s_RestoreClanTags) {
      CS_SetClientClanTag(i, s_ClanTagStorage[i]);
      s_ClanTagStorage[i] = ""; //reset storage
    }
  }
  
  //After all clan tags have been restored, disable bool
  s_RestoreClanTags = false;
  
  FindConVar("mp_friendlyfire").BoolValue = false;
  FindConVar("mp_teammates_are_enemies").BoolValue = false;
  
  //Enable Store jetpack and bunnyhop unlockables
  ToggleUnlockables(CS_TEAM_T, 1);
  ToggleUnlockables(CS_TEAM_CT, 1);
}

public void SpecialDays_ZombieDay_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_OnTakeDamage, SpecialDays_ZombieDay_OnTakeDamage);
  SDKHook(client, SDKHook_WeaponCanUse, SpecialDays_ZombieDay_BlockPickup);
}

//Called when a player takes damage
public Action SpecialDays_ZombieDay_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim >= 0 && victim <= MaxClients) || !(attacker >= 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }
  
  if (s_IsEnabled) {
    if (s_IsInfected[attacker] && !s_IsInfected[victim]) {
      SpecialDays_ZombieDay_InfectClient(victim, true);
    }
    //Non infected can harm the infected
    else if (!s_IsInfected[attacker] && s_IsInfected[victim]) {
      return Plugin_Continue;
    }
    
    return Plugin_Handled;
  }
  
  return Plugin_Continue;
}

public Action SpecialDays_ZombieDay_BlockPickup(int client, int weapon)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  char weaponClass[64];
  GetEntityClassname(weapon, weaponClass, sizeof(weaponClass));
  
  if (s_IsInfected[client]) {
    if (!StrEqual(weaponClass, "weapon_knife"))
      return Plugin_Handled;
  }
  
  return Plugin_Continue;
}

//Player death hook
public Action SpecialDays_ZombieDay_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
  
  int client = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  
  if (!s_IsInInfectedHideTime) {
    SpecialDays_ZombieDay_CheckInfectedOver();
    
    if (s_IsInfected[client]) {
      SpecialDays_ZombieDay_SafeDelete(s_InfectedIcon[client]);
      s_InfectedIcon[client] = -1;
      
      //Remove fade
      Blind_Unblind(client);
    }
  }
  
  if (s_IsInfected[client] && !s_IsInfected[attacker]) {
    if (attacker != 0)
      CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day Infected Killed", attacker, client);
    
    //Play sound
    char infectDeathSounds[2][] = {INFECT_DEATH_SOUND_1, INFECT_DEATH_SOUND_2};
    int randNum = GetRandomInt(0, sizeof(infectDeathSounds) - 1);

    //Play explosion sounds
    EmitSoundToAllAny(infectDeathSounds[randNum], client, SNDCHAN_USER_BASE, SNDLEVEL_RAIDSIREN); 
    
    //Make burn appear in kill feed
    if (s_IsPastCureFoundTime) {
      event.SetString("weapon", "inferno");
    }
  }
  
  return Plugin_Continue;
}

//Player spawn hook
public Action SpecialDays_ZombieDay_EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!s_IsEnabled)
    return Plugin_Continue;
    
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (!IsClientInGame(client) || !IsPlayerAlive(client))
    return Plugin_Continue;
  
  CreateTimer(0.0, RemoveRadar, client); //radar removal
        
  if (s_IsInfected[client])
    SpecialDays_ZombieDay_InfectClient(client, false);
  
  return Plugin_Continue;
}

//Timer called once Zombie day starts
public Action SpecialDays_ZombieDay_StartInfection(Handle timer)
{
  s_InfectionStartTimer = null; //Resolve dangling handle
  
  //Pick two people to infect
  ArrayList eligblePlayers = new ArrayList();
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        eligblePlayers.Push(i);
        setAndPreserveClanTag(i, "[NOT INFECTED]", s_ClanTagStorage);
        s_RestoreClanTags = true;
      }
    }
  }
  
  int totalToGive = 2;
  
  //Check to see if at least 'totalToGive' players are alive at this point and if not, abort
  if (eligblePlayers.Length < totalToGive) {
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day Aborted");
    delete eligblePlayers;
    return Plugin_Handled;
  }
  
  int client1 = -1;
  int client2 = -1;
  
  for (int c = 0; c < totalToGive; ++c) {
    int rand = GetRandomInt(0, eligblePlayers.Length - 1);
    int client = eligblePlayers.Get(rand);
    RemoveAllValuesFromArray(eligblePlayers, client);
    
    if (client1 == -1)
      client1 = client;
    else if (client2 == -1)
      client2 = client;
    
    //Infect said client
    SpecialDays_ZombieDay_InfectClient(client, false);
  }
  
  delete eligblePlayers;
  
  s_IsInInfectedHideTime = false;
  
  //Enable hud for all
  CreateTimer(0.5, SpecialDays_ZombieDay_ShowHud);
  
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day First Infected", client1, client2);
  
  return Plugin_Handled;
}

//Called when non infected win zombie day
public Action SpecialDays_ZombieDay_InfectedWin(Handle timer)
{
  s_ZombieDayNonInfectedWinHandle = null; //Resolve dangling handle
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (s_IsInfected[i]) {
        //Burn the infected
        ServerCommand("sm_burn #%d 10000", GetClientUserId(i));
      }
    }
  }
  
  s_IsPastCureFoundTime = true;
  
  //Disable medic
  Disable_Medics();
  
  //Start draining all infected
  s_DrainTimer = CreateTimer(g_Cvar_SpecialDays_ZombieDay_DrainInterval.FloatValue, SpecialDays_ZombieDay_DrainHP, _, TIMER_REPEAT);
  
  //Print victory message
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day Non Infected Win");
}

public Action SpecialDays_ZombieDay_ShowHud(Handle timer)
{
  if (!s_IsEnabled)
    return Plugin_Handled;
  
  int numDead = 0;
  int numInfected = 0;
  int numNotInfected = 0;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i)) {
      if (!IsPlayerAlive(i))
        ++numDead;
      else {
        if (s_IsInfected[i])
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
        if (s_IsInfected[i]) {
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
  
  CreateTimer(0.5, SpecialDays_ZombieDay_ShowHud);

  return Plugin_Handled;
}

public Action SpecialDays_ZombieDay_DrainHP(Handle timer)
{
  //For each client
  for (int i = 1; i <= MaxClients; ++i)
  {
    //Check if player is truly alive
    if (IsClientInGame(i) && IsPlayerAlive(i) && s_IsInfected[i]) {
      int currentHP = GetEntProp(i, Prop_Send, "m_iHealth");
      int drainAmount = GetRandomInt(g_Cvar_SpecialDays_ZombieDay_MinDrain.IntValue, g_Cvar_SpecialDays_ZombieDay_MaxDrain.IntValue);
      
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

void SpecialDays_ZombieDay_InfectClient(int client, bool printMessage)
{
  s_IsInfected[client] = true;
  
  //Set up red tint
  Blind_Blind(client, _, g_Colours_Red[0], g_Colours_Red[1], g_Colours_Red[2], 15);
  
  //Highlight infected red
  SetEntityRenderColor(client, g_Colours_Red[0], g_Colours_Red[1], g_Colours_Red[2], 255);
  
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
  SpecialDays_ZombieDay_CreateModel(client);
  
  //Set blood overlay
  ShowOverlayToClient(client, "overlays/invex/infectedblood.vmt");
  
  //Set clan tag
  CS_SetClientClanTag(client, "[INFECTED]");
  
  //Set health
  SetEntProp(client, Prop_Data, "m_iHealth", g_Cvar_SpecialDays_ZombieDay_InfectedHealth.IntValue);
  
  //Give speed boost
  SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_Cvar_SpecialDays_ZombieDay_InfectedSpeed.FloatValue);
  
  //Set gravity
  SetEntityGravity(client, g_Cvar_SpecialDays_ZombieDay_InfectedGravity.FloatValue);
  
  //Burn if past cure time
  if (s_IsPastCureFoundTime) {
    ServerCommand("sm_burn #%d 10000", GetClientUserId(client));
  }
  
  if (printMessage)
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day New Infected", client);
  
  SpecialDays_ZombieDay_CheckInfectedOver();
    
  return;
}

void SpecialDays_ZombieDay_CheckInfectedOver()
{
  int nonInfected = 0;
  int infected = 0;
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (s_IsInfected[i])
        ++infected;
      else
        ++nonInfected;
    }
  }
  
  if (infected == 0) {
    //Round over, non infected win
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day Non Infected Win Died Off");
    
    //Fire CT Win
    CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue, CSRoundEnd_CTWin, false);
  }
  else if (nonInfected == 0) {
    //Round over, everybody is infected
    CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Zombie Day All Infected");
    
    //Fire Prisoners Win
    CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue, CSRoundEnd_TerroristWin, false);
  }
}

//Icon/Sprite code
void SpecialDays_ZombieDay_CreateModel(int client)
{
  SpecialDays_ZombieDay_SafeDelete(s_InfectedIcon[client]);
  s_InfectedIcon[client] = SpecialDays_ZombieDay_CreateIcon();
  SpecialDays_ZombieDay_PlaceAndBindIcon(client, s_InfectedIcon[client]);
}

int SpecialDays_ZombieDay_CreateIcon()
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

void SpecialDays_ZombieDay_PlaceAndBindIcon(int client, int entity)
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

void SpecialDays_ZombieDay_SafeDelete(int entity)
{
  if (IsValidEntity(entity))
    AcceptEntityInput(entity, "Kill");
}