/*
* Special days manager
* Prefix: SpecialDays_
*/

#if defined _wardentools_specialdays_included
  #endinput
#endif
#define _wardentools_specialdays_included

#include <wardentools>
#include <cstrike>

#define SPECIALDAYS_MAX_DAYS 64

enum TeleportType {
  TeleportType_All,
  TeleportType_T
}

#include "wardentools/beams.sp"
#include "wardentools/colours.sp"
#include "wardentools/specialdays/freeday.sp"
#include "wardentools/specialdays/customday.sp"
#include "wardentools/specialdays/hnsday.sp"
#include "wardentools/specialdays/warday.sp"
#include "wardentools/specialdays/zombieday.sp"
#include "wardentools/specialdays/ffadm.sp"
#include "wardentools/specialdays/teamdm.sp"
#include "wardentools/specialdays/hungergames.sp"
#include "wardentools/specialdays/oneinthechamber.sp"
#include "wardentools/specialdays/espffadm.sp"

enum SpecialDay
{
	String:dayName[64],
	Function:dayStart,
	Function:dayEnd,
  Function:restrictionCheck,
  Function:onClientPutInServer,
  bool:allowDrawTools,
  bool:allowGameTools
}

//Convars
ConVar g_Cvar_SpecialDays_MaxDays = null;
ConVar g_Cvar_SpecialDays_StartTime = null;

//Global
int g_SpecialDayList[SPECIALDAYS_MAX_DAYS][SpecialDay];

//Global statics
static int s_SpecialDayCount = 0;
static int s_NumSpecialDays = 0; //number of special days performed on map
static int s_CurrentSpecialDay = -1; //index into special day list
static int s_SpecialDayStartTime = 0;
static bool s_SpecialDayDamageProtection = false;
static Handle s_DamageProtectionHandle = null;
static Handle s_TeleportHandle = null;
static int s_RoundCount = 1;
static bool s_IsSpecialDayRound[999] = {false, ...}; //hold data for 999 consecutive days
static bool s_ShowDayStartHud = false;
static Handle s_GameStartWarningTimer = null;
static int s_WarningSecondsLeft = -1;

public void SpecialDays_OnPluginStart()
{
  s_SpecialDayCount = 0;
  
  g_Cvar_SpecialDays_MaxDays = CreateConVar("sm_wt_specialdays_maxdays", "4", "Maximum number of special days per map (def. 4)");
  g_Cvar_SpecialDays_StartTime = CreateConVar("sm_wt_specialdays_starttime", "60.0", "The amount of time the warden has to trigger a special day (def. 60.0)");
  
  HookEvent("round_end", SpecialDay_EventRoundEnd, EventHookMode_Pre);
  //HookEvent("round_end", SpecialDay_EventRoundEndPost, EventHookMode_Post);
  HookEvent("round_prestart", SpecialDay_Reset, EventHookMode_Post);
  HookEvent("server_cvar", SpecialDay_EventServerCvar, EventHookMode_Pre);
  
  //Call init functions
  SpecialDays_Init_Freeday();
  SpecialDays_Init_CustomDay();
  SpecialDays_Init_HnsDay();
  SpecialDays_Init_WarDay();
  SpecialDays_Init_ZombieDay();
  SpecialDays_Init_FfaDm();
  SpecialDays_Init_TeamDm();
  SpecialDays_Init_HungerGames();
  SpecialDays_Init_OneInTheChamber();
  SpecialDays_Init_EspFfaDm();
}

public void SpecialDays_OnMapStart()
{
  s_NumSpecialDays = 0;
  s_RoundCount = 1;
  
  //Reset special day account
  for (int i = 0; i < sizeof(s_IsSpecialDayRound); ++i) {
    s_IsSpecialDayRound[i] = false;
  }
}

//Round End
public Action SpecialDay_EventRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
  //Call end func
  if (s_CurrentSpecialDay != -1) {
    Call_StartFunction(null, g_SpecialDayList[s_CurrentSpecialDay][dayEnd]);
    Call_Finish();
    s_CurrentSpecialDay = -1;
  }
  
  ++s_RoundCount; //increment round number
  
  //CSGO events start from 1 instead of 0, so we need to subtract 1 before comparison with cstrike enum
  if (view_as<CSRoundEndReason>(event.GetInt("reason") - 1) == CSRoundEnd_GameStart) {
    s_RoundCount = 1;
    
    //Reset special day account
    for (int i = 0; i < sizeof(s_IsSpecialDayRound); ++i) {
      s_IsSpecialDayRound[i] = false;
    }
  }
}

