/*
* Draw using a laser tool
* Prefix: laser_
*/

#if defined _wardentools_laser_included
  #endinput
#endif
#define _wardentools_laser_included

#include <wardentools>

//Global statics
static int g_DefaultColors_c[7][4] = { {255,255,255,255}, {255,0,0,255}, {0,255,0,255}, {0,0,255,255}, {255,255,0,255}, {0,255,255,255}, {255,0,255,255} };
static float LastLaser[MAXPLAYERS+1][3];
static bool LaserEnabled[MAXPLAYERS+1] = {false, ...};

//Materials
static int g_BeamSprite;

//OnPluginStart
public void Laser_OnPluginStart()
{
  RegConsoleCmd("+sm_laser", Laser_PlaceLaserAction, "");
  RegConsoleCmd("-sm_laser", Laser_RemoveLaserAction, "");
  
  HookEvent("player_death", Laser_EventPlayerDeath, EventHookMode_Pre);
  HookEvent("round_prestart", Laser_Reset, EventHookMode_Post);
}

//OnMapStart
public void Laser_OnMapStart()
{
  AddFileToDownloadsTable("materials/sprites/laserbeam.vmt");
  AddFileToDownloadsTable("materials/sprites/laserbeam.vtf");
  
  //Precache materials
  g_BeamSprite = PrecacheModel("sprites/laserbeam.vmt", true);
  
  //Laser timer
  CreateTimer(0.1, Laser_CheckLaser, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

//OnClientPutInServer
public void Laser_OnClientPutInServer(int client)
{
  LaserEnabled[client] = false;
  LastLaser[client][0] = 0.0;
  LastLaser[client][1] = 0.0;
  LastLaser[client][2] = 0.0;
}

//Player death hook
public Action Laser_EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(event.GetInt("userid"));
  
  bool isWarden = view_as<bool>(warden_iswarden(client));
  //Warden just died
  if (isWarden) {
    //Turn off laser for warden
    Laser_RemoveLaserAction(client, 0);
  }
}

//Round pre start
public void Laser_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientInGame(i))
      continue;
    
    //Remove enabled lasers for all
    Laser_RemoveLaserAction(i, 0);
  }
}

public Action Laser_PlaceLaserAction(int client, int args) {
  //Check restrictions
  if (Laser_CheckRestrictions(client))
    return Plugin_Handled;
  
  //Draw laser
  TraceEye(client, LastLaser[client]);
  LaserEnabled[client] = true;  
  
  return Plugin_Handled;
}

public Action Laser_RemoveLaserAction(int client, int args) {
  LastLaser[client][0] = 0.0;
  LastLaser[client][1] = 0.0;
  LastLaser[client][2] = 0.0;
  LaserEnabled[client] = false;
  return Plugin_Handled;
}

//Laser code
public Action Laser_CheckLaser(Handle timer)
{
  float pos[3];
  int colour = GetRandomInt(0,6);
  
  for (int i = 1; i <= MaxClients; ++i) {
    if (IsClientInGame(i) && LaserEnabled[i]) {
      TraceEye(i, pos);
      if (GetVectorDistance(pos, LastLaser[i]) > 6.0) {
        LaserP(LastLaser[i], pos, g_DefaultColors_c[colour]);
        LastLaser[i][0] = pos[0];
        LastLaser[i][1] = pos[1];
        LastLaser[i][2] = pos[2];
      }
    } 
  }
}

//Trace Eye for drawing laser
void TraceEye(int client, float pos[3]) {
  float vAngles[3], vOrigin[3];
  GetClientEyePosition(client, vOrigin);
  GetClientEyeAngles(client, vAngles);
  TR_TraceRayFilter(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
  
  if (TR_DidHit(null))
    TR_GetEndPosition(pos, null);
  
  return;
}

stock void LaserP(float start[3], float end[3], int colour[4]) {
  TE_SetupBeamPoints(start, end, g_BeamSprite, 0, 0, 0, 25.0, 2.0, 2.0, 10, 0.0, colour, 0);
  TE_SendToAll();
}

//Returns true if a restriction is enforced and we cannot proceed
bool Laser_CheckRestrictions(int client)
{
  //Ensure user is warden
  bool isWarden = view_as<bool>(warden_iswarden(client));

  if (!isWarden) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Warden Only Command");
    return true;
  }
  
  //Disallow on special days
  char specialDayName[64];
  Specialdays_GetSpecialDayName(specialDayName, sizeof(specialDayName));
  
  if (Specialdays_IsSpecialDay() && !StrEqual(specialDayName, "Freeday") && !StrEqual(specialDayName, "Custom Special Day")) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Command Not Allowed");
    return true;
  }
  
  return false;
}

//Getters/Setters

//Check if client has laser enabled
public bool Laser_IsLaserEnabled(int client)
{
  return LaserEnabled[client];
}