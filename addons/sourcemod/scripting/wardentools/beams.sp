/*
* Spawns beams (rings) on the ground
* Prefix: beams_
*/

#if defined _wardentools_beams_included
  #endinput
#endif
#define _wardentools_beams_included

#include <wardentools>

#include "wardentools/colours.sp"
#include "wardentools/specialdays.sp"

//Defines
#define BEAM_SOUND "invex_gaming/jb_wardentools/portalgun_shoot_red1_fix.mp3"

//Global statics
static int currentBeamsUsed = 0;
static float curDuration = 20.0;
static bool inRoundEndTime = false;

//Materials
static int g_BlackBeamSprite;
static int g_BeamSprite;
static int g_HaloSprite;

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
}

//OnMapStart
public void Beams_OnMapStart()
{
  AddFileToDownloadsTable("materials/sprites/invex/black1.vmt");
  AddFileToDownloadsTable("materials/sprites/invex/black1.vtf");
  AddFileToDownloadsTable("materials/sprites/laserbeam.vmt");
  AddFileToDownloadsTable("materials/sprites/laserbeam.vtf");
  AddFileToDownloadsTable("materials/sprites/halo01.vmt");
  AddFileToDownloadsTable("materials/sprites/halo01.vtf");
  
  //Precache materials
  g_BlackBeamSprite = PrecacheModel("sprites/invex/black1.vmt", true);
  g_BeamSprite = PrecacheModel("sprites/laserbeam.vmt", true);
  g_HaloSprite = PrecacheModel("sprites/halo01.vmt", true);
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
  curDuration = 20.0;
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
  
  //Spawn Beam
  Beams_SpawnBeam(curDuration, hOrigin, colours_current);
  
  //Make Beam Sound if not in round end time (to not cut off other audo)
  if (!inRoundEndTime)
    EmitSoundToAllAny(BEAM_SOUND, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL);
  
  ++currentBeamsUsed;
  CreateTimer(curDuration, Beams_CounterResetTimer);
  
  return;
}

//Reset beam counter for 1 beam
public Action Beams_CounterResetTimer(Handle timer)
{
  --currentBeamsUsed;
}

//Used to spawn Beams given a duration, position and colour
public void Beams_SpawnBeam(float duration, float position[3], const int colour[4])
{
  int excessDurationCount = RoundToFloor(duration / 10.0);
  
  //Start timer to recreate beacon
  Handle beampack;
  CreateDataTimer(0.0, Beams_ExcessBeamSpawner, beampack);
  WritePackCell(beampack, excessDurationCount);
  
  //Origin
  WritePackFloat(beampack, position[0]);
  WritePackFloat(beampack, position[1]);
  WritePackFloat(beampack, position[2]);
  
  //RGB Colour
  WritePackCell(beampack, colour[0]);
  WritePackCell(beampack, colour[1]);
  WritePackCell(beampack, colour[2]);
  WritePackCell(beampack, colour[3]);
}

//Used to spawn same beam every 10 second to avoid timer glitches for longer durations
public Action Beams_ExcessBeamSpawner(Handle timer, Handle pack)
{
  ResetPack(pack);
  
  int excessDurationCount = ReadPackCell(pack);
  
  float hOrigin[3];
  hOrigin[0] = ReadPackFloat(pack);
  hOrigin[1] = ReadPackFloat(pack);
  hOrigin[2] = ReadPackFloat(pack);
  
  //RGB colour
  int beamColour[4];
  beamColour[0] = ReadPackCell(pack);
  beamColour[1] = ReadPackCell(pack);
  beamColour[2] = ReadPackCell(pack);
  beamColour[3] = ReadPackCell(pack);
  
  //Draw Beam
  //Set sprite to black or regular
  int beamSprite = g_BeamSprite;
  if ((beamColour[0] == colours_black[0]) &&
      (beamColour[1] == colours_black[1]) &&
      (beamColour[2] == colours_black[2]) &&
      (beamColour[3] == colours_black[3]))
    beamSprite = g_BlackBeamSprite;
    
  TE_SetupBeamRingPoint(hOrigin, 75.0, 75.5, beamSprite, g_HaloSprite, 0, 0, 10.0, 10.0, 0.0, beamColour, 0, 0);
  TE_SendToAll();
  
  //Restart next timer
  --excessDurationCount;
  
  if (excessDurationCount != 0) {
    Handle nextPack;
    CreateDataTimer(10.0, Beams_ExcessBeamSpawner, nextPack);
    WritePackCell(nextPack, excessDurationCount);
    
    //Origin
    WritePackFloat(nextPack, hOrigin[0]);
    WritePackFloat(nextPack, hOrigin[1]);
    WritePackFloat(nextPack, hOrigin[2]);
    
    //RGB Colour
    WritePackCell(nextPack, beamColour[0]);
    WritePackCell(nextPack, beamColour[1]);
    WritePackCell(nextPack, beamColour[2]);
    WritePackCell(nextPack, beamColour[3]);
  }
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
public void Beams_SetDuration(float duration)
{
  curDuration = duration;
}