//Round pre start
public Action SpecialDay_Reset(Event event, const char[] name, bool dontBroadcast)
{ 
  //Enable LR if disabled
  ConVar hostiesLR = FindConVar("sm_hosties_lr");
  if (hostiesLR != null)
    hostiesLR.IntValue = 1; 
    
  //Enable colouring of rebellers
  ConVar rebelColour = FindConVar("sm_hosties_rebel_color");
  if (rebelColour != null)
    rebelColour.IntValue = 1;
    
  //Enable warden claiming
  ConVar wardenClaim = FindConVar("sm_warden_enabled");
  if (wardenClaim != null)
    wardenClaim.IntValue = 1;
    
  delete s_DamageProtectionHandle;
  delete s_TeleportHandle;
  delete s_GameStartWarningTimer;
    
  s_SpecialDayStartTime = 0;
  s_SpecialDayDamageProtection = false;
  s_ShowDayStartHud = false;
  s_WarningSecondsLeft = -1;
  
  //Set first round freeday
  if (s_RoundCount == 1)
    SpecialDays_StartSpecialDay("Freeday", false); //this round does not reduce number of remaining special days
}

//Disable annoying convar changes from being printed into chat
public Action SpecialDay_EventServerCvar(Event event, const char[] name, bool dontBroadcast)
{
  char cvarName[128];
  event.GetString("cvarname", cvarName, sizeof(cvarName));
  
  if (StrEqual(cvarName, "mp_friendlyfire") || StrEqual(cvarName, "mp_teammates_are_enemies")) {
    return Plugin_Handled;
  }

  return Plugin_Continue;  
}

public void SpecialDays_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_OnTakeDamage, SpecialDays_OnTakeDamage);
  
  //Special days
  for (int i = 0; i < s_SpecialDayCount; ++i) {
    Call_StartFunction(null, g_SpecialDayList[i][onClientPutInServer]);
    Call_PushCell(client);
    Call_Finish();
  }
}

//Called when a player takes damage, can be used by special days to block damage during hide time
public Action SpecialDays_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim >= 0 && victim <= MaxClients) || !(attacker >= 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }

  //On special days, stop drowning during freeze and fall damage from world
  if (SpecialDays_IsSpecialDay() && s_SpecialDayDamageProtection && attacker == 0) {
    if (damagetype & (DMG_DROWN | DMG_DROWNRECOVER | DMG_FALL) > 0)
      return Plugin_Handled;
  }
  
  //Block damage from players
  if (SpecialDays_IsSpecialDay() && s_SpecialDayDamageProtection && attacker != 0) {
    return Plugin_Handled;
  }
  
  return Plugin_Continue;
}


public void SpecialDays_StartSpecialDay(char[] name, bool countDay)
{
  //Store start time
  s_SpecialDayStartTime = GetTime();

  bool success = false;
  
  //Search for special day by name and call its start function
  for (int i = 0; i < s_SpecialDayCount; ++i) {
    if (StrEqual(g_SpecialDayList[i][dayName], name)) {
      //Perform restriction checking
      Call_StartFunction(null, g_SpecialDayList[i][restrictionCheck]);
      Call_Finish(success);
      if (!success)
        break;
    
      s_CurrentSpecialDay = i;
      Call_StartFunction(null, g_SpecialDayList[i][dayStart]);
      Call_Finish();
      break;
    }
  }
  
  //No special day found
  if (s_CurrentSpecialDay == -1)
    return;
  
  //Required condition was not met
  if (!success)
    return;
  
  //Show HUD for 8 seconds
  s_ShowDayStartHud = true;
  CreateTimer(0.5, SpecialDays_ShowDayStartHud);
  CreateTimer(8.0, SpecialDays_DisableDayStartHud);
  
  //Set other required settings
  //Disable LR on special days unless its a round modifier
  ConVar hostiesLR = FindConVar("sm_hosties_lr");
  if (hostiesLR != null)
    hostiesLR.IntValue = 0;
    
  //Disable colouring of rebellers
  ConVar rebelColour = FindConVar("sm_hosties_rebel_color");
  if (rebelColour != null)
    rebelColour.IntValue = 0;
    
  //Disable warden claiming
  ConVar wardenClaim = FindConVar("sm_warden_enabled");
  if (wardenClaim != null)
    wardenClaim.IntValue = 0;

  if (countDay)
    ++s_NumSpecialDays;
  
  s_IsSpecialDayRound[s_RoundCount] = true;
}

