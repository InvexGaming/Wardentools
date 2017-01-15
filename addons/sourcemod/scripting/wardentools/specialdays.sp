/*
* Special days manager
* Prefix: specialdays_
*/

#if defined _wardentools_specialdays_included
  #endinput
#endif
#define _wardentools_specialdays_included

#include <wardentools>
#include <cstrike>

#define SPECIALDAYS_MAX_DAYS 64
#define MAX_ROUNDS 30
#define TELEPORTTYPE_ALL 0
#define TELEPORTTYPE_T 1

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
ConVar cvar_specialdays_maxdays = null;
ConVar cvar_specialdays_starttime = null;

//Global
int specialDayList[SPECIALDAYS_MAX_DAYS][SpecialDay];

//Global statics
static int specialDayCount = 0;
static int numSpecialDays = 0; //number of special days performed on map
static int currentSpecialDay = -1; //index into special day list
static int specialDayStartTime = 0;
static bool specialDayDamageProtection = false;
static Handle damageProtectionHandle = null;
static Handle teleportHandle = null;
static int roundCount = 0;
static bool isSpecialDayRound[MAX_ROUNDS] = {false, ...};

public void Specialdays_OnPluginStart()
{
  specialDayCount = 0;
  
  cvar_specialdays_maxdays = CreateConVar("sm_wt_specialdays_maxdays", "4", "Maximum number of special days per map (def. 4)");
  cvar_specialdays_starttime = CreateConVar("sm_wt_specialdays_starttime", "60.0", "The amount of time the warden has to trigger a special day (def. 60.0)");
  
  HookEvent("round_end", SpecialDay_EventRoundEnd, EventHookMode_Pre);
  HookEvent("round_prestart", SpecialDay_Reset, EventHookMode_Post);
  HookEvent("server_cvar", SpecialDay_EventServerCvar, EventHookMode_Pre);
  
  //Call init functions
  Specialdays_Init_Freeday();
  Specialdays_Init_CustomDay();
  Specialdays_Init_HnsDay();
  Specialdays_Init_Warday();
  Specialdays_Init_ZombieDay();
  Specialdays_Init_FfaDm();
  Specialdays_Init_TeamDm();
  Specialdays_Init_Hungergames();
  Specialdays_Init_Oneinthechamber();
}

public void Specialdays_OnMapStart()
{
  numSpecialDays = 0;
  roundCount = 0;
}

//Round End
public Action SpecialDay_EventRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
  //Call end func
  if (currentSpecialDay != -1) {
    Call_StartFunction(null, specialDayList[currentSpecialDay][dayEnd]);
    Call_Finish();
    currentSpecialDay = -1;
  }
}

//Round pre start
public Action SpecialDay_Reset(Handle event, const char[] name, bool dontBroadcast)
{ 
  //Enable LR if disabled
  ConVar hostiesLR = FindConVar("sm_hosties_lr");
  if (hostiesLR != null)
    SetConVarInt(hostiesLR, 1);  
    
  //Enable colouring of rebellers
  ConVar rebelColour = FindConVar("sm_hosties_rebel_color");
  if (rebelColour != null)
    SetConVarInt(rebelColour, 1);
    
  //Enable warden claiming
  ConVar wardenClaim = FindConVar("sm_warden_enabled");
  if (wardenClaim != null)
    SetConVarInt(wardenClaim, 1);
    
  if (damageProtectionHandle != null)
    delete damageProtectionHandle;
    
  if (teleportHandle != null)
    delete teleportHandle;
    
  specialDayStartTime = 0;
  specialDayDamageProtection = false;
  
  ++roundCount;
  
  //Set first round freeday
  if (roundCount == 1) {
    --numSpecialDays; //this round does not reduce number of rounds
    Specialdays_StartSpecialDay("Freeday");
  }
}

//Disable annoying convar changes from being printed into chat
public Action SpecialDay_EventServerCvar(Handle event, const char[] name, bool dontBroadcast)
{
  char cvarName[128];
  GetEventString(event, "cvarname", cvarName, sizeof(cvarName));

  if (StrEqual(cvarName, "mp_friendlyfire") || StrEqual(cvarName, "mp_teammates_are_enemies")) {
    return Plugin_Handled;
  }

  return Plugin_Continue;  
}

