/*
* Selects/Manages which beam to use
* Prefix: beams_
*/

#if defined _wardentools_beams_included
  #endinput
#endif
#define _wardentools_beams_included

#include <wardentools>

#include "wardentools/colourbeams.sp"
#include "wardentools/particlebeams.sp"
#include "wardentools/specialdays.sp"

//Defines
#define BEAM_SOUND "invex_gaming/jb_wardentools/portalgun_shoot_red1_fix.mp3"
#define BEAMTYPE_COLOUR 0
#define BEAMTYPE_PARTICLE 1
#define BEAM_DEFAULT_DURATION 20.0

//Global statics
static int curBeamType = BEAMTYPE_COLOUR;
static int currentBeamsUsed = 0;
static float curDuration = BEAM_DEFAULT_DURATION;
static bool inRoundEndTime = false;

//Convars
ConVar cvar_beams_maxbeams = null;
ConVar cvar_beams_maxunits = null;

//OnPluginStart
public void Beams_OnPluginStart()
{
  RegConsoleCmd("+beam", Beams_PlaceBeamAction, "", FCVAR_GAMEDLL);
  HookEvent("round_prestart", Beams_Reset, EventHookMode_Post);
  HookEvent("round_end", Beams_EventRoundEnd, EventHookMode_Pre);
  
  //Convars
  cvar_beams_maxbeams = CreateConVar("sm_wt_beams_maxbeams", "7", "Maximum number of beams that can be spawned at any given time (def. 7)");
  cvar_beams_maxunits = CreateConVar("sm_wt_beams_maxunits", "1500", "Maximum number of units a beam can be spawned from the player (def. 1000)");
  
  //Call submodule OnPluginStart
  Particlebeams_OnPluginStart();
}

//OnMapStart
public void Beams_OnMapStart()
{
  Colourbeams_OnMapStart();
}

//Round End
public void Beams_EventRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
  inRoundEndTime = true;
}

//Round pre start
public void Beams_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  currentBeamsUsed = 0;
  inRoundEndTime = false;
}

//Quick place beams using bind
public Action Beams_PlaceBeamAction(int client, int args)
{
  Beams_PlaceBeam(client);
  
  return Plugin_Handled;
}

public void Beams_PlaceBeam(int client)
{
  //Check restrictions
  if (Beams_CheckRestrictions(client))
    return;
  
  //Get position client is looking at
  float hOrigin[3];
  GetAimOrigin(client, hOrigin, 1);
  
  float clientOrigin[3];
  GetClientAbsOrigin(client, clientOrigin);
  
  hOrigin[2] += 10; //move beam Y slightly above ground
  
  //Ensure beam is not too far
  if (GetVectorDistance(clientOrigin, hOrigin, false) > GetConVarInt(cvar_beams_maxunits)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Beam Too Far");
    return;
  }
  
  //Spawn the beam
  Beams_SpawnBeam(client, curDuration, hOrigin);
  
  //Make Beam Sound if not in round end time (to not cut off other audio)
  if (!inRoundEndTime)
    EmitSoundToAllAny(BEAM_SOUND, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
  
  ++currentBeamsUsed;
  CreateTimer(curDuration, Beams_CounterResetTimer);
  
  return;
}

public void Beams_SpawnBeam(int client, float duration, float position[3])
{
  //Spawn Beam based on beam type preference
  if (curBeamType == BEAMTYPE_COLOUR)
    Colourbeams_PlaceBeam(client, duration, position);
  else if (curBeamType == BEAMTYPE_PARTICLE)
    Particlebeams_PlaceBeam(client, duration, position);
}

//Reset beam counter for 1 beam
public Action Beams_CounterResetTimer(Handle timer)
{
  --currentBeamsUsed;
}

//Returns true if a restriction is enforced and we cannot proceed
bool Beams_CheckRestrictions(int client)
{
  //Ensure team is CT
  if (GetClientTeam(client) != CS_TEAM_CT) { 
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "CT Only Command");
    return true;
  }
  
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
  
  //Ensure max number of beams haven't already been made
  if (currentBeamsUsed >= GetConVarInt(cvar_beams_maxbeams)) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Too Many Beams");
    return true;
  }
  
  return false;
}

//Getters/Setters
public int Beams_GetBeamType()
{
  return curBeamType;
}

public float Beams_GetBeamDuration()
{
  return curDuration;
}

public void Beams_SetDuration(float duration)
{
  curDuration = duration;
}

public void Beams_SetBeamType(int type)
{
  curBeamType = type;
}