public Action SpecialDays_ShowDayStartHud(Handle timer)
{
  if (!s_ShowDayStartHud)
    return Plugin_Handled;
    
  if (!SpecialDays_IsSpecialDay())
    return Plugin_Handled;
    
  PrintCenterTextAll("%t", "SpecialDay - Day Start HUD", g_SpecialDayList[s_CurrentSpecialDay][dayName]);
  CreateTimer(0.5, SpecialDays_ShowDayStartHud);
  
  return Plugin_Handled;
}

public Action SpecialDays_DisableDayStartHud(Handle timer)
{
  if (s_ShowDayStartHud)
    s_ShowDayStartHud = false;
    
  return Plugin_Handled;
}

public void SpecialDays_RegisterDay(char[] name, Function startFunc, Function endFunc, Function restrictionCheckFunc, Function onClientPutInServerFunc, bool allowDrawToolsValue, bool allowGameToolsValue)
{
  //Store required information
  strcopy(g_SpecialDayList[s_SpecialDayCount][dayName], 64, name);
  g_SpecialDayList[s_SpecialDayCount][dayStart] = startFunc;
  g_SpecialDayList[s_SpecialDayCount][dayEnd] = endFunc;
  g_SpecialDayList[s_SpecialDayCount][restrictionCheck] = restrictionCheckFunc;
  g_SpecialDayList[s_SpecialDayCount][onClientPutInServer] = onClientPutInServerFunc;
  g_SpecialDayList[s_SpecialDayCount][allowDrawTools] = allowDrawToolsValue;
  g_SpecialDayList[s_SpecialDayCount][allowGameTools] = allowGameToolsValue;
  
  ++s_SpecialDayCount;
}

//Called when damage protection is to be turned off
public Action SpecialDays_DamageProtection_End(Handle timer)
{
  s_DamageProtectionHandle = null; //Resolve dangling handle
  
  s_SpecialDayDamageProtection = false;
}

//Teleports players to beam that spawns on a clients location
//Players are also frozen before being teleported
//Uses: s_TeleportHandle as handle (should be set to null in teleportFunc)
//teleportFunc is: SpecialDays_Teleport_Start_All, SpecialDays_Teleport_Start_T
//teleportType is: 0 for all players, 1 for T's
public void SpecialDays_TeleportPlayers(int client, float tptime, char[] specialDayName, Timer teleportFunc, TeleportType teleportType)
{
  float client_origin[3];
  float client_angles[3];
  GetClientAbsOrigin(client, client_origin);
  GetClientAbsAngles(client, client_angles);
 
  //Create timer with pack
  DataPack pack;
  s_TeleportHandle = CreateDataTimer(tptime, teleportFunc, pack);
  
  if (teleportType == TeleportType_All)
    ServerCommand("sm_freeze @all %d", RoundToFloor(tptime));
  else if (teleportType == TeleportType_T)
    ServerCommand("sm_freeze @t %d", RoundToFloor(tptime));
    
  //Day name
  pack.WriteString(specialDayName);
  
  //Origin
  pack.WriteFloat(client_origin[0]);
  pack.WriteFloat(client_origin[1]);
  pack.WriteFloat(client_origin[2]);
  
  //Angles
  pack.WriteFloat(client_angles[0]);
  pack.WriteFloat(client_angles[1]);
  pack.WriteFloat(client_angles[2]);
  
  //Draw beam (rally point)
  Beams_SpawnBeam(client, tptime, client_origin);
}

//Teleport start timer handler
public Action SpecialDays_Teleport_Start_All(Handle timer, DataPack pack)
{
  s_TeleportHandle = null;
  
  pack.Reset();
  
  char buffer[128];
  pack.ReadString(buffer, sizeof(buffer));
  
  float hOrigin[3], hAngles[3];
  hOrigin[0] = pack.ReadFloat();
  hOrigin[1] = pack.ReadFloat();
  hOrigin[2] = pack.ReadFloat();
  
  hAngles[0] = pack.ReadFloat();
  hAngles[1] = pack.ReadFloat();
  hAngles[2] = pack.ReadFloat();
  
  //Teleport all players to location
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT) {
        TeleportEntity(i, hOrigin, hAngles, NULL_VECTOR);
      }
    }
  }
  
  //Report Teleported
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Teleport Start All", buffer);
}