public void Specialdays_OnClientPutInServer(int client)
{
  SDKHook(client, SDKHook_OnTakeDamage, Specialdays_OnTakeDamage);
  
  //Special days
  for (int i = 0; i < specialDayCount; ++i) {
    Call_StartFunction(null, specialDayList[i][onClientPutInServer]);
    Call_PushCell(client);
    Call_Finish();
  }
}

//Called when a player takes damage, can be used by special days to block damage during hide time
public Action Specialdays_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
  //Ignore invalid entities
  if (!(victim >= 0 && victim <= MaxClients) || !(attacker >= 0 && attacker <= MaxClients)) {
    return Plugin_Continue;
  }

  //On special days, stop drowning during freeze and fall damage from world
  if (Specialdays_IsSpecialDay() && specialDayDamageProtection && attacker == 0) {
    if (damagetype & (DMG_DROWN | DMG_DROWNRECOVER | DMG_FALL) > 0)
      return Plugin_Handled;
  }
  
  //Block damage from players
  if (Specialdays_IsSpecialDay() && specialDayDamageProtection && attacker != 0) {
    return Plugin_Handled;
  }
  
  return Plugin_Continue;
}


public void Specialdays_StartSpecialDay(char[] name)
{
  //Store start time
  specialDayStartTime = GetTime();

  bool success = false;
  
  //Search for special day by name and call its start function
  for (int i = 0; i < specialDayCount; ++i) {
    if (StrEqual(specialDayList[i][dayName], name)) {
      //Perform restriction checking
      Call_StartFunction(null, specialDayList[i][restrictionCheck]);
      Call_Finish(success);
      if (!success)
        break;
    
      currentSpecialDay = i;
      Call_StartFunction(null, specialDayList[i][dayStart]);
      Call_Finish();
      break;
    }
  }
  
  //No special day found
  if (currentSpecialDay == -1)
    return;
  
  //Required condition was not met
  if (!success)
    return;
  
  //Set other required settings
  //Disable LR on special days unless its a round modifier
  ConVar hostiesLR = FindConVar("sm_hosties_lr");
  if (hostiesLR != null)
    SetConVarInt(hostiesLR, 0);  
    
  //Disable colouring of rebellers
  ConVar rebelColour = FindConVar("sm_hosties_rebel_color");
  if (rebelColour != null)
    SetConVarInt(rebelColour, 0);
    
  //Disable warden claiming
  ConVar wardenClaim = FindConVar("sm_warden_enabled");
  if (wardenClaim != null)
    SetConVarInt(wardenClaim, 0);

  ++numSpecialDays;
  
  isSpecialDayRound[roundCount] = true;
}

public void Specialdays_RegisterDay(char[] name, Function startFunc, Function endFunc, Function restrictionCheckFunc, Function onClientPutInServerFunc, bool allowDrawToolsValue, bool allowGameToolsValue)
{
  //Store required information
  strcopy(specialDayList[specialDayCount][dayName], 64, name);
  specialDayList[specialDayCount][dayStart] = startFunc;
  specialDayList[specialDayCount][dayEnd] = endFunc;
  specialDayList[specialDayCount][restrictionCheck] = restrictionCheckFunc;
  specialDayList[specialDayCount][onClientPutInServer] = onClientPutInServerFunc;
  specialDayList[specialDayCount][allowDrawTools] = allowDrawToolsValue;
  specialDayList[specialDayCount][allowGameTools] = allowGameToolsValue;
  
  ++specialDayCount;
}

//Called when damage protection is to be turned off
public Action Specialdays_DamageProtection_End(Handle timer)
{
  specialDayDamageProtection = false;
  damageProtectionHandle = null;
}

