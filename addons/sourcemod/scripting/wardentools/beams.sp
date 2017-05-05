/*
* Selects/Manages which beam to use
* Prefix: Beams_
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
#define BEAM_DEFAULT_DURATION 20.0

enum BeamType
{
  BeamType_Colour,
  BeamType_Particle
};

//Global statics
static BeamType s_CurBeamType = BeamType_Colour;
static int s_CurBeamsUsed = 0;
static float s_CurDuration = BEAM_DEFAULT_DURATION;
static bool s_InRoundEndTime = false;

//Convars
ConVar g_Cvar_Beams_MaxBeams = null;
ConVar g_Cvar_Beams_MaxUnits = null;

//OnPluginStart
public void Beams_OnPluginStart()
{
  RegConsoleCmd("+beam", Beams_PlaceBeamAction, "");
  HookEvent("round_prestart", Beams_Reset, EventHookMode_Post);
  HookEvent("round_end", Beams_EventRoundEnd, EventHookMode_Pre);
  
  //Convars
  g_Cvar_Beams_MaxBeams = CreateConVar("sm_wt_beams_maxbeams", "7", "Maximum number of beams that can be spawned at any given time (def. 7)");
  g_Cvar_Beams_MaxUnits = CreateConVar("sm_wt_beams_maxunits", "1500", "Maximum number of units a beam can be spawned from the player (def. 1000)");
  
  //Call submodule OnPluginStart
  ParticleBeams_OnPluginStart();
}

//OnMapStart
public void Beams_OnMapStart()
{
  ColourBeams_OnMapStart();
}

//Round End
public void Beams_EventRoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
  s_InRoundEndTime = true;
}

//Round pre start
public void Beams_Reset(Handle event, const char[] name, bool dontBroadcast)
{
  s_CurBeamsUsed = 0;
  s_InRoundEndTime = false;
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
  GetAimOrigin(client, hOrigin);
  
  float clientOrigin[3];
  GetClientAbsOrigin(client, clientOrigin);
  
  hOrigin[2] += 10; //move beam Y slightly above ground
  
  //Ensure beam is not too far
  if (GetVectorDistance(clientOrigin, hOrigin, false) > g_Cvar_Beams_MaxUnits.IntValue) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Beam Too Far");
    return;
  }
  
  //Spawn the beam
  Beams_SpawnBeam(client, s_CurDuration, hOrigin);
  
  //Make Beam Sound if not in round end time (to not cut off other audio)
  if (!s_InRoundEndTime)
    EmitSoundToAllAny(BEAM_SOUND, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
  
  ++s_CurBeamsUsed;
  CreateTimer(s_CurDuration, Beams_CounterResetTimer);
  
  return;
}

public void Beams_SpawnBeam(int client, float duration, float position[3])
{
  //Spawn Beam based on beam type preference
  if (s_CurBeamType == BeamType_Colour)
    ColourBeams_PlaceBeam(client, duration, position);
  else if (s_CurBeamType == BeamType_Particle)
    ParticleBeams_PlaceBeam(client, duration, position);
}

//Reset beam counter for 1 beam
public Action Beams_CounterResetTimer(Handle timer)
{
  --s_CurBeamsUsed;
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
  SpecialDays_GetSpecialDayName(specialDayName, sizeof(specialDayName));
  
  if (SpecialDays_IsSpecialDay() && !StrEqual(specialDayName, "Freeday") && !StrEqual(specialDayName, "Custom Special Day")) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "SpecialDay - Command Not Allowed");
    return true;
  }
  
  //Ensure max number of beams haven't already been made
  if (s_CurBeamsUsed >= g_Cvar_Beams_MaxBeams.IntValue) {
    CPrintToChat(client, "%s%t", CHAT_TAG_PREFIX, "Too Many Beams");
    return true;
  }
  
  return false;
}

//Getters/Setters
public BeamType Beams_GetBeamType()
{
  return s_CurBeamType;
}

public float Beams_GetBeamDuration()
{
  return s_CurDuration;
}

public void Beams_SetDuration(float duration)
{
  s_CurDuration = duration;
}

public void Beams_SetBeamType(BeamType type)
{
  s_CurBeamType = type;
}