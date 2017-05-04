/*
* Spawns beams (rings) on the ground
* Prefix: ColourBeams_
*/

#if defined _wardentools_colourBeams_included
  #endinput
#endif
#define _wardentools_colourBeams_included

#include <wardentools>

#include "wardentools/colours.sp"

//Materials
static int s_BlackBeamSprite;
static int s_BeamSprite;
static int s_HaloSprite;

//OnMapStart
public void ColourBeams_OnMapStart()
{
  AddFileToDownloadsTable("materials/sprites/invex/black1.vmt");
  AddFileToDownloadsTable("materials/sprites/invex/black1.vtf");
  AddFileToDownloadsTable("materials/sprites/laserbeam.vmt");
  AddFileToDownloadsTable("materials/sprites/laserbeam.vtf");
  AddFileToDownloadsTable("materials/sprites/halo01.vmt");
  AddFileToDownloadsTable("materials/sprites/halo01.vtf");
  
  //Precache materials
  s_BlackBeamSprite = PrecacheModel("sprites/invex/black1.vmt", true);
  s_BeamSprite = PrecacheModel("sprites/laserbeam.vmt", true);
  s_HaloSprite = PrecacheModel("sprites/halo01.vmt", true);
}

public void ColourBeams_PlaceBeam(int client, float duration, float position[3])
{
  //Delegate to subfunction passing duration and position
  ColourBeams_PlaceBeamColour(duration, position, g_Colours_Current);
}

//Used to spawn Beams given a duration, position and colour
public void ColourBeams_PlaceBeamColour(float duration, float position[3], const int colour[4])
{
  int excessDurationCount = RoundToFloor(duration / 10.0);
  
  //Start timer to recreate beacon
  //We won't use CreateDataPack because we don't want to automatically free this pack
  DataPack beampack = new DataPack();
  beampack.WriteCell(excessDurationCount);
  
  //Origin
  beampack.WriteFloat(position[0]);
  beampack.WriteFloat(position[1]);
  beampack.WriteFloat(position[2]);
  
  //RGB Colour
  beampack.WriteCell(colour[0]);
  beampack.WriteCell(colour[1]);
  beampack.WriteCell(colour[2]);
  beampack.WriteCell(colour[3]);
  
  CreateTimer(0.0, ColourBeams_ExcessBeamSpawner, beampack);
}

//Used to spawn same beam every 10 second to avoid timer glitches for longer durations
public Action ColourBeams_ExcessBeamSpawner(Handle timer, DataPack pack)
{
  pack.Reset();
  
  int excessDurationCount = pack.ReadCell();
  
  float hOrigin[3];
  hOrigin[0] = pack.ReadFloat();
  hOrigin[1] = pack.ReadFloat();
  hOrigin[2] = pack.ReadFloat();
  
  //RGB colour
  int beamColour[4];
  beamColour[0] = pack.ReadCell();
  beamColour[1] = pack.ReadCell();
  beamColour[2] = pack.ReadCell();
  beamColour[3] = pack.ReadCell();
  
  //Draw Beam
  //Set sprite to black or regular
  int beamSprite = s_BeamSprite;
  if ((beamColour[0] == g_Colours_Black[0]) &&
      (beamColour[1] == g_Colours_Black[1]) &&
      (beamColour[2] == g_Colours_Black[2]) &&
      (beamColour[3] == g_Colours_Black[3]))
    beamSprite = s_BlackBeamSprite;
    
  TE_SetupBeamRingPoint(hOrigin, 75.0, 75.5, beamSprite, s_HaloSprite, 0, 0, 10.0, 10.0, 0.0, beamColour, 0, 0);
  TE_SendToAll();
  
  //Restart next timer
  --excessDurationCount;
  
  if (excessDurationCount != 0) {
    //Update excessDurationCount in pack and reuse pack for next call
    pack.Reset();
    pack.WriteCell(excessDurationCount);
    CreateTimer(10.0 - 0.05, ColourBeams_ExcessBeamSpawner, pack); //spawn in just under 10 seconds to minimize flickering
  } else {
    //End of timers life, free pack
    delete pack;
  }
}