//Teleports players to beam that spawns on a clients location
//Players are also frozen before being teleported
//Uses: teleportHandle as handle (should be set to null in teleportFunc)
//teleportFunc is: Specialdays_Teleport_Start_All, Specialdays_Teleport_Start_T
//teleportType is: 0 for all players, 1 for T's
public void Specialdays_TeleportPlayers(int client, float tptime, char[] specialDayName, Timer teleportFunc, int teleportType)
{
  float client_origin[3];
  float client_angles[3];
  GetClientAbsOrigin(client, client_origin);
  GetClientAbsAngles(client, client_angles);
 
  //Create timer with pack
  Handle pack;
  teleportHandle = CreateDataTimer(tptime, teleportFunc, pack);
  
  if (teleportType == TELEPORTTYPE_ALL)
    ServerCommand("sm_freeze @all %d", RoundToFloor(tptime));
  else if (teleportType == TELEPORTTYPE_T)
    ServerCommand("sm_freeze @t %d", RoundToFloor(tptime));
    
  //Day name
  WritePackString(pack, specialDayName);
  
  //Origin
  WritePackFloat(pack, client_origin[0]);
  WritePackFloat(pack, client_origin[1]);
  WritePackFloat(pack, client_origin[2]);
  
  //Angles
  WritePackFloat(pack, client_angles[0]);
  WritePackFloat(pack, client_angles[1]);
  WritePackFloat(pack, client_angles[2]);
  
  //Draw beam (rally point)
  Beams_SpawnBeam(tptime, client_origin, colours_current);
}

//Teleport start timer handler
public Action Specialdays_Teleport_Start_All(Handle timer, Handle pack)
{
  ResetPack(pack);
  char buffer[128];
  ReadPackString(pack, buffer, sizeof(buffer));
  
  float hOrigin[3], hAngles[3];
  hOrigin[0] = ReadPackFloat(pack);
  hOrigin[1] = ReadPackFloat(pack);
  hOrigin[2] = ReadPackFloat(pack);
  
  hAngles[0] = ReadPackFloat(pack);
  hAngles[1] = ReadPackFloat(pack);
  hAngles[2] = ReadPackFloat(pack);
  
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
  
  teleportHandle = null;
}

//Teleport start timer handler
public Action Specialdays_Teleport_Start_T(Handle timer, Handle pack)
{
  ResetPack(pack);
  char buffer[128];
  ReadPackString(pack, buffer, sizeof(buffer));
  
  float hOrigin[3], hAngles[3];
  hOrigin[0] = ReadPackFloat(pack);
  hOrigin[1] = ReadPackFloat(pack);
  hOrigin[2] = ReadPackFloat(pack);
  
  hAngles[0] = ReadPackFloat(pack);
  hAngles[1] = ReadPackFloat(pack);
  hAngles[2] = ReadPackFloat(pack);
  
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
  
  teleportHandle = null;
}

//Getters/setters
public bool Specialdays_IsSpecialDay()
{
  return (currentSpecialDay != -1);
}

public int Specialdays_GetSpecialDay()
{
  return currentSpecialDay;
}

public void Specialdays_GetSpecialDayName(char[] buffer, int bufferSize)
{
  if (Specialdays_IsSpecialDay()) {
    Format(buffer, bufferSize, specialDayList[currentSpecialDay][dayName]);
  } else {
    Format(buffer, bufferSize, "");
  }
}

public int Specialdays_GetSpecialDayCount()
{
  return specialDayCount;
}

public int Specialdays_GetNumSpecialDays()
{
  return numSpecialDays;
}

public int Specialdays_GetNumSpecialDaysLeft()
{
  return GetConVarInt(cvar_specialdays_maxdays) - numSpecialDays;
}

public int Specialdays_GetDayStartTime()
{
  return specialDayStartTime;
}

public int Specialdays_GetSecondsToStartDay()
{
  return GetConVarInt(cvar_specialdays_starttime);
}

//Returns true if its okay to start special day
public bool Specialdays_CanStartSpecialDay()
{
  if (Specialdays_IsSpecialDay())
    return false;
    
  if (Specialdays_GetNumSpecialDaysLeft() == 0)
    return false;
  
  if (GetTimeSinceRoundStart() >= Specialdays_GetSecondsToStartDay())
    return false;
    
  if (roundCount <= 1 || isSpecialDayRound[roundCount - 1])
    return false;
  
  return true;
}

//Duration: 0.0 equals permanent
public void Specialdays_SetDamageProtection(bool value, float duration)
{
  specialDayDamageProtection = value;
  
  if (specialDayDamageProtection) {
    if (duration > 0.0) {
      damageProtectionHandle = CreateTimer(duration, Specialdays_DamageProtection_End);
    }
  }
}