//Teleport start timer handler
public Action SpecialDays_Teleport_Start_T(Handle timer, DataPack pack)
{
  s_TeleportHandle = null;
  
  pack.Reset();
  
  char buffer[128];
  pack.ReadString(buffer, sizeof(buffer));
  
  float hOrigin[3], hAngles[3];
  hOrigin[0] = pack.ReadFloat();
  hOrigin[1] = pack.ReadFloat();
  hOrigin[2] = pack.ReadFloat();
  
  hAngles[0] = pack.ReadFloat();
  hAngles[1] = pack.ReadFloat();
  hAngles[2] = pack.ReadFloat();
  
  //Teleport all T's to location
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && IsPlayerAlive(i)) {
      if (GetClientTeam(i) == CS_TEAM_T) {
        TeleportEntity(i, hOrigin, hAngles, NULL_VECTOR);
      }
    }
  }
  
  //Report Teleported
  CPrintToChatAll("%s%t", CHAT_TAG_PREFIX, "SpecialDay - Teleport Start T", buffer);
}

//Getters/setters
public bool SpecialDays_IsSpecialDay()
{
  return (s_CurrentSpecialDay != -1);
}

public int SpecialDays_GetSpecialDay()
{
  return s_CurrentSpecialDay;
}

public void SpecialDays_GetSpecialDayName(char[] buffer, int bufferSize)
{
  if (SpecialDays_IsSpecialDay()) {
    Format(buffer, bufferSize, g_SpecialDayList[s_CurrentSpecialDay][dayName]);
  } else {
    Format(buffer, bufferSize, "");
  }
}

public int SpecialDays_GetSpecialDayCount()
{
  return s_SpecialDayCount;
}

public int SpecialDays_GetNumSpecialDays()
{
  return s_NumSpecialDays;
}

public int SpecialDays_GetNumSpecialDaysLeft()
{
  return g_Cvar_SpecialDays_MaxDays.IntValue - s_NumSpecialDays;
}

public int SpecialDays_GetDayStartTime()
{
  return s_SpecialDayStartTime;
}

public int SpecialDays_GetSecondsToStartDay()
{
  return g_Cvar_SpecialDays_StartTime.IntValue;
}

//Returns true if its okay to start special day
public bool SpecialDays_CanStartSpecialDay()
{
  if (SpecialDays_IsSpecialDay())
    return false;
    
  if (SpecialDays_GetNumSpecialDaysLeft() == 0)
    return false;
  
  if (GetTimeSinceRoundStart() >= SpecialDays_GetSecondsToStartDay())
    return false;
  
  //Cannot start special day on first round or if last round was special day
  if (s_RoundCount == 1 || s_IsSpecialDayRound[s_RoundCount - 1])
    return false;
  
  return true;
}

//Duration: 0.0 equals permanent
public void SpecialDays_SetDamageProtection(bool value, float duration)
{
  s_SpecialDayDamageProtection = value;
  
  if (s_SpecialDayDamageProtection) {
    if (duration > 0.0) {
      s_DamageProtectionHandle = CreateTimer(duration, SpecialDays_DamageProtection_End);
    }
  }
}

public void SpecialDays_ShowGameStartWarning(float countdown, int duration)
{
  s_GameStartWarningTimer = CreateTimer(countdown - duration, SpecialDays_ShowGameStartWarningTimer);
  s_WarningSecondsLeft = duration;
}

//Timer called to warn of game starting
public Action SpecialDays_ShowGameStartWarningTimer(Handle timer)
{
  s_GameStartWarningTimer = null; //Resolve dangling handle
  
  //Create warning HUD
  CreateTimer(0.0, SpecialDays_ShowGameStartWarningHud);
  
  return Plugin_Handled;
}

public Action SpecialDays_ShowGameStartWarningHud(Handle timer)
{
  if (!SpecialDays_IsSpecialDay())
    return Plugin_Handled;
    
  if (s_WarningSecondsLeft <= 0) {
    PrintCenterTextAll("%t", "SpecialDay - Game Start Started", g_SpecialDayList[s_CurrentSpecialDay][dayName]);
    return Plugin_Handled;
  }
  
  PrintCenterTextAll("%t", "SpecialDay - Game Start Warning HUD", g_SpecialDayList[s_CurrentSpecialDay][dayName], s_WarningSecondsLeft);
  --s_WarningSecondsLeft;
  
  CreateTimer(1.0, SpecialDays_ShowGameStartWarningHud);
  
  return Plugin_Handled;
}
